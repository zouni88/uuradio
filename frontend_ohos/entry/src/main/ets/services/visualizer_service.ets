// 频谱采集：AudioCapturer 麦克风 PCM + 1024 点 FFT + 对数分桶 32 段（0~1 归一化）。
// 对齐 Flutter 原生 SignalMeter 的输出语义；未授权/失败由上层降级合成动画。
import { audio } from '@kit.AudioKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

const FFT_SIZE = 1024;
const BAND_COUNT = 32;
/// 峰值归一化基数（实测调优值）。
const NORMALIZE = 40000.0;

export class VisualizerService {
  private capturer: audio.AudioCapturer | null = null;
  onBands: ((bands: number[]) => void) | null = null;

  // FFT 缓冲
  private re: Float64Array = new Float64Array(FFT_SIZE);
  private im: Float64Array = new Float64Array(FFT_SIZE);
  private revTable: Int32Array = new Int32Array(FFT_SIZE);
  private window: Float64Array = new Float64Array(FFT_SIZE);
  private pending: number[] = [];
  private bandEdges: number[] = [];

  /// 请求麦克风授权（系统弹窗）。已授权/授权成功返回 true。
  static async requestMicPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = ['ohos.permission.MICROPHONE'];
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      for (const r of result.authResults) {
        if (r !== 0) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 启动采集。失败返回 false（未授权/设备不支持）。
  async start(): Promise<boolean> {
    try {
      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const capturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };
      const options: audio.AudioCapturerOptions = {
        streamInfo: streamInfo,
        capturerInfo: capturerInfo
      };
      this.initFft();
      this.capturer = await audio.createAudioCapturer(options);
      this.capturer.on('readData', (buffer: ArrayBuffer) => {
        this.onAudioData(buffer);
      });
      await this.capturer.start();
      return true;
    } catch (e) {
      this.capturer = null;
      return false;
    }
  }

  async stop(): Promise<void> {
    try {
      await this.capturer?.stop();
      await this.capturer?.release();
    } catch (e) {
    }
    this.capturer = null;
    this.pending = [];
  }

  private initFft(): void {
    // 位反转表
    let bits = 0;
    while ((1 << bits) < FFT_SIZE) {
      bits++;
    }
    for (let i = 0; i < FFT_SIZE; i++) {
      let x = i;
      let r = 0;
      for (let b = 0; b < bits; b++) {
        r = (r << 1) | (x & 1);
        x >>= 1;
      }
      this.revTable[i] = r;
    }
    // Hamming 窗
    for (let i = 0; i < FFT_SIZE; i++) {
      this.window[i] = 0.54 - 0.46 * Math.cos((2 * Math.PI * i) / (FFT_SIZE - 1));
    }
    // 对数分桶边界（bin 2 ≈ 86Hz → bin 511 ≈ Nyquist）
    const loBin = 2;
    const hiBin = FFT_SIZE / 2;
    this.bandEdges = [loBin];
    for (let b = 1; b <= BAND_COUNT; b++) {
      const edge = Math.round(loBin * Math.pow(hiBin / loBin, b / BAND_COUNT));
      const prev = this.bandEdges[b - 1];
      this.bandEdges.push(Math.max(prev + 1, Math.min(edge, hiBin)));
    }
  }

  private onAudioData(buffer: ArrayBuffer): void {
    if (this.onBands === null) {
      return;
    }
    const samples = new Int16Array(buffer);
    for (let i = 0; i < samples.length; i++) {
      this.pending.push(samples[i]);
    }
    // 只保留最近一帧
    if (this.pending.length > FFT_SIZE) {
      this.pending = this.pending.slice(this.pending.length - FFT_SIZE);
    }
    if (this.pending.length === FFT_SIZE) {
      const bands = this.computeBands();
      this.onBands(bands);
    }
  }

  private computeBands(): number[] {
    const n = FFT_SIZE;
    for (let i = 0; i < n; i++) {
      this.re[i] = (this.pending[i] / 32768.0) * this.window[i];
      this.im[i] = 0;
    }
    // 位反转置换
    for (let i = 0; i < n; i++) {
      const j = this.revTable[i];
      if (j > i) {
        let tmp = this.re[i];
        this.re[i] = this.re[j];
        this.re[j] = tmp;
        tmp = this.im[i];
        this.im[i] = this.im[j];
        this.im[j] = tmp;
      }
    }
    // 迭代基-2 蝶形
    for (let size = 2; size <= n; size <<= 1) {
      const half = size >> 1;
      const step = (2 * Math.PI) / size;
      for (let i = 0; i < n; i += size) {
        for (let j = 0; j < half; j++) {
          const angle = step * j;
          const wr = Math.cos(angle);
          const wi = -Math.sin(angle);
          const a = i + j;
          const b = a + half;
          const tr = this.re[b] * wr - this.im[b] * wi;
          const ti = this.re[b] * wi + this.im[b] * wr;
          this.re[b] = this.re[a] - tr;
          this.im[b] = this.im[a] - ti;
          this.re[a] += tr;
          this.im[a] += ti;
        }
      }
    }
    // 对数分桶取峰值
    const bands: number[] = [];
    for (let b = 0; b < BAND_COUNT; b++) {
      const lo = this.bandEdges[b];
      const hi = this.bandEdges[b + 1];
      let peak = 0;
      for (let k = lo; k < hi; k++) {
        const mag = Math.sqrt(this.re[k] * this.re[k] + this.im[k] * this.im[k]);
        if (mag > peak) {
          peak = mag;
        }
      }
      let v = peak / NORMALIZE;
      if (v < 0) {
        v = 0;
      }
      if (v > 1) {
        v = 1;
      }
      bands.push(v);
    }
    return bands;
  }
}
