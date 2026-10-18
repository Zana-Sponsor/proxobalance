package com.proxo.proxoapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Bitmap
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/** Local profile fixture; no test entry point or channel ships in release. */
class PolishRuntimeActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private val output get() = File(getExternalFilesDir(null), "polish-runtime").apply { mkdirs() }
    private var resumed: MethodChannel.Result? = null
    override fun onResume() {
        super.onResume()
        resumed?.success(true)
        resumed = null
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "proxo/polish-fixture")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "capture" -> {
                            val name = call.argument<String>("name") ?: ""
                            require(Regex("[a-z0-9_-]+\\.png").matches(name))
                            fun surface(v: View): SurfaceView? {
                                if (v is SurfaceView) return v
                                if (v is ViewGroup) for (i in 0 until v.childCount) {
                                    surface(v.getChildAt(i))?.let { return it }
                                }
                                return null
                            }
                            val view = surface(window.decorView) ?: error("Flutter surface missing")
                            val image = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
                            PixelCopy.request(view, image, { status ->
                                if (status == PixelCopy.SUCCESS) FileOutputStream(File(output, name)).use {
                                    image.compress(Bitmap.CompressFormat.PNG, 100, it)
                                }
                                image.recycle()
                                result.success(mapOf("status" to status, "width" to view.width, "height" to view.height))
                            }, handler)
                        }
                        "postBackgroundFcmFixture" -> {
                            val manager = getSystemService(NotificationManager::class.java)
                            manager.createNotificationChannel(NotificationChannel(
                                "proxo_high_importance", "Proxo Notifications", NotificationManager.IMPORTANCE_HIGH))
                            // Use Firebase's actual automatic-notification builder and the
                            // production manifest resources. This bypasses FCM transport only.
                            val bundle = Bundle().apply {
                                putString("gcm.n.e", "1")
                                putString("gcm.n.title", "پڕۆکسۆ · Proxo")
                                putString("gcm.n.body", "تاقیکردنەوەی ئاگاداری لە باکگراووند")
                                putString("gcm.n.icon", "ic_notification")
                                putString("gcm.n.color", "#046CFA")
                                putString("gcm.n.android_channel_id", "proxo_high_importance")
                                putString("gcm.n.default_sound", "1")
                            }
                            val paramsClass = Class.forName("com.google.firebase.messaging.NotificationParams")
                            val params = paramsClass.getDeclaredConstructor(Bundle::class.java).newInstance(bundle)
                            val builderClass = Class.forName("com.google.firebase.messaging.CommonNotificationBuilder")
                            val make = builderClass.declaredMethods.first {
                                it.parameterTypes.contentEquals(arrayOf(Context::class.java, paramsClass)) &&
                                    (it.name == "createNotificationInfo" || it.name == "createNotification")
                            }.apply { isAccessible = true }
                            val info = make.invoke(null, this, params)!!
                            val builder = info.javaClass.getField("notificationBuilder").get(info)
                            val notification = builder.javaClass.getMethod("build").invoke(builder) as Notification
                            check(notification.smallIcon.resId == R.drawable.ic_notification)
                            check(notification.color == 0xFF046CFA.toInt())
                            moveTaskToBack(true)
                            handler.postDelayed({ manager.notify("proxo-fixture", 4321, notification) }, 1000)
                            result.success(mapOf("builder" to make.name, "small_icon" to notification.smallIcon.resId,
                                "color" to notification.color, "channel" to notification.channelId,
                                "transport" to "local fixture; no FCM network request"))
                        }
                        "activeNotifications" -> {
                            val manager = getSystemService(NotificationManager::class.java)
                            result.success(manager.activeNotifications.map {
                                mapOf("id" to it.id, "icon" to it.notification.smallIcon.resId,
                                    "channel" to it.notification.channelId, "color" to it.notification.color)
                            })
                        }
                        "waitForResume" -> { resumed = result }
                        else -> result.notImplemented()
                    }
                } catch (error: Throwable) {
                    result.error("polish_fixture", error.toString(), null)
                }
            }
    }
}
