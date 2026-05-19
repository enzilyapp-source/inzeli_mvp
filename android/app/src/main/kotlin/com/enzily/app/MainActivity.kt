package com.enzily.app

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.enzily.app/game_notifications",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    LocalGameNotifications.requestPermission(this)
                    result.success(true)
                }

                "show" -> {
                    LocalGameNotifications.requestPermission(this)
                    LocalGameNotifications.show(
                        context = this,
                        id = call.intArg("id", 9001),
                        title = call.stringArg("title", "إنزلي"),
                        body = call.stringArg("body", ""),
                        endAtMillis = call.longArg("endAtMillis", 0L),
                    )
                    result.success(true)
                }

                "schedule" -> {
                    LocalGameNotifications.schedule(
                        context = this,
                        id = call.intArg("id", 9002),
                        title = call.stringArg("title", "إنزلي"),
                        body = call.stringArg("body", ""),
                        delaySeconds = call.longArg("delaySeconds", 1L),
                    )
                    result.success(true)
                }

                "cancel" -> {
                    LocalGameNotifications.cancel(this, call.intArg("id", 9002))
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}

class GameNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        LocalGameNotifications.show(
            context = context,
            id = intent.getIntExtra("id", 9002),
            title = intent.getStringExtra("title") ?: "إنزلي",
            body = intent.getStringExtra("body") ?: "",
            endAtMillis = 0L,
        )
    }
}

private object LocalGameNotifications {
    private const val CHANNEL_ID = "inzeli_game_timer"
    private const val PERMISSION_REQUEST_CODE = 7023

    fun requestPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        activity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            PERMISSION_REQUEST_CODE,
        )
    }

    fun show(
        context: Context,
        id: Int,
        title: String,
        body: String,
        endAtMillis: Long,
    ) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent()
        val contentIntent = PendingIntent.getActivity(
            context,
            id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }

        builder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_HIGH)
            .setDefaults(Notification.DEFAULT_ALL)

        if (endAtMillis > 0L && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder
                .setWhen(endAtMillis)
                .setShowWhen(true)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
        } else {
            builder.setWhen(System.currentTimeMillis()).setShowWhen(true)
        }

        manager.notify(id, builder.build())
    }

    fun schedule(
        context: Context,
        id: Int,
        title: String,
        body: String,
        delaySeconds: Long,
    ) {
        val triggerAtMillis =
            System.currentTimeMillis() + (delaySeconds.coerceAtLeast(1L) * 1000L)
        val intent = Intent(context, GameNotificationReceiver::class.java)
            .putExtra("id", id)
            .putExtra("title", title)
            .putExtra("body", body)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    fun cancel(context: Context, id: Int) {
        val intent = Intent(context, GameNotificationReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(id)
    }

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Game timer",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Inzeli match timer notifications"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }
}

private fun MethodCall.args(): Map<*, *> = arguments as? Map<*, *> ?: emptyMap<Any, Any>()

private fun MethodCall.stringArg(name: String, fallback: String): String =
    args()[name]?.toString() ?: fallback

private fun MethodCall.intArg(name: String, fallback: Int): Int =
    (args()[name] as? Number)?.toInt() ?: fallback

private fun MethodCall.longArg(name: String, fallback: Long): Long =
    (args()[name] as? Number)?.toLong() ?: fallback
