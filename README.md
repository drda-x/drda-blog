# 加辣の秘密基地

> 奶茶少糖，喜欢吃辣

个人技术博客，记录前端开发、工具使用和踩坑日常。

**在线地址**: [https://drda-x.github.io/drda-blog](https://drda-x.github.io/drda-blog)

---

## 技术栈

- [Hexo](https://hexo.io/) 7.3.0 — 静态博客框架
- [hexo-theme-reimu](https://github.com/D-Sketon/hexo-theme-reimu) — 主题
- [pnpm](https://pnpm.io/) — 包管理器
- GitHub Pages — 托管与部署

---

## 本地开发

```bash
# 1. 安装依赖
pnpm install

# 2. 启动预览
hexo server
# 或
pnpm run server
```

浏览器打开 [http://localhost:4000](http://localhost:4000)。

---

## 写作与部署

### 新建文章

```bash
hexo new post "文章标题"
```

在 `source/_posts/文章标题.md` 中补充 front-matter：

```markdown
---
title: 文章标题
banner: https://img.8845.top/img2/xxx.jpg
cover: https://img.8845.top/img2/xxx.jpg
date: 2026-06-09
categories: 前端
tags:
  - Vue
---

正文内容...
```

### 一键部署

Windows 下直接双击运行：

```bash
deploy.bat
```

或手动执行：

```bash
hexo clean && hexo generate && hexo deploy
```

---

## 项目结构

```
drdaBlog/
├── source/
│   └── _posts/          # 博客文章
├── themes/
│   └── reimu/           # 主题配置
├── _config.yml          # 站点配置
├── _config.reimu.yml    # 主题配置
├── deploy.bat           # 一键部署脚本
└── package.json
```

---

## 注意事项

- 部署目标为 GitHub Pages 项目站点，访问路径为 `/drda-blog/`
- `_config.yml` 中不要提交敏感 token（如 GitHub PAT），建议通过环境变量注入
- 本地预览时如遇 `Cannot find module 'babel-plugin-inferno'` 等错误，确保 `.npmrc` 中已配置 `shamefully-hoist=true`

