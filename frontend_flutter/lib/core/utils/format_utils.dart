/// 展示层格式化工具。
library;

/// 国家代码 → 国旗 emoji（ISO 3166-1 alpha-2 区域指示符）。
String flagEmoji(String countryCode) {
  final code = countryCode.trim().toUpperCase();
  if (code.length != 2) return '📡';
  final base = 0x1F1E6;
  final a = code.codeUnitAt(0) - 65;
  final b = code.codeUnitAt(1) - 65;
  if (a < 0 || a > 25 || b < 0 || b > 25) return '📡';
  return String.fromCharCode(base + a) + String.fromCharCode(base + b);
}

/// 电台展示副标题：国旗 + 国家 + 码率/编码。
String stationSubtitle(String countryCode, String country, int bitrate, String codec) {
  final flag = flagEmoji(countryCode);
  final parts = <String>[
    if (country.isNotEmpty) country,
    if (bitrate > 0) '$bitrate kbps',
    if (codec.isNotEmpty) codec.toUpperCase(),
  ];
  final tail = parts.join(' · ');
  return tail.isEmpty ? flag : '$flag $tail';
}
