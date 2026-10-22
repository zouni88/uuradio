// RadioBrowser JSON 直接映射（手写序列化）——对齐 Flutter data/dto。
// 本地存储与备份导出共用 toJson；API 解析走 fromJson（双键兼容）。
import { Station, BrowseCategory } from '../domain/models';

function asStr(v: Object | undefined | null, fallback: Object | undefined | null = undefined): string {
  const x = (v === undefined || v === null) ? fallback : v;
  if (x === undefined || x === null) {
    return '';
  }
  const s = `${x}`;
  return s === 'undefined' || s === 'null' ? '' : s;
}

function asInt(v: Object | undefined | null): number {
  if (typeof v === 'number') {
    return Math.trunc(v as number);
  }
  if (typeof v === 'string') {
    const n = parseInt(v as string, 10);
    return isNaN(n) ? 0 : n;
  }
  return 0;
}

function splitCsv(csv: string): string[] {
  return csv.split(',')
    .map((e: string) => e.trim())
    .filter((e: string) => e.length > 0);
}

/// 电台 DTO。
export class StationDto {
  stationuuid: string = '';
  name: string = '';
  url: string = '';
  urlResolved: string = '';
  homepage: string = '';
  favicon: string = '';
  country: string = '';
  countryCode: string = '';
  language: string = '';
  tags: string = '';
  codec: string = '';
  bitrate: number = 0;
  clickCount: number = 0;
  votes: number = 0;

  /// 同时兼容 API 原始键（stationuuid/favicon/...）与本地持久化键
  /// （uuid/logoUrl/streamUrl/...），缓存与收藏读取走同一入口。
  static fromJson(json: Record<string, Object>): StationDto {
    const d = new StationDto();
    d.stationuuid = asStr(json['stationuuid'], json['uuid']);
    d.name = asStr(json['name']);
    d.url = asStr(json['url']);
    d.urlResolved = asStr(json['url_resolved'], json['streamUrl']);
    d.homepage = asStr(json['homepage']);
    d.favicon = asStr(json['favicon'], json['logoUrl']);
    d.country = asStr(json['country']);
    d.countryCode = asStr(json['countrycode'], json['countryCode']);
    d.language = asStr(json['language']);
    d.tags = asStr(json['tags']);
    d.codec = asStr(json['codec']);
    d.bitrate = asInt(json['bitrate']);
    d.clickCount = asInt(json['clickcount'] ?? json['clickCount']);
    d.votes = asInt(json['votes']);
    return d;
  }

  static fromArray(text: string): StationDto[] {
    const arr = JSON.parse(text) as Array<Record<string, Object>>;
    const out: StationDto[] = [];
    for (const item of arr) {
      out.push(StationDto.fromJson(item));
    }
    return out;
  }

  /// 本地持久化格式（camelCase 稳定键，独立于 API 字段）。
  toJson(): Record<string, Object> {
    const m: Record<string, Object> = {
      'uuid': this.stationuuid,
      'name': this.name
    };
    if (this.url.length > 0) {
      m['url'] = this.url;
    }
    m['streamUrl'] = this.urlResolved;
    if (this.homepage.length > 0) {
      m['homepage'] = this.homepage;
    }
    if (this.favicon.length > 0) {
      m['logoUrl'] = this.favicon;
    }
    if (this.country.length > 0) {
      m['country'] = this.country;
    }
    if (this.countryCode.length > 0) {
      m['countryCode'] = this.countryCode;
    }
    if (this.language.length > 0) {
      m['language'] = this.language;
    }
    if (this.tags.length > 0) {
      m['tags'] = this.tags;
    }
    if (this.codec.length > 0) {
      m['codec'] = this.codec;
    }
    if (this.bitrate > 0) {
      m['bitrate'] = this.bitrate;
    }
    if (this.clickCount > 0) {
      m['clickCount'] = this.clickCount;
    }
    if (this.votes > 0) {
      m['votes'] = this.votes;
    }
    return m;
  }

  toJsonString(): string {
    return JSON.stringify(this.toJson());
  }

  toDomain(): Station {
    const s = new Station();
    s.uuid = this.stationuuid;
    s.name = this.name;
    s.streamUrl = this.urlResolved.length > 0 ? this.urlResolved : this.url;
    s.logoUrl = this.favicon;
    s.homepage = this.homepage;
    s.countryCode = this.countryCode;
    s.country = this.country;
    s.languages = splitCsv(this.language);
    s.tags = splitCsv(this.tags);
    s.codec = this.codec;
    s.bitrate = this.bitrate;
    s.clickCount = this.clickCount;
    s.votes = this.votes;
    return s;
  }

  static fromDomain(s: Station): StationDto {
    const d = new StationDto();
    d.stationuuid = s.uuid;
    d.name = s.name;
    d.urlResolved = s.streamUrl;
    d.homepage = s.homepage;
    d.favicon = s.logoUrl;
    d.country = s.country;
    d.countryCode = s.countryCode;
    d.language = s.languages.join(',');
    d.tags = s.tags.join(',');
    d.codec = s.codec;
    d.bitrate = s.bitrate;
    d.clickCount = s.clickCount;
    d.votes = s.votes;
    return d;
  }
}

/// countries / tags / languages 共用分类 DTO。
export class CategoryDto {
  name: string = '';
  stationCount: number = 0;
  isoCode: string = '';

  static fromJson(json: Record<string, Object>): CategoryDto {
    const d = new CategoryDto();
    d.name = asStr(json['name']);
    d.stationCount = asInt(json['stationcount']);
    d.isoCode = asStr(json['iso_3166_1']);
    return d;
  }

  static fromArray(text: string): CategoryDto[] {
    const arr = JSON.parse(text) as Array<Record<string, Object>>;
    const out: CategoryDto[] = [];
    for (const item of arr) {
      out.push(CategoryDto.fromJson(item));
    }
    return out;
  }

  toJson(): Record<string, Object> {
    const m: Record<string, Object> = {
      'name': this.name,
      'stationcount': this.stationCount
    };
    if (this.isoCode.length > 0) {
      m['iso_3166_1'] = this.isoCode;
    }
    return m;
  }

  toJsonString(): string {
    return JSON.stringify(this.toJson());
  }

  toDomain(): BrowseCategory {
    return BrowseCategory.of(this.name, this.stationCount, this.isoCode);
  }
}
