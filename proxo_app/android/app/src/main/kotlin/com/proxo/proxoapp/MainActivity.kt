package com.proxo.proxoapp

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the `proxo/local_preview` MethodChannel.
 *
 * It takes a local `.html` file that Flutter has already written into the
 * app cache and hands it to whatever app the user has for HTML — Chrome,
 * Samsung Internet, Firefox, Edge, anything. No package name is hard-coded:
 * a bare ACTION_VIEW lets Android open the user's default, or show its own
 * standard chooser when there isn't one.
 *
 * The file is exposed through FileProvider as a `content://` URI with a
 * temporary read grant — never a raw `file://` URI, which Android 7+ blocks
 * with FileUriExposedException. No storage permission is involved: the file
 * lives in the app's own cache directory.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "proxo/local_preview"

        /** Must match android:authorities in AndroidManifest.xml. */
        const val AUTHORITY_SUFFIX = ".previewprovider"

        const val MIME_HTML = "text/html"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openHtml" -> openHtml(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun openHtml(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("bad_args", "path is missing", null)
            return
        }

        val file = File(path)
        if (!file.exists() || file.length() == 0L) {
            result.error("missing_file", "preview file is missing or empty", null)
            return
        }

        val uri = try {
            FileProvider.getUriForFile(this, "$packageName$AUTHORITY_SUFFIX", file)
        } catch (e: Exception) {
            // Almost always a provider-paths mismatch — surfaced, never silent.
            result.error("provider_failed", e.message, null)
            return
        }

        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, MIME_HTML)
            // The temporary read grant that makes content:// usable by the
            // receiving app. Without it the browser gets a SecurityException.
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivity(view)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            // Nothing on the device handles a local text/html document.
            result.error("no_app", "no application can open text/html", null)
        } catch (e: SecurityException) {
            result.error("launch_failed", e.message, null)
        } catch (e: Exception) {
            result.error("launch_failed", e.message, null)
        }
    }
}
