package com.uunas.uuradio

import android.content.Context
import android.media.AudioManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 媒体音量控制（车机模式左侧音量滚轮）：
 * get/set STREAM_MUSIC 音量，返回 {volume, max}。
 */
class VolumeControl : MethodChannel.MethodCallHandler {

    private var activity: AudioServiceActivity? = null

    fun attach(activity: AudioServiceActivity, messenger: BinaryMessenger) {
        this.activity = activity
        MethodChannel(messenger, "iradio/volume").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.success(null)
            return
        }
        val am = act.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        when (call.method) {
            "get" -> result.success(volumeMap(am))
            "set" -> {
                val v = call.argument<Int>("volume")
                if (v != null) {
                    am.setStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        v.coerceIn(0, am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)),
                        0,
                    )
                }
                result.success(volumeMap(am))
            }
            else -> result.notImplemented()
        }
    }

    private fun volumeMap(am: AudioManager): Map<String, Int> = mapOf(
        "volume" to am.getStreamVolume(AudioManager.STREAM_MUSIC),
        "max" to am.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
    )
}
