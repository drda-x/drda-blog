---
title: Hexo自动部署到 GitHub Pages
banner: https://img.8845.top/img2/126611624.jpg
cover: https://img.8845.top/img2/126611624.jpg
sticky: false
date: 2026-07-14 13:58:10
categories: 
 - 笔记
tags: 
 - hexo
---


## 介绍
本文记录如何在写好文章后通过 GitHub Actions 自动使用 `hexo deploy` 将生成的站点发布到 GitHub Pages。

**前提**
- 已在 `package.json` 中配置好 `build`/`deploy` 脚本（本仓库使用 `pnpm build`/`pnpm deploy`）。
- 已安装 `hexo-deployer-git`（见 `package.json` 依赖）。
- `_config.yml` 中 `deploy` 字段已填写正确的 `repo`（例如 `https://github.com/<user>/<repo>.git`）和 `branch`（通常为 `gh-pages`）。

如果以上都就绪，下面按步骤配置 GH Actions：

1. 在仓库中添加工作流文件 ` .github/workflows/deploy.yml `（已示例加入仓库）。工作流主要流程：检出代码 -> 安装 Node 与 pnpm -> 安装依赖 -> 生成站点 -> 运行 `pnpm deploy`。

2. 我们的工作流示例要点：
- 使用 `actions/checkout`、`actions/setup-node` 和 `pnpm/action-setup` 来准备环境。
- 使用 `pnpm install --frozen-lockfile` 保持依赖一致性，然后 `pnpm build` 生成 `public`。
- 为了让 `hexo-deployer-git` 能推送到 `gh-pages`，工作流中用 `git config` 将 `https://github.com/` 替换为带 `${{ secrets.GITHUB_TOKEN }}` 的 URL，这样 `hexo deploy` 使用 HTTPS 推送时会带上 token：

```yaml
# 关键片段（完整文件位于 .github/workflows/deploy.yml）
- name: Configure Git for hexo deploy
	run: |
		git config --global user.name "github-actions[bot]"
		git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
		git config --global url."https://${{ secrets.GITHUB_TOKEN }}@github.com/".insteadOf "https://github.com/"

- name: Deploy with Hexo
	run: pnpm deploy
	env:
		CI: false
```

3. 提交并推送工作流文件后，往主分支（`main`/`master`）推送内容会触发自动构建与部署。提交示例命令：

```powershell
git add .github/workflows/deploy.yml
git commit -m "ci: use hexo deploy in GH Actions"
git push
```

4. 常见注意事项与排查
- 如果站点构建失败：检查 `pnpm install` 输出的错误与 `node` 版本（工作流中可指定 `node-version`）。
- 如果 `hexo deploy` 推送失败：确认 `_config.yml` 中 `deploy.repo` 填写完整（包含 `.git`）或使用相应的 `repo` URL；查看 Actions 日志中 `git` 的真实 push URL（替换规则应已把 token 注入）。
- 如果你需要使用自定义 PAT（权限更宽的 token，例如跨仓库），可以把 `secrets.GITHUB_TOKEN` 换为 `secrets.DEPLOY_TOKEN`，并在仓库 Settings -> Secrets 中添加。

5. 本仓库已完成的改动概览
- 添加工作流：`.github/workflows/deploy.yml`，在构建后调用 `pnpm deploy` 并通过 `git config` 注入 token。 

如果你希望我把文章补充为更详细的调试步骤（包含 Actions 日志示例、常见报错及解决办法），或把文章内容同步到 `README.md`，告诉我需要的深度，我来继续完善。 

