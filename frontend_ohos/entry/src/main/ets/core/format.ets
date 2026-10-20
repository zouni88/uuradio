// 展示层格式化工具（对齐 Flutter format_utils.dart）。

/// 国家代码 → 国旗 emoji（ISO 3166-1 alpha-2 区域指示符）。
export function flagEmoji(countryCode: string): string {
  const code = countryCode.trim().toUpperCase();
  if (code.length !== 2) {
    return '📡';
  }
  const base = 0x1F1E6;
  const a = code.charCodeAt(0) - 65;
  const b = code.charCodeAt(1) - 65;
  if (a < 0 || a > 25 || b < 0 || b > 25) {
    return '📡';
  }
  return String.fromCodePoint(base + a) + String.fromCodePoint(base + b);
}

/// 电台展示副标题：国旗 + 国家 + 码率/编码。
export function stationSubtitle(countryCode: string, country: string, bitrate: number, codec: string): string {
  const flag = flagEmoji(countryCode);
  const parts: string[] = [];
  if (country.length > 0) {
    parts.push(country);
  }
  if (bitrate > 0) {
    parts.push(`${bitrate} kbps`);
  }
  if (codec.length > 0) {
    parts.push(codec.toUpperCase());
  }
  const tail = parts.join(' · ');
  return tail.length === 0 ? flag : `${flag} ${tail}`;
}
