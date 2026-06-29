---
title: VSCode Copilot 接入第三方 OpenAI 兼容接口
date: 2026-06-18 10:07:08
banner: https://img.8845.top/img2/1942944226892972282.jpg
cover: https://img.8845.top/img2/1942944226892972282.jpg
sticky: false
categories:
  - 笔记
tags:
  - AI
  - VSCode
  - Copilot
description: 教你如何使用 OAI Compatible Provider 插件，让 VSCode Copilot 接入讯飞星辰等第三方 OpenAI 兼容接口，免费使用大模型。
---

## 前言

近日在关注 **GitHubDaily** 的公众号推送时，偶然看到一个标题吸引住了我 —— **「无限量 Token 免费白嫖，科大讯飞大手笔啊！」**

如今 Claude Code、Codex 已成为开发者日常使用最多的 AI 生产力工具，但不少人都是时刻盯着 API 账单来使用，看着 Token 的大量消耗，心里都是一颤一颤的。所以有免费的当然值得试试，看看好不好用。

> 💡 该活动来自 [讯飞星辰 MaaS 平台](https://maas.xfyun.cn/modelSquare) 的模型集市，限时一个月免费，主打一个白嫖。

![Qwen 模型列表](https://raw.githubusercontent.com/drda-x/images/main/20260618111434954.png)
![Qwen 模型详情](https://raw.githubusercontent.com/drda-x/images/main/20260618111631737.png)

但是，**如何使用这些 OpenAI 兼容接口呢？**

我使用的 VSCode Copilot 一直不支持通过 OpenAI 兼容接口来接入任意模型，默认的模型选择有限：

![Copilot 默认模型](https://raw.githubusercontent.com/drda-x/images/main/1.png)

经过一番搜索，发现有一个插件实现了让 VSCode Copilot 支持其他 OpenAI 兼容接口的功能，本文将详细记录使用方法。

## 一、安装插件

1. 打开 VSCode，点击左侧扩展市场（快捷键 `Ctrl+Shift+X`）
2. 搜索 **`OAI Compatible Provider for Copilot`**
3. 点击 **Install** 安装该插件

![插件搜索与安装](https://raw.githubusercontent.com/drda-x/images/main/20260618113246819.png)

## 二、获取并配置 API Key

本文以**科大讯飞模型**为例进行演示：

### 2.1 创建应用

1. 访问 [讯飞开放平台](https://console.xfyun.cn/app/myapp)
2. 登录账号，点击 **创建新应用**

### 2.2 配置模型服务

1. 访问 [讯飞星辰 MaaS 平台](https://maas.xfyun.cn/modelSquare)
2. 在模型集市中选择限时免费的模型
3. 点击 **API 调用**
4. 配置以下信息：
   - **模型服务 API 名称**：自定义填写（随便写）
   - **授权应用**：选择刚刚创建的新应用
5. 点击 **确定**，创建服务成功

### 2.3 获取 API Key

创建成功后，在 MaaS 平台的 **推理服务** 中可以看到调用信息以及 **API Key**：

![API Key 获取](https://raw.githubusercontent.com/drda-x/images/main/20260618133255488.png)

> 📌 **提示**：请妥善保管你的 API Key，不要泄露给他人。

## 三、配置插件

### 3.1 配置 Base URL

1. 打开 VSCode 设置（快捷键 `Ctrl+,` 或点击左下角齿轮图标）
2. 搜索 **`OAI`**
3. 选择 **用户（User）** 设置，拉到最下方的 **扩展** 部分
4. 找到 **OAI Compatible Provider for Copilot** 插件设置
5. 配置 **Base URL**

> ✅ Base URL 只要是 OpenAI 兼容的接口都可以使用，例如讯飞星辰的接口地址。

![Base URL 配置](https://raw.githubusercontent.com/drda-x/images/main/20260618113955666.png)

### 3.2 添加模型

1. 打开 Copilot 对话框
2. 点击下方的 **Auto** 按钮，打开 Copilot 设置
3. 在 **语言模型列表** 中添加你的模型信息
4. 模型类型选择 **OAI Compatible**
![添加模型](https://raw.githubusercontent.com/drda-x/images/main/20260618133930051.png)
![模型配置完成](https://raw.githubusercontent.com/drda-x/images/main/20260618134007284.png)

## 四、测试使用

配置完成后，在对话框点击 **Auto**，选择你刚刚添加的模型，然后开始使用：

![测试结果](https://raw.githubusercontent.com/drda-x/images/main/20260618135446750.png)

> ✨ 如果正常收到回复，说明配置成功！

## 五、总结

通过 **OAI Compatible Provider for Copilot** 插件，我们可以突破 Copilot 默认模型的限制，灵活接入各种 OpenAI 兼容的第三方 API。这不仅能够节省 API 费用，还能体验到不同厂商的大模型能力。

**优点：**
- 🆓 可以利用各平台的免费额度
- 🔧 灵活切换不同模型
- 🌐 支持所有 OpenAI 兼容接口

**注意事项：**
- 确保 Base URL 正确且可访问
- API Key 要妥善保管
- 注意各平台的调用频率限制

---

*参考资料：*
- [讯飞星辰 MaaS 平台](https://maas.xfyun.cn/modelSquare)
- [讯飞开放平台](https://console.xfyun.cn/app/myapp)