package com.iradio.iradio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// 频谱分桶数（与 Flutter 侧 VisualizerState.bandCount 一致）。
private const val BAND_COUNT = 32

/// RECORD_AUDIO 运行时权限请求码。
private const val REQ_RECORD_AUDIO = 4242

/**
 * Android Visualizer 频谱采集：
 * attach 到 just_audio 的音频会话，FFT 512 bin 对数分桶成 32 段强度推给 Flutter。
 */
class SpectrumVisualizer :
    EventChannel.StreamHandler,
    MethodChannel.MethodCallHandler {

    private var activity: AudioServiceActivity? = null
    private var visualizer: Visualizer? = null
    private var sink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingSessionId: Int? = null
    private var permissionCallback: ((Boolean) -> Unit)? = null

    // 对数分桶边界（bin 1..256，跳过直流分量）。
    private val bandRanges: Array<IntArray> = buildBandRanges()

    fun attach(activity: AudioServiceActivity, messenger: BinaryMessenger) {
        this.activity = activity
        MethodChannel(messenger, "iradio/visualizer").setMethodCallHandler(this)
        EventChannel(messenger, "iradio/visualizer_events").setStreamHandler(this)
    }

    /** 由 MainActivity 转发系统授权弹窗结果。 */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQ_RECORD_AUDIO) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        val callback = permissionCallback
        permissionCallback = null
        callback?.invoke(granted)
    }

    // ---- MethodChannel ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> requestPermission(result)
            "enable" -> {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                result.success(setup(sessionId))
            }
            "disable" -> {
                release()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // ---- EventChannel ----

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        // Flutter 侧后订阅时，先补挂已记录的会话。
        pendingSessionId?.let { id ->
            pendingSessionId = null
            setup(id)
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // ---- 权限 ----

    private fun isRecordAudioGranted(): Boolean {
        return activity?.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.success(false)
            return
        }
        if (isRecordAudioGranted()) {
            result.success(true)
            return
        }
        // 已有待决回调则直接覆盖（前一次弹窗被系统取消）。
        permissionCallback = { granted -> result.success(granted) }
        try {
            act.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQ_RECORD_AUDIO)
        } catch (e: Exception) {
            permissionCallback = null
            result.success(false)
        }
    }

    // ---- 核心逻辑 ----

    private fun setup(sessionId: Int): Boolean {
        if (sessionId <= 0) return false
        if (sink == null) {
            pendingSessionId = sessionId
            return true
        }
        release()
        return try {
            val v = Visualizer(sessionId)
            val sizeRange = Visualizer.getCaptureSizeRange()
            v.captureSize = 1024.coerceIn(sizeRange[0], sizeRange[1])
            // FFT 数据采集由 setDataCaptureListener 的 fft=true 参数开启。
            v.scalingMode = Visualizer.SCALING_MODE_NORMALIZED
            v.measurementMode = Visualizer.MEASUREMENT_MODE_NONE
            v.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(visualizer: Visualizer?, waveform: ByteArray?, samplingRate: Int) {}
                    override fun onFftDataCapture(visualizer: Visualizer?, fft: ByteArray?, samplingRate: Int) {
                        if (fft != null) emitBands(fft)
                    }
                },
                Visualizer.getMaxCaptureRate() / 2,
                false,
                true,
            )
            v.enabled = true
            visualizer = v
            true
        } catch (e: Exception) {
            release()
            false
        }
    }

    private fun release() {
        try {
            visualizer?.enabled = false
            visualizer?.release()
        } catch (_: Exception) {
        }
        visualizer = null
    }

    private fun emitBands(fft: ByteArray) {
        val bands = FloatArray(BAND_COUNT)
        val half = fft.size / 2
        for (b in 0 until BAND_COUNT) {
            val range = bandRanges[b]
            var sum = 0.0
            var count = 0
            var bin = range[0]
            while (bin <= range[1] && bin < half) {
                val re = fft[bin * 2].toDouble()
                val im = fft[bin * 2 + 1].toDouble()
                val magnitude = kotlin.math.sqrt(re * re + im * im) / 128.0
                sum += magnitude
                count++
                bin++
            }
            if (count > 0) {
                // 归一化 + 轻微增益，让低电平电台也有可见起伏。
                bands[b] = (sum / count * 1.8).coerceIn(0.0, 1.0).toFloat()
            }
        }
        val sink = sink ?: return
        mainHandler.post { sink.success(bands.toList()) }
    }

    private fun buildBandRanges(): Array<IntArray> {
        // 只取 ~5kHz 以下的频段（对视觉最有效），对数分布：低频细分、高频渐宽。
        val effectiveBins = 48
        val ranges = mutableListOf<IntArray>()
        var start = 1
        for (b in 0 until BAND_COUNT) {
            val end = Math.pow(effectiveBins.toDouble(), (b + 1).toDouble() / BAND_COUNT)
                .toInt().coerceAtLeast(start).coerceAtMost(255)
            ranges.add(intArrayOf(start, end))
            start = end + 1
        }
        return ranges.toTypedArray()
    }
}

class MainActivity : AudioServiceActivity() {
    private val spectrumVisualizer = SpectrumVisualizer()
    private val signalMeter = SignalMeter()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        spectrumVisualizer.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        signalMeter.attach(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        spectrumVisualizer.onRequestPermissionsResult(requestCode, grantResults)
    }
}
