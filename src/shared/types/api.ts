export interface TagResp {
  id: string;
  name: string;
  color: string;
  sort: number;
  description: string;
  createTime: string;
  updateTime: string;
}

export interface BookmarkResp {
  id: string;
  namespaceId: string;
  name: string;
  description: string;
  url: string;
  icon: string;
  num: number;
  star: boolean;
  tags: TagResp[];
}

export interface BookmarkTreeResp {
  spaceId: string;
  spaceName: string;
  spaceDescription: string;
  bookmarks: BookmarkResp[];
}

export interface NewSpace {
  name: string;
  description?: string;
  icon?: string;
}

export interface NewTag {
  name: string;
  color: string;
  description?: string;
}

export interface AddBookmarkReq {
  name: string;
  url: string;
  description?: string;
  namespaceId?: string;
  tagsIds?: string[];
  newSpace?: NewSpace;
  newTags?: NewTag[];
}

export interface ApiResult<T> {
  code: number;
  message: string;
  description: string;
  data: T;
  date: number;
  flag: boolean;
  messageId: string;
}

export interface MostVisitedParams {
  limit: number;
  search?: string;
}

export interface SnSpace {
  id: string;
  userId: string;
  name: string;
  pinyin: string;
  abbreviation: string;
  icon: string;
  sort: number;
  share: boolean;
  shareKey: string;
  description: string;
  createTime: string;
  updateTime: string;
  deleted: number;
}

export type ResultBookmarkResp = ApiResult<BookmarkResp>;
export type ResultListBookmarkResp = ApiResult<BookmarkResp[]>;
export type ResultListBookmarkTreeResp = ApiResult<BookmarkTreeResp[]>;
export type ResultListSnSpace = ApiResult<SnSpace[]>;
export type ResultListTagResp = ApiResult<TagResp[]>;
export type ResultString = ApiResult<string>;