// 领域模型（纯展示，与 API 字段解耦）——对齐 Flutter domain/models。

/// 电台。
export class Station {
  uuid: string = '';
  name: string = '';
  /// 播放永远使用 url_resolved（已解析的最终地址）。
  streamUrl: string = '';
  logoUrl: string = '';
  homepage: string = '';
  countryCode: string = '';
  country: string = '';
  languages: string[] = [];
  tags: string[] = [];
  codec: string = '';
  bitrate: number = 0;
  clickCount: number = 0;
  votes: number = 0;
}

/// 浏览分类（国家 / 标签 / 语言共用）。
export class BrowseCategory {
  name: string = '';
  stationCount: number = 0;
  /// 仅国家有：ISO 3166-1 alpha-2 代码。
  isoCode: string = '';

  static of(name: string, stationCount: number, isoCode: string): BrowseCategory {
    const c = new BrowseCategory();
    c.name = name;
    c.stationCount = stationCount;
    c.isoCode = isoCode;
    return c;
  }
}

/// 电台搜索参数（radio-browser /json/stations/search 常用参数）。
export class StationQuery {
  static readonly ORDER_BY_CLICKS = 'clickcount';
  static readonly ORDER_BY_VOTES = 'votes';
  static readonly ORDER_BY_BITRATE = 'bitrate';
  static readonly ORDER_BY_NAME = 'name';

  name: string = '';
  countryCode: string = '';
  tag: string = '';
  language: string = '';
  order: string = '';
  reverse: boolean = false;
  /// 0 = 不限。
  minBitrate: number = 0;
  limit: number = 50;
  offset: number = 0;

  toQueryParameters(): Record<string, string> {
    const p: Record<string, string> = {};
    if (this.name.length > 0) {
      p['name'] = this.name;
    }
    if (this.countryCode.length > 0) {
      p['countrycode'] = this.countryCode;
    }
    if (this.tag.length > 0) {
      p['tag'] = this.tag;
    }
    if (this.language.length > 0) {
      p['language'] = this.language;
    }
    if (this.order.length > 0) {
      p['order'] = this.order;
    }
    if (this.reverse) {
      p['reverse'] = 'true';
    }
    if (this.minBitrate > 0) {
      p['minBitrate'] = `${this.minBitrate}`;
    }
    p['hidebroken'] = 'true';
    p['limit'] = `${this.limit}`;
    p['offset'] = `${this.offset}`;
    return p;
  }
}

/// 一条播放历史记录。
export class PlayHistoryEntry {
  station: Station = new Station();
  /// epoch 毫秒。
  playedAt: number = 0;
}

/// 备份文件结构（导出/导入共用）。
export class BackupFile {
  app: string = 'iradio';
  version: number = 1;
  exportedAt: string = '';
  stations: BackupStation[] = [];
}

/// 备份文件中的单条电台记录。
export class BackupStation {
  uuid: string = '';
  name: string = '';
  streamUrl: string = '';
  logoUrl: string = '';
  homepage: string = '';
  countryCode: string = '';
  country: string = '';
  tags: string[] = [];
  addedAt: string = '';
}
