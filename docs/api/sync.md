# 同步 API

> 文件说明：本文档记录文件夹和笔记的服务端同步接口。

## 通用约定

- 请求和响应使用 JSON。
- 响应内容类型为 `application/json; charset=utf-8`。
- 同步接口都需要 `Authorization: Bearer <accessToken>`。
- `updatedAt` 使用 Unix 纳秒。
- `serverVersion` 是服务端分配的递增版本。

## 推送变更

```text
POST /api/sync/push
```

请求头：

```text
Authorization: Bearer <accessToken>
```

请求：

```json
{
  "folders": [
    {
      "id": "fld_inbox",
      "name": "收件箱",
      "parentId": "",
      "deleted": false,
      "updatedAt": 1770000000000000000
    }
  ],
  "notes": [
    {
      "id": "note_1",
      "folderId": "fld_inbox",
      "title": "第一篇笔记",
      "body": "正文",
      "deleted": false,
      "updatedAt": 1770000000000000001
    }
  ]
}
```

成功响应：

```json
{
  "serverVersion": 2,
  "folders": [{"id": "fld_inbox", "serverVersion": 1}],
  "notes": [{"id": "note_1", "serverVersion": 2}]
}
```

## 拉取变更

```text
GET /api/sync/pull?since=0
```

请求头：

```text
Authorization: Bearer <accessToken>
```

成功响应：

```json
{
  "serverVersion": 2,
  "folders": [
    {
      "id": "fld_inbox",
      "name": "收件箱",
      "deleted": false,
      "updatedAt": 1770000000000000000,
      "serverVersion": 1
    }
  ],
  "notes": [
    {
      "id": "note_1",
      "folderId": "fld_inbox",
      "title": "第一篇笔记",
      "body": "正文",
      "deleted": false,
      "updatedAt": 1770000000000000001,
      "serverVersion": 2
    }
  ]
}
```

## 错误结构

```json
{"error":{"code":"invalid_request","message":"请求无效"}}
```

常见错误：

- `401 unauthorized`：未登录或访问令牌无效。
- `400 invalid_request`：JSON 无效或 `since` 不是数字。
- `500 internal_error`：服务端存储失败。
