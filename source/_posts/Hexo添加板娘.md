---
title: Hexo添加板娘
banner: https://img.8845.top/img2/%E3%80%8ARe%EF%BC%9A%E4%BB%8E%E9%9B%B6%E5%BC%80%E5%A7%8B%E7%9A%84%E5%BC%82%E4%B8%96%E7%95%8C%E7%94%9F%E6%B4%BB%E3%80%8B%E9%9B%B7%E5%A7%866k.png
cover: https://img.8845.top/img2/%E3%80%8ARe%EF%BC%9A%E4%BB%8E%E9%9B%B6%E5%BC%80%E5%A7%8B%E7%9A%84%E5%BC%82%E4%B8%96%E7%95%8C%E7%94%9F%E6%B4%BB%E3%80%8B%E9%9B%B7%E5%A7%866k.png
sticky: false
date: 2025-12-17 14:26:29
categories: 
 - 笔记
tags:
 - hexo
---

## 前言

Live2D 看板娘可以为博客增添趣味性和互动感。本文以 Reimu 主题为例，介绍两种添加看板娘的方式：**主题内置** 和 **自定义配置**。

---

## 方式一：使用主题内置的 Live2D（推荐新手）

很多 Hexo 主题（如 Reimu、Butterfly 等）已经集成了 Live2D 功能，只需简单配置即可启用。

### 1. 开启方法

打开主题配置文件 `themes/reimu/_config.yml`，找到 `live2d` 配置节：

```yaml
# Experimental
live2d:
  enable: true
```
将 `enable` 改为 `true`，保存后重启 Hexo 即可看到看板娘。

![kbn.png](https://file.fishpi.cn/2026/06/kbn-38f3482a.png)

在页面中有多个板娘可以进行切换，还可以换装，拍照等许多互动体验。想了解更多功能实现可以访问[https://github.com/LIlGG/plugin-live2d](https://github.com/LIlGG/plugin-live2d)

### 2. 原理说明

Reimu 主题内置的 Live2D 使用 [D-Sketon/plugin-live2d](https://github.com/D-Sketon/plugin-live2d) 库，脚本从 CDN 自动加载，无需额外安装任何依赖。

## 方式二：使用 hexo-helper-live2d 插件（推荐进阶用户）

如果需要更多模型选择或使用本地模型，可以使用 `hexo-helper-live2d` 插件。

### 1. 安装插件

```bash
npm install hexo-helper-live2d --save
```

### 2. 安装模型

**方式 A：使用 npm 模型包（推荐）**

```bash
# 模型包
npm install live2d-widget-model-shizuku --save   # 诗库
npm install live2d-widget-model-koharu --save    # 小春
npm install live2d-widget-model-hijiki --save    # 羊驼
npm install live2d-widget-model-tororo --save    # 小白
```

**方式 B：使用本地模型**

如果你有自定义的模型文件，可以放在项目根目录的 `live2d_modules/` 目录下，结构如下：

```
live2d_modules/
└── live2D/
    ├── js/
    │   ├── live2d.min.js
    │   └── message.js
    └── model/
        └── xiaomai/
            ├── xiaomai.model.json
            ├── umaru.moc
            └── ...
```

### 3. 配置插件

在站点配置文件 `_config.yml`（不是主题的）中添加：

```yaml
# live2d
live2d:
  enable: true
  scriptFrom: local
  pluginRootPath: live2dw/      # 静态资源根路径
  pluginJsPath: lib/            # JS 文件路径
  pluginModelPath: assets/      # 模型文件路径
  tagMode: false
  log: false
  model:
    use: live2d-widget-model-hijiki  # npm 包名称
  display:
    position: right             # 位置：left 或 right
    width: 150                  # 宽度
    height: 300                 # 高度
  mobile:
    show: true                  # 移动端是否显示
  react:
    opacity: 0.7                # 透明度
```

**如果使用本地模型**，将 `model.use` 改为本地目录路径：

```yaml
model:
  use: live2d_modules/live2D/model/xiaomai # 这里我使用的是自定义的小埋模型
```

> **注意**：`model.use` 应该指向模型**目录**，而不是 `.model.json` 文件本身。

### 4. 禁用主题内置的 Live2D

使用插件时，记得禁用主题内置的 Live2D，避免冲突：

```yaml
# themes/reimu/_config.yml
live2d:
  enable: false
```

### 5. 测试

```bash
hexo clean
hexo server
```

访问 `http://localhost:4000`，查看看板娘是否正常显示。

---

### 如何更换模型

只需修改 `model.use` 的值：

```yaml
# 使用 npm 包
model:
  use: live2d-widget-model-shizuku

# 或使用本地模型
model:
  use: live2d_modules/live2D/model/shizuku
```

---

## 总结

如果只是想让博客多个看板娘，直接用主题内置的最简单；如果想深度定制或使用自己的模型，选择 `hexo-helper-live2d` 插件。
