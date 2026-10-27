package com.glow.glow_battery

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "glow/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBattery" -> {
                        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        val m = HashMap<String, Any>()
                        m["currentUa"] = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
                        m["chargeUah"] = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
                        m["percent"] = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        m["charging"] = bm.isCharging
                        result.success(m)
                    }
                    else -> result.notImplemented()
                }
            }
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
        val i = Intent(this, MonitorService::class.java)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
    }
}
