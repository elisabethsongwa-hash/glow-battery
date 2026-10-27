package com.glow.glow_battery

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import kotlin.math.abs

class MonitorService : Service() {
    private val handler = Handler(Looper.getMainLooper())

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_POWER_CONNECTED -> alert(true)
                Intent.ACTION_POWER_DISCONNECTED -> alert(false)
            }
        }
    }

    private val ticker = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 5000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onCreate() {
        super.onCreate()
        createChannels()
        val n = ongoing("Surveillance de la batterie")
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, n)
        }
        val f = IntentFilter()
        f.addAction(Intent.ACTION_POWER_CONNECTED)
        f.addAction(Intent.ACTION_POWER_DISCONNECTED)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(receiver, f, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, f)
        }
        handler.post(ticker)
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        try { unregisterReceiver(receiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel("glow_monitor", "Surveillance", NotificationManager.IMPORTANCE_LOW)
            )
            nm.createNotificationChannel(
                NotificationChannel("glow_alerts", "Alertes charge", NotificationManager.IMPORTANCE_HIGH)
            )
        }
    }

    private fun builder(channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel)
        else Notification.Builder(this)

    private fun openIntent(mode: String, req: Int): PendingIntent {
        val i = Intent(this, MainActivity::class.java)
        i.putExtra("mode", mode)
        i.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        return PendingIntent.getActivity(this, req, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun ongoing(text: String): Notification =
        builder("glow_monitor")
            .setSmallIcon(android.R.drawable.ic_lock_idle_charging)
            .setContentTitle("Glow Battery")
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(openIntent("", 0))
            .build()

    private fun readMa(bm: BatteryManager): Int {
        val raw = abs(bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW))
        return if (raw >= 10000) raw / 1000 else raw
    }

    private fun refresh() {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val pct = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val dir = if (bm.isCharging) "entrant" else "sortant"
        val n = ongoing("$pct % • ${readMa(bm)} mA $dir")
        getSystemService(NotificationManager::class.java).notify(1, n)
    }

    private fun alert(charging: Boolean) {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val pct = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val title = if (charging) "Glow Up – en charge" else "Glow Down – sur batterie"
        val n = builder("glow_alerts")
            .setSmallIcon(android.R.drawable.ic_lock_idle_charging)
            .setContentTitle(title)
            .setContentText("Batterie à $pct %. Touchez pour ouvrir.")
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_HIGH)
            .setContentIntent(openIntent(if (charging) "up" else "down", if (charging) 1 else 2))
            .build()
        getSystemService(NotificationManager::class.java).notify(2, n)
    }
}
