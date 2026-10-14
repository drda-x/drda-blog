---
title: 自定义H5弹窗组件 (CustomModal)
date: 2026-10-14 15:09:31
tags: [Vue, js, 随笔]
categories: [笔记]
top_img: "https://img.8845.top/img2/%E7%9C%9F%E5%AF%BB%E9%85%B1.png"
cover: "https://img.8845.top/img2/%E7%9C%9F%E5%AF%BB%E9%85%B1.png"
---

我自己自定义了一套H5页面统一风格的弹窗组件，支持**提示弹窗**、**确认弹窗**、**自定义内容弹窗**，可插入表单、图片等任意元素，并支持自定义标题、图标和背景图。
![](https://raw.githubusercontent.com/drda-x/images/main/20261014150121391.png)

---

## 目录

- [文件结构](#文件结构)
- [快速开始](#快速开始)
- [方式一：声明式组件](#方式一声明式组件)
- [方式二：编程式调用](#方式二编程式调用)
- [完整 Props 属性表](#完整-props-属性表)
- [Events 事件](#events-事件)
- [Slots 插槽](#slots-插槽)
- [使用示例](#使用示例)
  - [基础提示弹窗](#1-基础提示弹窗)
  - [确认弹窗](#2-确认弹窗)
  - [成功/错误/警告弹窗](#3-成功错误警告弹窗)
  - [带表单的自定义弹窗](#4-带表单的自定义弹窗)
  - [自定义底部按钮](#5-自定义底部按钮)
  - [带背景图的弹窗](#6-带背景图的弹窗)
  - [Promise 异步用法](#7-promise-异步用法)

---

## 文件结构

```
compones/
├── CustomModal.vue    ← 核心弹窗组件（声明式使用）
└── GlobalModal.vue    ← 全局弹窗容器（编程式使用）

utils/
├── modal.js           ← $modal 服务（alert/confirm/show）
└── modal-mixin.js     ← 快捷混入（showSuccess/showError/showWarning）

pages/
└── modaltest/
    └── modaltest.vue  ← 测试用例页面
```

---

## 快速开始

### 1. 已完成全局注册

在 `main.js` 中已自动注册 `$modal` 服务，**所有页面**均可直接使用 `this.$modal`：

```js
// main.js（已完成配置）
import $modal from '@/utils/modal.js'
Vue.prototype.$modal = $modal
```

### 2. 页面中使用

只需两步：

```vue
<template>
  <view>
    <!-- 页面内容 -->
    <button @click="handleClick">打开弹窗</button>

    <!-- 第一步：在 template 末尾添加 GlobalModal -->
    <GlobalModal />
  </view>
</template>

<script>
// 第二步：引入组件和 mixin
import GlobalModal from '@/compones/GlobalModal.vue'
import modalMixin from '@/utils/modal-mixin.js'

export default {
  components: { GlobalModal },
  mixins: [modalMixin],
  methods: {
    handleClick() {
      // 第三步：直接调用
      this.$modal.alert({ title: '提示', content: '操作成功' })
    }
  }
}
</script>
```

---

## 方式一：声明式组件

适合需要插入**自定义内容**（表单、列表等）的场景。

```vue
<template>
  <CustomModal
    :show="showModal"
    mode="confirm"
    title="编辑信息"
    iconType="person"
    iconColor="#3b82f6"
    :headerGradient="['#3b82f6', '#60a5fa']"
    confirmText="保存"
    cancelText="取消"
    @confirm="onSubmit"
    @cancel="showModal = false"
  >
    <!-- 默认插槽：可插入任意内容 -->
    <u-form :model="form">
      <u-form-item label="姓名" borderBottom>
        <u-input v-model="form.name" />
      </u-form-item>
      <u-form-item label="手机号" borderBottom>
        <u-input v-model="form.phone" />
      </u-form-item>
    </u-form>
  </CustomModal>
</template>

<script>
import CustomModal from '@/compones/CustomModal.vue'

export default {
  components: { CustomModal },
  data() {
    return {
      showModal: false,
      form: { name: '', phone: '' }
    }
  },
  methods: {
    onSubmit() {
      console.log('提交', this.form)
      this.showModal = false
    }
  }
}
</script>
```

---

## 方式二：编程式调用

适合简单的提示、确认场景，无需在 template 中写组件。

### 前置准备

```vue
<template>
  <view>
    <!-- 页面内容 -->
    <!-- 在 template 末尾添加 -->
    <GlobalModal />
  </view>
</template>

<script>
import GlobalModal from '@/compones/GlobalModal.vue'
import modalMixin from '@/utils/modal-mixin.js'

export default {
  components: { GlobalModal },
  mixins: [modalMixin]
}
</script>
```

### 调用方法

```js
// 提示弹窗
this.$modal.alert({ title: '提示', content: '操作成功' })

// 确认弹窗
this.$modal.confirm({
  title: '确认删除',
  content: '删除后无法恢复，是否继续？',
  onConfirm: () => { /* 用户点了确定 */ },
  onCancel: () => { /* 用户点了取消 */ }
})

// 快捷方法（需引入 modalMixin）
this.showSuccess('保存成功！')
this.showError('网络错误，请重试')
this.showWarning('余额不足')
this.showAlert('这是一条提示')
this.showConfirm('是否继续？')
```

---

## 完整 Props 属性表

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `show` | Boolean | `false` | 控制弹窗显示/隐藏 |
| `mode` | String | `'alert'` | 弹窗模式：`alert` / `confirm` / `custom` |
| `title` | String | `''` | 标题文字 |
| `subtitle` | String | `''` | 副标题描述文字 |
| `content` | String | `''` | 文本内容（不使用插槽时生效） |
| `icon` | String | `''` | 图片图标路径（优先级高于 iconType） |
| `iconType` | String | `''` | uni-icons 图标类型名 |
| `iconSize` | Number/String | `60` | 图标大小（rpx） |
| `iconColor` | String | `'#3b82f6'` | 图标颜色 |
| `bgImage` | String | `''` | 顶部背景图片路径 |
| `headerGradient` | Array | `['#3b82f6','#60a5fa']` | 顶部渐变色 `[起始色, 结束色]` |
| `showHeader` | Boolean | `true` | 是否显示顶部区域 |
| `confirmText` | String | `'确定'` | 确认按钮文字 |
| `cancelText` | String | `'取消'` | 取消按钮文字 |
| `showConfirmButton` | Boolean | `true` | 是否显示确认按钮 |
| `showCancelButton` | Boolean | `false` | 是否显示取消按钮 |
| `confirmColor` | String | `''` | 确认按钮自定义颜色 |
| `cancelColor` | String | `''` | 取消按钮自定义颜色 |
| `maskCloseAble` | Boolean | `true` | 点击遮罩是否关闭 |
| `showClose` | Boolean | `false` | 是否显示右上角关闭按钮 |
| `closeSize` | Number/String | `20` | 关闭按钮图标大小 |
| `confirmLoading` | Boolean | `false` | 确认按钮 loading 状态 |
| `cancelLoading` | Boolean | `false` | 取消按钮 loading 状态 |
| `titleStyle` | Object | `{}` | 标题自定义样式 |

### mode 模式说明

| 模式 | 说明 | 默认按钮 |
|------|------|----------|
| `alert` | 提示弹窗 | 仅显示「确定」按钮 |
| `confirm` | 确认弹窗 | 显示「确定」+「取消」按钮 |
| `custom` | 自定义模式 | 由使用者自行控制 |

---

## Events 事件

| 事件名 | 说明 | 回调参数 |
|--------|------|----------|
| `confirm` | 点击确认按钮时触发 | - |
| `cancel` | 点击取消按钮或遮罩时触发 | - |
| `update:show` | show 值变化时触发（支持 .sync） | Boolean |

---

## Slots 插槽

| 插槽名 | 说明 |
|--------|------|
| `default` | 内容区域默认插槽，可插入任意元素（表单、图片、列表等） |
| `footer` | 底部按钮区域插槽，完全自定义底部按钮 |

### footer 插槽示例

```vue
<CustomModal :show="show" title="自定义按钮">
  <text>内容</text>

  <template #footer>
    <view style="display: flex; gap: 20rpx;">
      <button @click="show = false">返回</button>
      <button @click="handleSave">保存</button>
      <button @click="handleDelete">删除</button>
    </view>
  </template>
</CustomModal>
```

---

## 使用示例

### 1. 基础提示弹窗

```js
this.$modal.alert({
  title: '提示',
  content: '操作成功'
})
```
![](https://raw.githubusercontent.com/drda-x/images/main/20261014151709813.png)

### 2. 确认弹窗

```js
const confirmed = await this.$modal.confirm({
  title: '确认删除',
  content: '删除后无法恢复，是否继续？'
})
if (confirmed) {
  // 执行删除
}
```
![](https://raw.githubusercontent.com/drda-x/images/main/20261014151859874.png)

### 3. 成功/错误/警告弹窗

```js
// 成功提示（绿色主题 + 勾选图标）
this.showSuccess('数据保存成功！')

// 错误提示（红色主题 + X 图标）
this.showError('网络请求失败，请重试')

// 警告提示（橙色主题 + 感叹号图标）
this.showWarning('账户余额不足，请先充值')
```
>错误提示作为例子展示

![](https://raw.githubusercontent.com/drda-x/images/main/20261014151957082.png)

### 4. 带表单的自定义弹窗

```vue
<CustomModal
  :show="showForm"
  mode="custom"
  title="新增设备"
  iconType="plus-filled"
  iconColor="#8b5cf6"
  :headerGradient="['#8b5cf6', '#a78bfa']"
  :showHeader="true"
  :showConfirmButton="true"
  :showCancelButton="true"
  confirmText="提交"
  cancelText="关闭"
  :showClose="true"
  :maskCloseAble="false"
  @confirm="submitForm"
  @cancel="showForm = false"
>
  <u-form :model="form" ref="uForm" :rules="rules">
    <u-form-item label="设备名称" prop="name" borderBottom>
      <u-input v-model="form.name" placeholder="请输入设备名称" />
    </u-form-item>
    <u-form-item label="设备编号" prop="code" borderBottom>
      <u-input v-model="form.code" placeholder="请输入设备编号" />
    </u-form-item>
    <u-form-item label="所在区域" prop="area" borderBottom>
      <u-input v-model="form.area" placeholder="请选择区域" disabled @click="pickArea" />
    </u-form-item>
  </u-form>
</CustomModal>
```
![](https://raw.githubusercontent.com/drda-x/images/main/20261014152132227.png)

### 5. 自定义底部按钮

```vue
<CustomModal :show="showFooterModal" title="订单操作"
			iconType="list" iconColor="#14b8a6" :headerGradient="['#14b8a6', '#2dd4bf']">
			<view class="order-info">
				<view class="order-row">
					<text class="order-label">订单编号</text>
					<text class="order-value">ORD20261013001</text>
				</view>
				<view class="order-row">
					<text class="order-label">消费金额</text>
					<text class="order-value price">¥15.00</text>
				</view>
				<view class="order-row">
					<text class="order-label">订单状态</text>
					<text class="order-value status">待支付</text>
				</view>
			</view>
			<template #footer>
				<view class="multi-btn-group">
					<view class="multi-btn btn-cancel" @click="showFooterModal = false">
						<text>取消订单</text>
					</view>
					<view class="multi-btn btn-detail" @click="handleDetail">
						<text>查看详情</text>
					</view>
					<view class="multi-btn btn-pay" @click="handlePay">
						<text>立即支付</text>
					</view>
				</view>
			</template>
		</CustomModal>
```
![](https://raw.githubusercontent.com/drda-x/images/main/20261014152915988.png)

### 6. 带背景图的弹窗

```vue
<CustomModal
  :show="show"
  title="活动详情"
  bgImage="/static/image/banner.png"
  iconType="gift-filled"
  iconColor="#ffffff"
  content="参与活动即可获得丰厚奖励！"
  confirmText="立即参与"
  @confirm="joinActivity"
  @cancel="show = false"
/>
```
![](https://raw.githubusercontent.com/drda-x/images/main/20261014153935595.png)

### 7. Promise 异步用法

```js
async handleDelete(item) {
  const confirmed = await this.$modal.confirm({
    title: '确认删除',
    content: `确定要删除「${item.name}」吗？`,
    confirmColor: '#ef4444',
    iconType: 'trash',
    iconColor: '#ef4444',
    headerGradient: ['#ef4444', '#f87171']
  })

  if (confirmed) {
    await this.deleteItem(item.id)
    this.showSuccess('删除成功')
  }
}
```
![](https://raw.githubusercontent.com/drda-x/images/main/20261014154112003.png)

---

## 测试页面

项目已内置测试页面，包含所有弹窗类型的演示：

**路径**：`pages/modaltest/modaltest.vue`

**访问方式**：在浏览器中直接访问 `#/pages/modaltest/modaltest`

测试页面包含以下场景：

| 测试项 | 说明 |
|--------|------|
| 基础提示弹窗 | 最简单的 alert 用法 |
| 确认弹窗 | 带确认/取消的 confirm 用法 |
| 成功提示 | 绿色主题成功弹窗 |
| 错误提示 | 红色主题错误弹窗 |
| 警告提示 | 橙色主题警告弹窗 |
| 自定义表单弹窗 | 插入 u-form 表单的完整示例 |
| 带背景图弹窗 | 使用 bgImage 自定义背景 |
| 多按钮弹窗 | 使用 footer 插槽自定义底部 |
| 编程式 Promise | async/await 异步调用示例 |

---

## 样式定制

组件使用 `scoped` 样式，如需全局覆盖，可在 `App.vue` 中使用 `::v-deep`：

```scss
::v-deep .custom-modal-wrapper {
  width: 650rpx; // 修改弹窗宽度
  border-radius: 32rpx; // 修改圆角
}

::v-deep .confirm-btn {
  // 修改确认按钮默认样式
  background: linear-gradient(135deg, #10b981, #059669);
}
```

---

## 常见问题

**Q: 为什么弹窗不显示？**
A: 确保已在页面 template 中添加 `<GlobalModal />`（编程式），或正确绑定 `:show`（声明式）。

**Q: 如何在弹窗关闭后执行操作？**
A: 监听 `@cancel` 事件，或使用 `$modal.confirm()` 的 Promise 返回值。

**Q: 如何阻止点击遮罩关闭？**
A: 设置 `:mask-close-able="false"`。

**Q: 编程式弹窗可以插入自定义内容吗？**
A: 编程式弹窗仅支持文本内容。如需插入表单等自定义内容，请使用声明式 `<CustomModal>` 组件。

---

## 最后附上源码
**compones/CustomModal.vue**
```vue
<template>
	<view v-if="visible" class="custom-modal-mask" :class="{ 'mask-show': show }" @click="handleMaskClick">
		<view class="custom-modal-wrapper" :class="{ 'modal-show': show }" @click.stop>
			<!-- 顶部背景图区域 -->
			<view class="modal-header" v-if="showHeader">
				<image v-if="bgImage" :src="bgImage" class="header-bg-image" mode="aspectFill" />
				<view class="header-bg-gradient" :style="headerGradientStyle"></view>
				<!-- 图标背景 + 标题浮于图标之上 -->
				<view class="header-main">
					<view class="header-icon-wrapper" v-if="icon || iconType">
						<image v-if="icon" :src="icon" class="header-icon-image" mode="aspectFit" />
						<uni-icons v-else :type="iconType" :size="iconSize" :color="iconColor"></uni-icons>
					</view>
					<view class="header-title-wrapper" v-if="title">
						<text class="header-title" :style="titleStyle">{{ title }}</text>
					</view>
				</view>
				<!-- 副标题 -->
				<view class="header-subtitle-wrapper" v-if="subtitle">
					<text class="header-subtitle">{{ subtitle }}</text>
				</view>
			</view>

			<!-- 内容区域 -->
			<view class="modal-body">
				<!-- 文本内容 -->
				<view class="modal-content-wrapper" v-if="content && !$slots.default">
					<text class="modal-content">{{ content }}</text>
				</view>

				<!-- 自定义插槽内容（支持表单等任意元素） -->
				<view class="modal-slot-wrapper" v-if="$slots.default">
					<slot></slot>
				</view>
			</view>

			<!-- 底部按钮区域 -->
			<view class="modal-footer">
				<!-- 自定义底部插槽 -->
				<slot name="footer">
					<view class="footer-buttons">
						<button v-if="showCancelButton" class="modal-btn cancel-btn" :style="cancelBtnStyle"
							@click="handleCancel" :loading="cancelLoading">
							{{ cancelText }}
						</button>
						<button v-if="showConfirmButton" class="modal-btn confirm-btn" :style="confirmBtnStyle"
							@click="handleConfirm" :loading="confirmLoading">
							{{ confirmText }}
						</button>
					</view>
				</slot>
			</view>

			<!-- 关闭按钮 -->
			<view v-if="showClose" class="modal-close-btn" @click="handleCancel">
				<uni-icons type="closeempty" :size="closeSize" color="#999999"></uni-icons>
			</view>
		</view>
	</view>
</template>

<script>
	export default {
		name: 'CustomModal',
		props: {
			// 控制弹窗显示
			show: {
				type: Boolean,
				default: false
			},
			// 弹窗模式：alert(提示) / confirm(确认) / custom(自定义)
			mode: {
				type: String,
				default: 'alert',
				validator: (val) => ['alert', 'confirm', 'custom'].includes(val)
			},
			// 标题
			title: {
				type: String,
				default: ''
			},
			// 副标题
			subtitle: {
				type: String,
				default: ''
			},
			// 文本内容（不使用插槽时生效）
			content: {
				type: String,
				default: ''
			},
			// 图片图标路径
			icon: {
				type: String,
				default: ''
			},
			// uni-icons 图标类型
			iconType: {
				type: String,
				default: ''
			},
			// 图标大小
			iconSize: {
				type: [Number, String],
				default: 60
			},
			// 图标颜色
			iconColor: {
				type: String,
				default: '#3b82f6'
			},
			// 顶部背景图
			bgImage: {
				type: String,
				default: ''
			},
			// 顶部渐变色 [起始色, 结束色]
			headerGradient: {
				type: Array,
				default: () => ['#3b82f6', '#60a5fa']
			},
			// 是否显示顶部区域
			showHeader: {
				type: Boolean,
				default: true
			},
			// 确认按钮文字
			confirmText: {
				type: String,
				default: '确定'
			},
			// 取消按钮文字
			cancelText: {
				type: String,
				default: '取消'
			},
			// 是否显示确认按钮
			showConfirmButton: {
				type: Boolean,
				default: true
			},
			// 是否显示取消按钮
			showCancelButton: {
				type: Boolean,
				default: false
			},
			// 确认按钮颜色
			confirmColor: {
				type: String,
				default: ''
			},
			// 取消按钮颜色
			cancelColor: {
				type: String,
				default: ''
			},
			// 点击遮罩是否关闭
			maskCloseAble: {
				type: Boolean,
				default: true
			},
			// 是否显示右上角关闭按钮
			showClose: {
				type: Boolean,
				default: false
			},
			// 关闭按钮大小
			closeSize: {
				type: [Number, String],
				default: 20
			},
			// 确认按钮 loading
			confirmLoading: {
				type: Boolean,
				default: false
			},
			// 取消按钮 loading
			cancelLoading: {
				type: Boolean,
				default: false
			},
			// 标题自定义样式
			titleStyle: {
				type: Object,
				default: () => ({})
			}
		},
		data() {
			return {
				visible: false
			}
		},
		computed: {
			headerGradientStyle() {
				if (this.bgImage) return {}
				const colors = this.headerGradient
				if (!colors || colors.length < 2) return {}
				return {
					background: `linear-gradient(135deg, ${colors[0]}, ${colors[1]})`
				}
			},
			confirmBtnStyle() {
				if (!this.confirmColor) return {}
				return {
					background: this.confirmColor,
					borderColor: this.confirmColor
				}
			},
			cancelBtnStyle() {
				if (!this.cancelColor) return {}
				return {
					color: this.cancelColor,
					borderColor: this.cancelColor
				}
			}
		},
		watch: {
			show: {
				handler(val) {
					if (val) {
						this.visible = true
					} else {
						// 延迟隐藏以播放关闭动画
						setTimeout(() => {
							this.visible = false
						}, 300)
					}
				},
				immediate: true
			},
			// 根据 mode 自动设置按钮
			mode: {
				handler(val) {
					if (val === 'alert') {
						this.$emit('update:showCancelButton', false)
					} else if (val === 'confirm') {
						this.$emit('update:showCancelButton', true)
					}
				},
				immediate: true
			}
		},
		methods: {
			handleConfirm() {
				this.$emit('confirm')
				this.$emit('update:show', false)
			},
			handleCancel() {
				this.$emit('cancel')
				this.$emit('update:show', false)
			},
			handleMaskClick() {
				if (this.maskCloseAble) {
					this.handleCancel()
				}
			}
		}
	}
</script>

<style lang="scss" scoped>
	/* 遮罩层 */
	.custom-modal-mask {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 9999;
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 0;
		transition: opacity 0.3s ease;

		&.mask-show {
			opacity: 1;
		}
	}

	/* 弹窗主体 */
	.custom-modal-wrapper {
		position: relative;
		width: 600rpx;
		background: #ffffff;
		border-radius: 24rpx;
		overflow: hidden;
		transform: scale(0.85) translateY(40rpx);
		opacity: 0;
		transition: all 0.35s cubic-bezier(0.4, 0, 0.2, 1);
		box-shadow: 0 20rpx 60rpx rgba(0, 0, 0, 0.15);

		&.modal-show {
			transform: scale(1) translateY(0);
			opacity: 1;
		}
	}

	/* 顶部背景区域 */
	.modal-header {
		position: relative;
		width: 100%;
		// padding: 20rpx 40rpx 18rpx;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		overflow: hidden;

		.header-bg-image {
			position: absolute;
			top: 0;
			left: 0;
			width: 100%;
			height: 100%;
		}

		.header-bg-gradient {
			position: absolute;
			top: 0;
			left: 0;
			width: 100%;
			height: 100%;
		}

		.header-main {
			position: relative;
			z-index: 2;
			display: flex;
			flex-direction: row;
			align-items: center;
			justify-content: center;
			min-height: 110rpx;
			padding: 10rpx 30rpx;
		}

		.header-icon-wrapper {
			position: absolute;
			left: 50%;
			top: 50%;
			transform: translate(-50%, -50%);
			width: 130rpx;
			height: 130rpx;
			display: flex;
			align-items: center;
			justify-content: center;
			background: rgba(255, 255, 255, 0.18);
			border-radius: 50%;
			border: 3rpx solid rgba(255, 255, 255, 0.3);
			z-index: 1;

			.header-icon-image {
				width: 70rpx;
				height: 70rpx;
				opacity: 0.9;
			}
		}

		.header-title-wrapper {
			position: relative;
			z-index: 2;
			text-align: center;
		}

		.header-title {
			font-size: 38rpx;
			font-weight: 700;
			color: #ffffff;
			line-height: 1.4;
			text-shadow: 0 2rpx 12rpx rgba(0, 0, 0, 0.35);
		}

		.header-subtitle-wrapper {
			position: relative;
			z-index: 2;
			text-align: center;
			margin-top: 6rpx;
		}

		.header-subtitle {
			font-size: 26rpx;
			color: rgba(255, 255, 255, 0.85);
			line-height: 1.5;
			text-shadow: 0 1rpx 4rpx rgba(0, 0, 0, 0.1);
		}
	}

	/* 内容区域 */
	.modal-body {
		padding: 32rpx 40rpx 20rpx;
	}

	.modal-content-wrapper {
		padding: 10rpx 0;
	}

	.modal-content {
		font-size: 28rpx;
		color: #64748b;
		line-height: 1.7;
		text-align: center;
	}

	.modal-slot-wrapper {
		padding: 10rpx 0;
	}

	/* 底部按钮 */
	.modal-footer {
		padding: 20rpx 40rpx 40rpx;
	}

	.footer-buttons {
		display: flex;
		gap: 24rpx;
	}

	.modal-btn {
		flex: 1;
		height: 84rpx;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 42rpx;
		font-size: 30rpx;
		font-weight: 600;
		border: none;
		transition: all 0.25s ease;
		position: relative;
		overflow: hidden;

		&::after {
			border: none;
		}

		&:active {
			transform: scale(0.96);
		}
	}

	.confirm-btn {
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		color: #ffffff;
		box-shadow: 0 8rpx 24rpx rgba(59, 130, 246, 0.35);

		&:active {
			box-shadow: 0 4rpx 12rpx rgba(59, 130, 246, 0.2);
		}
	}

	.cancel-btn {
		background: #ffffff;
		color: #64748b;
		border: 2rpx solid #e2e8f0;

		&:active {
			background: #f8fafc;
		}
	}

	/* 关闭按钮 */
	.modal-close-btn {
		position: absolute;
		top: 20rpx;
		right: 20rpx;
		width: 56rpx;
		height: 56rpx;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(255, 255, 255, 0.8);
		border-radius: 50%;
		z-index: 10;
		transition: all 0.2s ease;

		&:active {
			transform: scale(0.9);
			background: rgba(255, 255, 255, 0.6);
		}
	}
</style>
```
**compones/GlobaModal.vue**
```vue
<template>
	<CustomModal
		:show="show"
		:mode="config.mode"
		:title="config.title"
		:subtitle="config.subtitle"
		:content="config.content"
		:icon="config.icon"
		:iconType="config.iconType"
		:iconSize="config.iconSize"
		:iconColor="config.iconColor"
		:bgImage="config.bgImage"
		:headerGradient="config.headerGradient"
		:showHeader="config.showHeader"
		:confirmText="config.confirmText"
		:cancelText="config.cancelText"
		:showConfirmButton="config.showConfirmButton"
		:showCancelButton="config.showCancelButton"
		:confirmColor="config.confirmColor"
		:cancelColor="config.cancelColor"
		:maskCloseAble="config.maskCloseAble"
		:showClose="config.showClose"
		:confirmLoading="config.confirmLoading"
		:titleStyle="config.titleStyle"
		@confirm="handleConfirm"
		@cancel="handleCancel"
	/>
</template>

<script>
	import CustomModal from '@/compones/CustomModal.vue'
	import modalService from '@/utils/modal.js'
	
	export default {
		name: 'GlobalModal',
		components: { CustomModal },
		data() {
			return {
				show: false,
				defaultConfig: {
					mode: 'alert',
					title: '提示',
					subtitle: '',
					content: '',
					icon: '',
					iconType: '',
					iconSize: 60,
					iconColor: '#3b82f6',
					bgImage: '',
					headerGradient: ['#3b82f6', '#60a5fa'],
					showHeader: true,
					confirmText: '确定',
					cancelText: '取消',
					showConfirmButton: true,
					showCancelButton: false,
					confirmColor: '',
					cancelColor: '',
					maskCloseAble: true,
					showClose: false,
					confirmLoading: false,
					titleStyle: {}
				},
				config: {}
			}
		},
		created() {
			this.config = { ...this.defaultConfig }
			uni.$on('__custom_modal_show__', (config) => {
				this.config = { ...this.defaultConfig, ...config }
				this.show = true
			})
			uni.$on('__custom_modal_hide__', () => {
				this.show = false
			})
		},
		beforeDestroy() {
			uni.$off('__custom_modal_show__')
			uni.$off('__custom_modal_hide__')
		},
		methods: {
			handleConfirm() {
				const { onConfirm } = modalService.getCallbacks()
				onConfirm && onConfirm()
				modalService.clearCallbacks()
				this.show = false
			},
			handleCancel() {
				const { onCancel } = modalService.getCallbacks()
				onCancel && onCancel()
				modalService.clearCallbacks()
				this.show = false
			}
		}
	}
</script>
```

**utils/modal.js**
```js
/**
 * 自定义弹窗服务
 * 
 * 使用方式：
 * 1. 在 App.vue 中引入并注册组件
 * 2. 在任意页面调用 this.$modal.alert / this.$modal.confirm / this.$modal.show
 * 
 * 示例：
 * this.$modal.alert({
 *   title: '提示',
 *   content: '操作成功',
 *   iconType: 'checkbox-filled',
 *   iconColor: '#10b981'
 * })
 * 
 * this.$modal.confirm({
 *   title: '确认',
 *   content: '是否确定取消该订单？',
 *   onConfirm: () => { ... }
 * })
 */

// 存储回调函数
let _onConfirm = null
let _onCancel = null

/**
 * 提示弹窗
 * @param {Object} options 配置项
 */
function alert(options = {}) {
	return new Promise((resolve) => {
		const config = {
			mode: 'alert',
			showCancelButton: false,
			maskCloseAble: options.maskCloseAble !== undefined ? options.maskCloseAble : true,
			...options
		}
		_onConfirm = () => {
			options.onConfirm && options.onConfirm()
			resolve(true)
		}
		_onCancel = () => {
			options.onCancel && options.onCancel()
			resolve(false)
		}
		uni.$emit('__custom_modal_show__', config)
	})
}

/**
 * 确认弹窗
 * @param {Object} options 配置项
 */
function confirm(options = {}) {
	return new Promise((resolve) => {
		const config = {
			mode: 'confirm',
			showCancelButton: true,
			maskCloseAble: options.maskCloseAble !== undefined ? options.maskCloseAble : false,
			...options
		}
		_onConfirm = () => {
			options.onConfirm && options.onConfirm()
			resolve(true)
		}
		_onCancel = () => {
			options.onCancel && options.onCancel()
			resolve(false)
		}
		uni.$emit('__custom_modal_show__', config)
	})
}

/**
 * 自定义弹窗
 * @param {Object} options 配置项
 */
function show(options = {}) {
	return new Promise((resolve) => {
		const config = {
			mode: 'custom',
			...options
		}
		_onConfirm = () => {
			options.onConfirm && options.onConfirm()
			resolve(true)
		}
		_onCancel = () => {
			options.onCancel && options.onCancel()
			resolve(false)
		}
		uni.$emit('__custom_modal_show__', config)
	})
}

/**
 * 关闭弹窗
 */
function close() {
	uni.$emit('__custom_modal_hide__')
}

/**
 * 获取回调函数（供组件内部使用）
 */
function getCallbacks() {
	return { onConfirm: _onConfirm, onCancel: _onCancel }
}

/**
 * 清除回调
 */
function clearCallbacks() {
	_onConfirm = null
	_onCancel = null
}

export default {
	alert,
	confirm,
	show,
	close,
	getCallbacks,
	clearCallbacks
}
```
utils/modal-mixin.js
```js
/**
 * 弹窗混入
 * 在页面的 components 中引入 GlobalModal 后，使用此 mixin 即可自动获得 $modal 功能
 * 
 * 使用方式：
 * 1. 在页面 script 中：import modalMixin from '@/utils/modal-mixin.js'
 * 2. 在页面 components 中：import GlobalModal from '@/compones/GlobalModal.vue'
 * 3. 在 mixins 中：mixins: [modalMixin]
 * 4. 在 template 末尾添加：<GlobalModal />
 * 
 * 然后即可使用：
 * this.$modal.alert({ title: '提示', content: '操作成功' })
 * this.$modal.confirm({ title: '确认', content: '是否删除？' })
 */

export default {
	components: {},
	methods: {
		/**
		 * 快捷提示弹窗
		 * @param {String} content 提示内容
		 * @param {String} title 标题（可选）
		 */
		showAlert(content, title = '提示') {
			return this.$modal.alert({ title, content })
		},
		/**
		 * 快捷确认弹窗
		 * @param {String} content 确认内容
		 * @param {String} title 标题（可选）
		 */
		showConfirm(content, title = '确认') {
			return this.$modal.confirm({ title, content })
		},
		/**
		 * 成功提示
		 * @param {String} content 内容
		 */
		showSuccess(content) {
			return this.$modal.alert({
				title: '成功',
				content,
				iconType: 'checkbox-filled',
				iconColor: '#10b981',
				headerGradient: ['#10b981', '#34d399'],
				confirmColor: '#10b981'
			})
		},
		/**
		 * 错误提示
		 * @param {String} content 内容
		 */
		showError(content) {
			return this.$modal.alert({
				title: '错误',
				content,
				iconType: 'closeempty',
				iconColor: '#ef4444',
				headerGradient: ['#ef4444', '#f87171'],
				confirmColor: '#ef4444'
			})
		},
		/**
		 * 警告提示
		 * @param {String} content 内容
		 */
		showWarning(content) {
			return this.$modal.alert({
				title: '警告',
				content,
				iconType: 'info',
				iconColor: '#f59e0b',
				headerGradient: ['#f59e0b', '#fbbf24'],
				confirmColor: '#f59e0b'
			})
		}
	}
}
```

**pages/modaltest/modaltest.vue**
```vue
<template>
	<view class="test-page">
		<!-- 顶部背景 -->
		<view class="header-bg"></view>

		<view class="content">
			<!-- 页面标题 -->
			<view class="page-header">
				<view class="page-icon">
					<uni-icons type="chat" size="28" color="#ffffff"></uni-icons>
				</view>
				<text class="page-title">自定义弹窗组件测试</text>
				<text class="page-desc">CustomModal 完整功能演示</text>
			</view>

			<!-- 编程式调用 -->
			<view class="section">
				<view class="section-title">
					<uni-icons type="code" size="18" color="#3b82f6"></uni-icons>
					<text>编程式调用（this.$modal）</text>
				</view>
				<view class="btn-grid">
					<view class="test-btn alert-btn" @click="testAlert">
						<uni-icons type="info" size="20" color="#3b82f6"></uni-icons>
						<text>基础提示</text>
					</view>
					<view class="test-btn confirm-btn" @click="testConfirm">
						<uni-icons type="help" size="20" color="#8b5cf6"></uni-icons>
						<text>确认弹窗</text>
					</view>
					<view class="test-btn success-btn" @click="testSuccess">
						<uni-icons type="checkbox-filled" size="20" color="#10b981"></uni-icons>
						<text>成功提示</text>
					</view>
					<view class="test-btn error-btn" @click="testError">
						<uni-icons type="closeempty" size="20" color="#ef4444"></uni-icons>
						<text>错误提示</text>
					</view>
					<view class="test-btn warning-btn" @click="testWarning">
						<uni-icons type="info" size="20" color="#f59e0b"></uni-icons>
						<text>警告提示</text>
					</view>
					<view class="test-btn promise-btn" @click="testPromise">
						<uni-icons type="loop" size="20" color="#06b6d4"></uni-icons>
						<text>Promise</text>
					</view>
				</view>
			</view>

			<!-- 声明式调用 -->
			<view class="section">
				<view class="section-title">
					<uni-icons type="compose" size="18" color="#8b5cf6"></uni-icons>
					<text>声明式调用（组件）</text>
				</view>
				<view class="btn-grid">
					<view class="test-btn form-btn" @click="showFormModal = true">
						<uni-icons type="compose" size="20" color="#8b5cf6"></uni-icons>
						<text>表单弹窗</text>
					</view>
					<view class="test-btn bg-btn" @click="showBgModal = true">
						<uni-icons type="image" size="20" color="#f97316"></uni-icons>
						<text>背景图弹窗</text>
					</view>
					<view class="test-btn footer-btn" @click="showFooterModal = true">
						<uni-icons type="more-filled" size="20" color="#14b8a6"></uni-icons>
						<text>多按钮弹窗</text>
					</view>
					<view class="test-btn close-btn" @click="showCloseModal = true">
						<uni-icons type="closeempty" size="20" color="#64748b"></uni-icons>
						<text>关闭按钮</text>
					</view>
					<view class="test-btn custom-btn" @click="showCustomModal = true">
						<uni-icons type="star-filled" size="20" color="#ec4899"></uni-icons>
						<text>自定义图标</text>
					</view>
					<view class="test-btn loading-btn" @click="showLoadingModal = true">
						<uni-icons type="spinner-cycle" size="20" color="#6366f1"></uni-icons>
						<text>Loading</text>
					</view>
				</view>
			</view>

			<!-- 调用结果 -->
			<view class="section" v-if="resultText">
				<view class="section-title">
					<uni-icons type="checkbox" size="18" color="#10b981"></uni-icons>
					<text>调用结果</text>
				</view>
				<view class="result-card">
					<text class="result-text">{{ resultText }}</text>
				</view>
			</view>
		</view>

		<!-- ====== 声明式弹窗区域 ====== -->

		<!-- 1. 表单弹窗 -->
		<CustomModal :show="showFormModal" mode="custom" title="新增设备"
			iconType="plus-filled" iconColor="#8b5cf6" :headerGradient="['#8b5cf6', '#a78bfa']"
			:showClose="true" :maskCloseAble="false" :showCancelButton="true"
			confirmText="提交" cancelText="关闭"
			@confirm="submitForm" @cancel="showFormModal = false">
			<u-form :model="formData" ref="uForm">
				<u-form-item label="设备名称" borderBottom labelWidth="80">
					<u-input v-model="formData.name" placeholder="请输入设备名称" />
				</u-form-item>
				<u-form-item label="设备编号" borderBottom labelWidth="80">
					<u-input v-model="formData.code" placeholder="请输入设备编号" />
				</u-form-item>
				<u-form-item label="所在区域" borderBottom labelWidth="80">
					<u-input v-model="formData.area" placeholder="请选择区域" />
				</u-form-item>
				<u-form-item label="备注" labelWidth="80">
					<u-input v-model="formData.remark" placeholder="选填" />
				</u-form-item>
			</u-form>
		</CustomModal>

		<!-- 2. 背景图弹窗（用渐变模拟） -->
		<CustomModal :show="showBgModal" title="新年活动"
		    bgImage="https://img.8845.top/img2/%E7%9C%9F%E5%AF%BB%E9%85%B1.png"
			:headerGradient="['#f97316', '#fbbf24']"
			iconType="gift-filled" iconColor="#fbbf24" :iconSize="50"
			content="参与新年活动，充值满100送20！限时优惠，不容错过！"
			confirmText="立即参与" cancelText="稍后再说" :showCancelButton="true"
			@confirm="handleBgConfirm" @cancel="showBgModal = false" />

		<!-- 3. 多按钮弹窗 -->
		<CustomModal :show="showFooterModal" title="订单操作"
			iconType="list" iconColor="#14b8a6" :headerGradient="['#14b8a6', '#2dd4bf']">
			<view class="order-info">
				<view class="order-row">
					<text class="order-label">订单编号</text>
					<text class="order-value">ORD20261013001</text>
				</view>
				<view class="order-row">
					<text class="order-label">消费金额</text>
					<text class="order-value price">¥15.00</text>
				</view>
				<view class="order-row">
					<text class="order-label">订单状态</text>
					<text class="order-value status">待支付</text>
				</view>
			</view>
			<template #footer>
				<view class="multi-btn-group">
					<view class="multi-btn btn-cancel" @click="showFooterModal = false">
						<text>取消订单</text>
					</view>
					<view class="multi-btn btn-detail" @click="handleDetail">
						<text>查看详情</text>
					</view>
					<view class="multi-btn btn-pay" @click="handlePay">
						<text>立即支付</text>
					</view>
				</view>
			</template>
		</CustomModal>

		<!-- 4. 带关闭按钮弹窗 -->
		<CustomModal :show="showCloseModal" title="系统公告"
			iconType="sound-filled" iconColor="#3b82f6" :headerGradient="['#3b82f6', '#60a5fa']"
			:showClose="true" :showConfirmButton="false" :showCancelButton="false" @cancel="showCloseModal = false">
			<view class="notice-content">
				<text class="notice-title">关于系统升级的通知</text>
				<text class="notice-body">尊敬的用户，系统将于2026年10月15日凌晨2:00-4:00进行维护升级，届时部分功能将暂时不可用，请提前做好相关安排。</text>
				<text class="notice-date">发布日期：2026-10-13</text>
			</view>
		</CustomModal>

		<!-- 5. 自定义图标弹窗 -->
		<CustomModal :show="showCustomModal" title="VIP 升级"
		
			icon="/static/image/functions/huiyuanchongzhitaocan_icon.png" :iconSize="56"
			:headerGradient="['#ec4899', '#f472b6']"
			content="恭喜您升级为 VIP 会员！享受专属折扣和优先服务。"
			confirmText="查看权益" cancelText="知道了" :showCancelButton="true"
			@confirm="showCustomModal = false" @cancel="showCustomModal = false" />

		<!-- 6. Loading 弹窗 -->
		<CustomModal :show="showLoadingModal" title="提交中"
			iconType="spinner-cycle" iconColor="#6366f1" :headerGradient="['#6366f1', '#818cf8']"
			content="正在提交您的数据，请稍候..."
			:confirmLoading="true" :showCancelButton="false"
			confirmText="提交中..." :maskCloseAble="false" />

		<!-- 全局弹窗（供编程式调用） -->
		<GlobalModal />
	</view>
</template>

<script>
	import CustomModal from '@/compones/CustomModal.vue'
	import GlobalModal from '@/compones/GlobalModal.vue'
	import modalMixin from '@/utils/modal-mixin.js'

	export default {
		components: {
			CustomModal,
			GlobalModal
		},
		mixins: [modalMixin],
		data() {
			return {
				resultText: '',
				// 声明式弹窗控制
				showFormModal: false,
				showBgModal: false,
				showFooterModal: false,
				showCloseModal: false,
				showCustomModal: false,
				showLoadingModal: false,
				// 表单数据
				formData: {
					name: '',
					code: '',
					area: '',
					remark: ''
				}
			}
		},
		methods: {
			// ====== 编程式调用测试 ======
			testAlert() {
				this.resultText = '调用 this.$modal.alert()'
				this.$modal.alert({
					title: '这是标题',
					content: '这是一条基础提示信息',
					iconType: 'info',
					iconColor: '#3b82f6'
				})
			},

			async testConfirm() {
				this.resultText = '调用 this.$modal.confirm()'
				const confirmed = await this.$modal.confirm({
					title: '确认操作',
					content: '确定要执行此操作吗？',
					confirmText: '确定执行',
					cancelText: '取消',
					iconType: 'help-filled',
					iconColor: '#8b5cf6',
					headerGradient: ['#8b5cf6', '#a78bfa']
				})
				this.resultText = confirmed ? '用户点击了【确定】' : '用户点击了【取消】'
			},

			testSuccess() {
				this.resultText = '调用 this.showSuccess()'
				this.showSuccess('数据保存成功！')
			},

			testError() {
				this.resultText = '调用 this.showError()'
				this.showError('网络请求失败，请检查网络连接后重试')
			},

			testWarning() {
				this.resultText = '调用 this.showWarning()'
				this.showWarning('账户余额不足，请先充值')
			},

			async testPromise() {
				this.resultText = '调用 async/await 模式'
				const confirmed = await this.$modal.confirm({
					title: '异步确认',
					content: '此操作将删除选中的 3 条记录，是否继续？',
					confirmColor: '#ef4444',
					iconType: 'trash',
					iconColor: '#ef4444',
					headerGradient: ['#ef4444', '#f87171']
				})
				if (confirmed) {
					await this.showSuccess('删除成功，共删除 3 条记录')
				} else {
					this.resultText = '已取消删除操作'
				}
			},

			// ====== 声明式弹窗测试 ======
			submitForm() {
				this.showFormModal = false
				this.resultText = `表单提交：${JSON.stringify(this.formData)}`
				this.showSuccess('设备添加成功！')
				this.formData = { name: '', code: '', area: '', remark: '' }
			},

			handleBgConfirm() {
				this.showBgModal = false
				this.resultText = '参与活动成功'
				this.showSuccess('恭喜您成功参与活动！')
			},

			handleDetail() {
				this.showFooterModal = false
				this.resultText = '点击了「查看详情」'
			},

			handlePay() {
				this.showFooterModal = false
				this.resultText = '点击了「立即支付」'
				this.showSuccess('支付成功！')
			}
		}
	}
</script>

<style lang="scss" scoped>
	.test-page {
		min-height: 100vh;
		background: #f0f5ff;
		padding-bottom: calc(40rpx + env(safe-area-inset-bottom));
	}

	.header-bg {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		height: 400rpx;
		background: linear-gradient(135deg, #1d4ed8, #3b82f6, #60a5fa);
		border-radius: 0 0 60rpx 60rpx;
		z-index: 0;
	}

	.content {
		position: relative;
		z-index: 1;
		padding: 0 30rpx;
	}

	/* 页面标题 */
	.page-header {
		padding-top: 60rpx;
		padding-bottom: 40rpx;
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	.page-icon {
		width: 96rpx;
		height: 96rpx;
		background: rgba(255, 255, 255, 0.2);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 20rpx;
		border: 2rpx solid rgba(255, 255, 255, 0.3);
	}

	.page-title {
		font-size: 40rpx;
		font-weight: 700;
		color: #ffffff;
		margin-bottom: 10rpx;
	}

	.page-desc {
		font-size: 26rpx;
		color: rgba(255, 255, 255, 0.75);
	}

	/* 区块 */
	.section {
		background: #ffffff;
		border-radius: 24rpx;
		padding: 36rpx;
		margin-bottom: 24rpx;
		box-shadow: 0 4rpx 20rpx rgba(0, 0, 0, 0.05);
	}

	.section-title {
		display: flex;
		align-items: center;
		gap: 12rpx;
		margin-bottom: 28rpx;

		text {
			font-size: 30rpx;
			font-weight: 600;
			color: #1e293b;
		}
	}

	/* 按钮网格 */
	.btn-grid {
		display: flex;
		flex-wrap: wrap;
		gap: 20rpx;
	}

	.test-btn {
		flex: 0 0 calc(50% - 10rpx);
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 12rpx;
		height: 88rpx;
		border-radius: 16rpx;
		font-size: 26rpx;
		font-weight: 600;
		transition: all 0.2s ease;

		&:active {
			transform: scale(0.96);
			opacity: 0.85;
		}

		text {
			color: inherit;
		}
	}

	.alert-btn {
		background: #eff6ff;
		color: #3b82f6;
		border: 2rpx solid #bfdbfe;
	}

	.confirm-btn {
		background: #f5f3ff;
		color: #8b5cf6;
		border: 2rpx solid #ddd6fe;
	}

	.success-btn {
		background: #ecfdf5;
		color: #10b981;
		border: 2rpx solid #a7f3d0;
	}

	.error-btn {
		background: #fef2f2;
		color: #ef4444;
		border: 2rpx solid #fecaca;
	}

	.warning-btn {
		background: #fffbeb;
		color: #f59e0b;
		border: 2rpx solid #fde68a;
	}

	.promise-btn {
		background: #ecfeff;
		color: #06b6d4;
		border: 2rpx solid #a5f3fc;
	}

	.form-btn {
		background: #f5f3ff;
		color: #8b5cf6;
		border: 2rpx solid #ddd6fe;
	}

	.bg-btn {
		background: #fff7ed;
		color: #f97316;
		border: 2rpx solid #fed7aa;
	}

	.footer-btn {
		background: #f0fdfa;
		color: #14b8a6;
		border: 2rpx solid #99f6e4;
	}

	.close-btn {
		background: #f8fafc;
		color: #64748b;
		border: 2rpx solid #e2e8f0;
	}

	.custom-btn {
		background: #fdf2f8;
		color: #ec4899;
		border: 2rpx solid #fbcfe8;
	}

	.loading-btn {
		background: #eef2ff;
		color: #6366f1;
		border: 2rpx solid #c7d2fe;
	}

	/* 调用结果 */
	.result-card {
		padding: 24rpx;
		background: #f0fdf4;
		border-radius: 16rpx;
		border: 2rpx solid #bbf7d0;
	}

	.result-text {
		font-size: 26rpx;
		color: #166534;
		word-break: break-all;
	}

	/* ====== 弹窗内部样式 ====== */

	/* 订单信息 */
	.order-info {
		padding: 10rpx 0;
	}

	.order-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 18rpx 0;
		border-bottom: 1rpx solid #f1f5f9;

		&:last-child {
			border-bottom: none;
		}
	}

	.order-label {
		font-size: 26rpx;
		color: #94a3b8;
	}

	.order-value {
		font-size: 28rpx;
		color: #1e293b;
		font-weight: 500;

		&.price {
			color: #ef4444;
			font-weight: 700;
			font-size: 32rpx;
		}

		&.status {
			color: #f59e0b;
			font-weight: 600;
		}
	}

	/* 多按钮组 */
	.multi-btn-group {
		display: flex;
		gap: 16rpx;
		width: 100%;
	}

	.multi-btn {
		flex: 1;
		height: 80rpx;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 40rpx;
		font-size: 26rpx;
		font-weight: 600;
		transition: all 0.2s ease;

		&:active {
			transform: scale(0.96);
		}

		text {
			color: inherit;
		}
	}

	.btn-cancel {
		background: #f8fafc;
		color: #64748b;
		border: 2rpx solid #e2e8f0;
	}

	.btn-detail {
		background: #eff6ff;
		color: #3b82f6;
		border: 2rpx solid #bfdbfe;
	}

	.btn-pay {
		background: linear-gradient(135deg, #10b981, #059669);
		color: #ffffff;
		box-shadow: 0 8rpx 20rpx rgba(16, 185, 129, 0.3);
	}

	/* 公告内容 */
	.notice-content {
		padding: 10rpx 0;
	}

	.notice-title {
		font-size: 30rpx;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 20rpx;
		text-align: center;
	}

	.notice-body {
		font-size: 26rpx;
		color: #64748b;
		line-height: 1.8;
		text-align: justify;
		margin-bottom: 24rpx;
	}

	.notice-date {
		font-size: 24rpx;
		color: #94a3b8;
		text-align: right;
	}
</style>
```

