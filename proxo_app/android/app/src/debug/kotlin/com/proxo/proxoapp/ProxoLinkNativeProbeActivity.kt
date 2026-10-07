package com.proxo.proxoapp

import android.os.Handler
import android.os.Looper
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
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "proxo/native-capture")
            .setMethodCallHandler { call, result ->
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
                        observer = ViewTreeObserver.OnDrawListener {
                            if (!drawSeen && !completed) {
                                drawSeen = true
                                // Remove the listener outside onDraw, then allow the
                                // platform-view texture to reach Flutter's compositor.
                                webView.post {
                                    webView.postOnAnimation {
                                        webView.postOnAnimation {
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
