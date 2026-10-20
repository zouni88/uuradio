// 霓虹频谱视图：32 根渐变圆角柱 + 光晕 + 顶端亮点（Canvas 复刻 Flutter SpectrumPainter）。
import { VisualizerController } from '../../controllers/visualizer_controller';
import { darkScheme, DEFAULT_ACCENT } from '../../core/theme';

function cssColor(c: number, alpha: number): string {
  const r = (c >> 16) & 0xFF;
  const g = (c >> 8) & 0xFF;
  const b = c & 0xFF;
  return `rgba(${r},${g},${b},${alpha})`;
}

@Component
export struct SpectrumView {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  playing: boolean = false;
  @State private bands: number[] = [];
  private vc: VisualizerController = VisualizerController.inst();
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private cb: () => void = () => {
    this.bands = this.vc.bands;
    this.draw();
  };

  aboutToAppear(): void {
    this.bands = this.vc.bands;
    this.vc.addListener(this.cb);
  }

  aboutToDisappear(): void {
    this.vc.removeListener(this.cb);
  }

  private draw(): void {
    const ctx = this.ctx;
    const w = ctx.width;
    const h = ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const scheme = darkScheme(this.accent);
    const color = this.accent;
    const topColor = scheme.secondary;
    ctx.clearRect(0, 0, w, h);

    const bands = this.bands;
    const count = bands.length === 0 ? 32 : bands.length;
    const gap = w * 0.008;
    const barW = (w - gap * (count - 1)) / count;
    const radius = barW / 2;
    const minH = h * 0.04;

    for (let i = 0; i < count; i++) {
      const value = i < bands.length ? bands[i] : 0;
      const clamped = Math.min(Math.max(value, 0), 1);
      const intensity = this.playing ? value : value * 0.12;
      const bh = Math.max(minH, h * Math.min(Math.max(intensity, 0), 1));
      const x = i * (barW + gap);
      const y = h - bh;

      // 光晕层（播放中且柱体可见时）
      if (this.playing && value > 0.02) {
        ctx.shadowColor = cssColor(color, 0.4 * clamped);
        ctx.shadowBlur = 9;
        ctx.shadowOffsetX = 0;
        ctx.shadowOffsetY = 0;
      } else {
        ctx.shadowBlur = 0;
      }

      // 渐变柱体
      const grad = ctx.createLinearGradient(0, h, 0, y);
      grad.addColorStop(0, cssColor(color, 0.45));
      grad.addColorStop(0.5, cssColor(color, 1));
      grad.addColorStop(1, cssColor(topColor, 1));
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.roundRect(x, y, barW, bh, radius);
      ctx.fill();

      ctx.shadowBlur = 0;

      // 顶端亮点
      if (this.playing && value > 0.04) {
        ctx.fillStyle = cssColor(0xFFFFFF, 0.85);
        ctx.beginPath();
        ctx.arc(x + barW / 2, y, barW * 0.28, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.draw();
      })
  }
}
