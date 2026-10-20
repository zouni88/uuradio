import 'dart:async';

/// 应用异常：把底层错误翻译成用户可读的分类。
enum AppErrorType { network, timeout, server, unknown }

class AppException implements Exception {
  const AppException(this.type, {this.detail});

  final AppErrorType type;
  final String? detail;

  factory AppException.from(Object error) {
    if (error is AppException) return error;
    if (error is TimeoutException) {
      return const AppException(AppErrorType.timeout);
    }
    final text = error.toString();
    if (text.contains('DioException') ||
        text.contains('SocketException') ||
        text.contains('Connection')) {
      return AppException(AppErrorType.network, detail: text);
    }
    return AppException(AppErrorType.unknown, detail: text);
  }

  @override
  String toString() => 'AppException(${type.name}, $detail)';
}
