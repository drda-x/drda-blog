---
title: Git 首次提交代码
banner: "https://img.8845.top/img2/7.jpg"
cover: "https://img.8845.top/img2/7.jpg"
date: 2023-04-12 13:19:00
categories: [笔记]
tags: [git]
---
记录一下本地项目第一次提交到 Git 仓库的完整流程。

## 1. 初始化仓库

进入项目根目录，执行：

```bash
git init
```
![3e2a4097ec980299bfc089d7c5746a6c.gif.gif](https://raw.githubusercontent.com/drda-x/images/main/2026/06/1782779878106.gif)
该命令会在当前目录生成一个 `.git` 隐藏目录，Git 会从这里开始追踪所有文件的变更。

## 2. 配置用户信息

首次使用 Git 必须要配置用户名和邮箱，否则提交会失败：

```bash
git config --global user.name "你的用户名"
git config --global user.email "your_email@example.com"
```

`--global` 表示对当前用户下所有仓库生效。如果只想对当前仓库配置，去掉 `--global` 即可。

## 3. 添加文件到暂存区

把项目所有文件加入 Git 追踪：

```bash
git add .          # 添加全部文件
git add <file>     # 添加指定文件
```

`.` 表示当前目录下的所有文件。

## 4. 提交到本地仓库

```bash
git commit -m "首次提交：项目初始化"
```

`-m` 后面是本次提交的说明信息，**建议用简短的中文或英文描述本次提交的内容**。

## 5. 关联远程仓库

以 GitHub 为例，先在 GitHub 上新建一个空仓库，复制仓库地址（HTTP 或 SSH 形式），然后执行：

```bash
git remote add origin https://github.com/your_name/your_repo.git
```

`origin` 是远程仓库的默认别名，可以自定义，但一般都用 `origin`。

## 6. 推送到远程

第一次推送需要加上 `-u` 参数，建立本地分支与远程分支的关联：

```bash
git push -u origin main
```

如果是旧版 Git，默认分支可能是 `master`，根据实际情况替换即可。

## 常见问题

- **推送时提示输入用户名密码**：说明使用的是 HTTPS 协议，可以改用 SSH 密钥方式免密推送。
- **`! [rejected] (non-fast-forward)`**：远程有本地没有的提交，需要先 `git pull --rebase` 再推送。
- **大文件推送失败**：GitHub 不允许单个文件超过 100MB，可以考虑使用 Git LFS。

完成以上步骤后，代码就已经成功推送到远程仓库了 🎉
