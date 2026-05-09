# 轻量多端同步笔记

> 文件说明：本文档介绍项目目标、目录结构、当前状态和本地开发入口。

本项目是一个本地优先的轻量多端同步笔记应用，计划覆盖 Windows 端和 Android 端。客户端使用 Flutter，后端使用 Go，自建同步服务负责账号、设备、笔记、附件和多端同步。

## 当前状态

当前仓库处于基础设计和工程骨架阶段。已完成第一版设计文档，尚未开始业务功能实现。

## 第一版目标

- 支持账号注册、登录和退出登录。
- 支持 Windows 和 Android 客户端。
- 支持文件夹、笔记、图片附件、外部链接和内部笔记链接。
- 支持本地离线编辑。
- 支持多端同步。
- 支持冲突副本，避免覆盖用户内容。

## 技术栈

- 客户端：Flutter、Dart、SQLite。
- 后端：Go、PostgreSQL。
- 附件：可插拔存储层，开发默认本地文件存储，生产可切换对象存储。
- 文档：中文 Markdown。

## 目录结构

```text
apps/
  client/                 Flutter 客户端
services/
  api/                    Go 同步后端
docs/
  development/            开发规范和本地运行说明
  superpowers/
    specs/                设计文档
    plans/                实现计划
```

## 编码与注释约束

- 所有文本和代码文件使用 UTF-8 编码。
- 文档使用中文。
- 代码相关文件开头添加简单文件说明注释。
- 每个方法或函数添加简单注释。
- 重要阶段提交 git，并推送到 GitHub。

## 设计文档

第一版设计文档位于：

```text
docs/superpowers/specs/2026-05-09-note-app-design.md
```

## 本地运行

本地运行方式见：

```text
docs/development/local-run.md
```
