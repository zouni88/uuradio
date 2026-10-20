package com.iradio.iradio

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.PhoneStateListener
import android.telephony.SignalStrength
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 信号强度采集：WiFi RSSI / 蜂窝信号等级，供播放页 HUD 展示。
 * 不需要定位权限：只读当前连接的 RSSI 与 LISTEN_SIGNAL_STRENGTHS（无权限要求）。
 */
class SignalMeter : MethodChannel.MethodCallHandler {

    private var appContext: Context? = null
    private var lastCellLevel = -1

    fun attach(context: Context, messenger: BinaryMessenger) {
        appContext = context.applicationContext
        MethodChannel(messenger, "iradio/signal").setMethodCallHandler(this)
        registerCellListener()
    }

    /** 持续监听蜂窝信号等级（缓存最新值，轮询直接读）。 */
    @Suppress("DEPRECATION")
    private fun registerCellListener() {
        try {
            val tm = appContext?.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                ?: return
            if (Build.VERSION.SDK_INT >= 31) {
                tm.registerTelephonyCallback(
                    appContext!!.mainExecutor,
                    object : TelephonyCallback(), TelephonyCallback.SignalStrengthsListener {
                        override fun onSignalStrengthsChanged(signalStrength: SignalStrength) {
                            lastCellLevel = signalStrength.level
                        }
                    },
                )
            } else {
                tm.listen(
                    object : PhoneStateListener() {
                        override fun onSignalStrengthsChanged(signalStrength: SignalStrength?) {
                            lastCellLevel = signalStrength?.level ?: -1
                        }
                    },
                    PhoneStateListener.LISTEN_SIGNAL_STRENGTHS,
                )
            }
        } catch (_: Exception) {
            // 个别设备/无 SIM 时失败，轮询路径仍有兜底。
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSignal" -> result.success(readSignal())
            else -> result.notImplemented()
        }
    }

    /** 返回 {type: wifi|cell|none, rssi: dBm 或 null, level: 0..4}。 */
    private fun readSignal(): Map<String, Any?> {
        val ctx = appContext ?: return mapOf("type" to "none")
        val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val caps = try {
            cm?.getNetworkCapabilities(cm.activeNetwork)
        } catch (_: Exception) {
            null
        } ?: return mapOf("type" to "none")

        val isWifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        val isCell = caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        if (!isWifi && !isCell) return mapOf("type" to "none")

        return if (isWifi) {
            readWifi(ctx)
        } else {
            readCellular(ctx)
        }
    }

    @Suppress("DEPRECATION")
    private fun readWifi(ctx: Context): Map<String, Any?> {
        return try {
            val wm = ctx.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val rssi = wm.connectionInfo?.rssi ?: -127
            mapOf(
                "type" to "wifi",
                "rssi" to rssi,
                "level" to WifiManager.calculateSignalLevel(rssi, 5),
            )
        } catch (_: Exception) {
            mapOf("type" to "wifi", "rssi" to null, "level" to 0)
        }
    }

    private fun readCellular(ctx: Context): Map<String, Any?> {
        var dbm: Int? = null
        var level = lastCellLevel
        try {
            val tm = ctx.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            val ss = tm?.signalStrength
            if (ss != null) {
                level = ss.level
                if (Build.VERSION.SDK_INT >= 29) {
                    dbm = ss.cellSignalStrengths.maxByOrNull { it.level }?.dbm
                }
            }
        } catch (_: Exception) {
        }
        return mapOf("type" to "cell", "rssi" to dbm, "level" to level)
    }
}
