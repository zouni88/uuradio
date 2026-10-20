// HTTP GET 封装：统一超时 / UA / 错误分类（对齐 Flutter dio 配置语义）。
import { http } from '@kit.NetworkKit';
import { AppErrorType, AppException } from './app_exception';

export class Http {
  /**
   * GET JSON 文本。非 2xx 抛 AppException(server/unknown)，超时抛 timeout，其余网络错抛 network。
   */
  static async getJson(url: string, timeoutMs: number, userAgent: string): Promise<string> {
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': userAgent,
          'Accept': 'application/json'
        },
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false
      });
      const code = resp.responseCode;
      if (code >= 200 && code < 300) {
        return resp.result as string;
      }
      throw new AppException(
        code >= 500 ? AppErrorType.server : AppErrorType.unknown,
        `HTTP ${code} ${url}`
      );
    } catch (e) {
      throw AppException.fromError(e);
    } finally {
      req.destroy();
    }
  }
}
