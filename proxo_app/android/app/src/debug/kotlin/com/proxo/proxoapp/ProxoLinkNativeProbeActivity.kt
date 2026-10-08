package com.proxo.proxoapp

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.graphics.Bitmap
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.ViewGroup
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import android.view.View
import android.view.ViewTreeObserver
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

// Debug verification entry point. Use the production WebView, renderer and GPU;
// synchronize capture without changing its CSS, pixels or rendering settings.
class ProxoLinkNativeProbeActivity : FlutterActivity() {
    private var barrier: MutableMap<String, Any> = ConcurrentHashMap()
    private fun clockMs() = SystemClock.elapsedRealtimeNanos() / 1_000_000.0
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "proxo/native-capture")
            .setMethodCallHandler { call, result ->
                if (call.method == "captureSurface") {
                    fun surface(view: View): SurfaceView? {
                        if (view is SurfaceView) return view
                        if (view is ViewGroup) for (i in 0 until view.childCount) {
                            surface(view.getChildAt(i))?.let { return it }
                        }
                        return null
                    }
                    val view = surface(window.decorView)
                    if (view == null || !view.holder.surface.isValid || view.width <= 0 || view.height <= 0) {
                        result.success(mapOf("status" to -1)); return@setMethodCallHandler
                    }
                    val origin = IntArray(2); view.getLocationOnScreen(origin)
                    val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
                    val requested = clockMs()
                    // One fixed diagnostic read of Flutter's existing hardware surface,
                    // after the three acceptance samples. No redraw or alternative renderer.
                    PixelCopy.request(view, bitmap, { status ->
                        if (status == PixelCopy.SUCCESS) FileOutputStream(File(filesDir, "proxolink-diagnostic-surface.png")).use {
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
                        }
                        bitmap.recycle()
                        result.success(mapOf("status" to status, "requested_ms" to requested,
                            "completed_ms" to clockMs(), "screen_x" to origin[0], "screen_y" to origin[1],
                            "width" to view.width, "height" to view.height))
                    }, Handler(Looper.getMainLooper()))
                    return@setMethodCallHandler
                }
                if (call.method == "diagnostics") {
                    val identifier = call.argument<Number>("webViewIdentifier")?.toLong()
                    @Suppress("DEPRECATION")
                    val view = identifier?.let { WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, it) }
                    if (view == null) { result.error("native_diagnostics", "WebView required", null); return@setMethodCallHandler }
                    val screen = IntArray(2); view.getLocationOnScreen(screen)
                    val window = IntArray(2); view.getLocationInWindow(window)
                    val matrix = FloatArray(9); view.matrix.getValues(matrix)
                    result.success(mapOf(
                        "observed_ms" to clockMs(), "barrier" to barrier.toMap(),
                        "width" to view.width, "height" to view.height,
                        "content_height" to view.contentHeight, "page_scale" to view.scale,
                        "window_width" to this.window.decorView.width, "window_height" to this.window.decorView.height,
                        "display_width" to resources.displayMetrics.widthPixels,
                        "display_height" to resources.displayMetrics.heightPixels,
                        "xdpi" to resources.displayMetrics.xdpi, "ydpi" to resources.displayMetrics.ydpi,
                        "window_color_mode" to this.window.colorMode,
                        "screen_x" to screen[0], "screen_y" to screen[1],
                        "window_x" to window[0], "window_y" to window[1],
                        "scroll_x" to view.scrollX, "scroll_y" to view.scrollY,
                        "x" to view.x, "y" to view.y, "alpha" to view.alpha,
                        "scale_x" to view.scaleX, "scale_y" to view.scaleY,
                        "translation_x" to view.translationX, "translation_y" to view.translationY,
                        "matrix" to matrix.toList(), "layer_type" to view.layerType,
                        "hardware_accelerated" to view.isHardwareAccelerated,
                        "attached" to view.isAttachedToWindow,
                        "density" to resources.displayMetrics.density,
                        "density_dpi" to resources.displayMetrics.densityDpi,
                        "sdk" to android.os.Build.VERSION.SDK_INT,
                        "webview_version" to (WebView.getCurrentWebViewPackage()?.versionName ?: "unknown")
                    )); return@setMethodCallHandler
                }
                if (call.method != "awaitDraw") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val identifier = call.argument<Number>("webViewIdentifier")?.toLong()
                @Suppress("DEPRECATION")
                val webView = identifier?.let {
                    WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, it)
                }
                if (webView == null || !webView.isAttachedToWindow ||
                    webView.visibility != View.VISIBLE || webView.width <= 0 || webView.height <= 0) {
                    result.error("native_paint_barrier", "Visible attached WebView required", null)
                    return@setMethodCallHandler
                }
                val handler = Handler(Looper.getMainLooper())
                val instrument = call.argument<Boolean>("diagnostics") == true
                val observed: MutableMap<String, Any> = ConcurrentHashMap(mapOf("requested_ms" to clockMs(), "visual_state_seen" to false,
                    "draw_seen" to false, "frame_commit_seen" to false, "post_animation_callbacks" to 0))
                if (instrument) barrier = observed
                var completed = false
                var drawSeen = false
                var observer: ViewTreeObserver.OnDrawListener? = null
                fun finish(passed: Boolean) {
                    if (completed) return
                    completed = true
                    observer?.let { listener ->
                        if (webView.viewTreeObserver.isAlive) {
                            webView.viewTreeObserver.removeOnDrawListener(listener)
                        }
                    }
                    if (passed) result.success(true)
                    else result.error("native_paint_barrier", "Native draw timeout", null)
                }
                val timeout = Runnable { finish(false) }
                handler.postDelayed(timeout, 10000)
                webView.postVisualStateCallback(identifier ?: 0L, object : WebView.VisualStateCallback() {
                    override fun onComplete(requestId: Long) {
                        if (completed) return
                        if (instrument) {
                            observed["visual_state_seen"] = true; observed["visual_state_ms"] = clockMs()
                            // Observational only: do not wait on this or change the capture barrier.
                            // Frame commit means submitted for rendering, NOT proof of display presentation.
                            webView.viewTreeObserver.registerFrameCommitCallback {
                                observed["frame_commit_seen"] = true; observed["frame_commit_ms"] = clockMs()
                            }
                        }
                        observer = ViewTreeObserver.OnDrawListener {
                            if (!drawSeen && !completed) {
                                drawSeen = true
                                if (instrument) { observed["draw_seen"] = true; observed["draw_ms"] = clockMs() }
                                // Remove the listener outside onDraw, then allow the
                                // platform-view texture to reach Flutter's compositor.
                                webView.post {
                                    webView.postOnAnimation {
                                        if (instrument) { observed["post_animation_callbacks"] = 1; observed["animation_1_ms"] = clockMs() }
                                        webView.postOnAnimation {
                                            if (instrument) { observed["post_animation_callbacks"] = 2; observed["animation_2_ms"] = clockMs() }
                                            handler.removeCallbacks(timeout)
                                            finish(true)
                                        }
                                    }
                                }
                            }
                        }
                        webView.viewTreeObserver.addOnDrawListener(observer)
                        webView.invalidate()
                    }
                })
            }
    }
}

