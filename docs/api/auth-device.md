# 账号认证与设备 API

> 文件说明：本文档记录账号注册、登录、刷新令牌、退出登录和设备登记接口。

## 通用约定

- 请求和响应使用 JSON。
- 响应内容类型为 `application/json; charset=utf-8`。
- 设备登记接口需要 `Authorization: Bearer <accessToken>`。

## 错误结构

```json
{"error":{"code":"invalid_request","message":"请求无效"}}
```

## 注册

```text
POST /api/auth/register
```

请求：

```json
{"email":"user@example.com","password":"pass123456","displayName":"用户"}
```

成功响应：

```json
{"user":{"id":"usr_...","email":"user@example.com","displayName":"用户"},"accessToken":"...","refreshToken":"..."}
```

## 登录

```text
POST /api/auth/login
```

请求：

```json
{"email":"user@example.com","password":"pass123456"}
```

成功响应与注册一致。

## 刷新令牌

```text
POST /api/auth/refresh
```

请求：

```json
{"refreshToken":"..."}
```

成功响应：

```json
{"accessToken":"...","refreshToken":"..."}
```

## 退出登录

```text
POST /api/auth/logout
```

请求：

```json
{"refreshToken":"..."}
```

成功响应：

```json
{"status":"ok"}
```

## 设备登记

```text
POST /api/devices/register
```

请求头：

```text
Authorization: Bearer <accessToken>
```

请求：

```json
{"deviceName":"Windows 主力机","platform":"windows"}
```

成功响应：

```json
{"device":{"id":"dev_...","userId":"usr_...","deviceName":"Windows 主力机","platform":"windows"}}
```
