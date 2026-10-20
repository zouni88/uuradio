// 应用异常：把底层错误翻译成用户可读的分类（对齐 Flutter app_exception.dart）。

export enum AppErrorType {
  network,
  timeout,
  server,
  unknown
}

export class AppException extends Error {
  readonly type: AppErrorType;
  readonly detail: string;

  constructor(type: AppErrorType, detail: string = '') {
    super(`AppException(${type}, ${detail})`);
    this.type = type;
    this.detail = detail;
  }

  static fromError(error: Object): AppException {
    if (error instanceof AppException) {
      return error;
    }
    const text = String(error);
    const lower = text.toLowerCase();
    if (lower.includes('timeout') || lower.includes('timed out')) {
      return new AppException(AppErrorType.timeout, text);
    }
    if (text.includes('Socket') || text.includes('Connection') ||
      lower.includes('network') || lower.includes('failed to connect') ||
      lower.includes('connection reset') || lower.includes('unreachable')) {
      return new AppException(AppErrorType.network, text);
    }
    return new AppException(AppErrorType.unknown, text);
  }
}
