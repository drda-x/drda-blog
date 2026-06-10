---
title: Hexo 初体验
banner: https://img.8845.top/img2/%E3%80%8A%E4%BA%B2%E7%88%B1%E7%9A%84%E5%BC%97%E5%85%B0%E5%85%8B%E6%96%AF%E3%80%8B024k.jpg
cover: https://img.8845.top/img2/%E3%80%8A%E4%BA%B2%E7%88%B1%E7%9A%84%E5%BC%97%E5%85%B0%E5%85%8B%E6%96%AF%E3%80%8B024k.jpg
date: 2026-06-08
tags:
  - hexo
  - github
categories: 博客
---

一直想搭建一个属于自己的个人博客，记录学习和生活。试过多种方案后，最终选择了 **Hexo + GitHub Pages**，原因是：免费、静态、速度快、主题丰富。下面把完整的搭建过程记录下来，希望能帮到有同样需求的朋友。

## 前置准备

在开始之前，确保你的环境已经准备好：

1. **Node.js 和 npm**（建议使用 nvm 管理版本）
2. **Git** 和 **GitHub 账号**
3. **VS Code** 或任意代码编辑器

## 第一步：安装 Hexo CLI

打开终端，全局安装 Hexo 命令行工具：

```bash
npm install -g hexo-cli
```

安装完成后，验证是否成功：

```bash
hexo -v
```

## 第二步：初始化项目

创建一个文件夹，名字随便取，例如 `myHexo`，然后进入该目录执行初始化：

```bash
mkdir myHexo
cd myHexo
hexo init
npm install
```

`hexo init` 会自动下载依赖并生成目录结构，看到提示 **"start blogging with hexo!"** 就成功了。目录结构如下：

```
myHexo/
├── _config.yml          # 站点配置文件
├── package.json
├── scaffolds/             # 文章模板
├── source/                # 源文件（文章、页面）
├── themes/                # 主题目录
└── node_modules/
```

## 第三步：本地预览

启动本地服务器，默认端口 4000：

```bash
hexo server
# 或简写
hexo s
```

浏览器打开 `http://localhost:4000`，就能看到默认的 Hello World 页面了。按 `Ctrl + C` 停止服务。

## 第四步：创建 GitHub 仓库

1. 登录 GitHub，新建一个仓库
2. 仓库名必须是 **`你的用户名.github.io`**（这是 GitHub Pages 的规则）
3. 保持仓库为空（不要勾选 README），记录仓库地址：

```
https://github.com/你的用户名/你的用户名.github.io.git
```

## 第五步：配置部署

打开项目根目录的 `_config.yml`，翻到最底部，找到 `deploy` 字段并修改为：

```yaml
deploy:
  type: git
  repo: https://github.com/你的用户名/你的用户名.github.io.git
  branch: main
```

> 注意：`branch` 的值根据你的仓库默认分支填写，旧版 GitHub 可能是 `master`。

同时把 `_config.yml` 顶部的 `url` 字段改成你的站点地址：

```yaml
url: https://你的用户名.github.io
```

## 第六步：安装部署插件

Hexo 默认不自带 Git 部署功能，需要额外安装插件：

```bash
npm install hexo-deployer-git --save
```

## 第七步：生成并推送

首次部署前，建议先执行生成命令：

```bash
hexo generate
# 或简写
hexo g
```

然后一键部署到 GitHub：

```bash
hexo deploy
# 或简写
hexo d
```

等待命令执行完毕，浏览器访问 `https://你的用户名.github.io`，博客就上线了！

## 常用命令总结

| 命令 | 作用 |
|---|---|
| `hexo new "文章标题"` | 新建文章 |
| `hexo server` | 启动本地预览 |
| `hexo generate` | 生成静态文件 |
| `hexo deploy` | 部署到远程 |
| `hexo clean` | 清理缓存和已生成文件 |
| `hexo clean && hexo generate && hexo deploy` | 完整发布流程 |

## 常见问题

- **部署失败提示 `Authentication failed`**：说明你用的是 HTTPS 协议，需要输入用户名密码，或者提前配置 SSH key 免密推送。
- **页面样式丢失**：检查 `_config.yml` 里的 `url` 和 `root` 是否配置正确。
- **修改后不生效**：先 `hexo clean` 再重新生成。

## 写在最后

Hexo 的社区非常活跃，主题和插件都很丰富。后续可以尝试换主题、加评论系统、接入 CDN 加速等。搭建博客只是第一步，持续输出内容才是重点。加油！
