---
title: el-table 双击单元格修改
cover: https://p7.qhimg.com/bdm/0_0_100/t0194a1161f2ce1524e.jpg
banner: https://p7.qhimg.com/bdm/0_0_100/t0194a1161f2ce1524e.jpg
date: 2025-05-01
categories: 
  - 笔记
tags:
  - Vue
  - Element
---

在使用 Element UI 的 `el-table` 时，我们经常会遇到这样的需求：**在表格中直接双击某个单元格就能进入编辑状态，输入完成后按回车或失去焦点自动保存**。这个功能在后台管理系统中非常实用，省去了跳转到编辑页面的繁琐操作。本文就来详细记录一下这个交互的实现方式。

## 核心思路

实现这个效果主要分为三步：

1. 给 `el-table` 绑定 `cell-dblclick` 事件，监听单元格双击
2. 双击时记录当前行和列信息，显示输入框（`el-input`）
3. 输入完成后，触发保存逻辑并更新数据

## 基础表格结构

先准备一个基础的 `el-table`：

```vue
<template>
  <el-table
    :data="tableData"
    border
    @cell-dblclick="handleCellDblClick"
  >
    <el-table-column prop="name" label="姓名" />
    <el-table-column prop="age" label="年龄" />
    <el-table-column prop="address" label="地址" />
  </el-table>
</template>

<script>
export default {
  data() {
    return {
      tableData: [
        { name: '张三', age: 24, address: '上海市' },
        { name: '李四', age: 28, address: '北京市' },
        { name: '王五', age: 32, address: '广州市' }
      ],
      editRow: null,
      editColumn: null,
      editValue: ''
    }
  },
  methods: {
    handleCellDblClick(row, column, cell, event) {
      // 双击逻辑
    }
  }
}
</script>
```

## 实现双击编辑

关键点是利用 Vue 的 **作用域插槽**（`scoped-slot`）来控制单元格的渲染状态。平时显示普通文本，双击时切换成 `el-input`。

```vue
<template>
  <el-table
    :data="tableData"
    border
    @cell-dblclick="handleCellDblClick"
  >
    <el-table-column prop="name" label="姓名">
      <template #default="{ row }">
        <el-input
          v-if="editRow === row && editColumn === 'name'"
          v-model="editValue"
          size="small"
          @blur="handleSave"
          @keyup.enter="handleSave"
          ref="inputRef"
        />
        <span v-else>{{ row.name }}</span>
      </template>
    </el-table-column>

    <el-table-column prop="age" label="年龄">
      <template #default="{ row }">
        <el-input
          v-if="editRow === row && editColumn === 'age'"
          v-model="editValue"
          size="small"
          @blur="handleSave"
          @keyup.enter="handleSave"
          ref="inputRef"
        />
        <span v-else>{{ row.age }}</span>
      </template>
    </el-table-column>

    <el-table-column prop="address" label="地址">
      <template #default="{ row }">
        <el-input
          v-if="editRow === row && editColumn === 'address'"
          v-model="editValue"
          size="small"
          @blur="handleSave"
          @keyup.enter="handleSave"
          ref="inputRef"
        />
        <span v-else>{{ row.address }}</span>
      </template>
    </el-table-column>
  </el-table>
</template>
```

## 事件处理逻辑

```javascript
methods: {
  handleCellDblClick(row, column) {
    // 如果已经在编辑另一个单元格，先保存
    if (this.editRow) {
      this.handleSave()
    }
    this.editRow = row
    this.editColumn = column.property
    this.editValue = row[column.property]

    // 自动聚焦输入框（需要等 DOM 更新）
    this.$nextTick(() => {
      this.$refs.inputRef?.focus()
    })
  },

  handleSave() {
    if (!this.editRow || !this.editColumn) return

    // 可以在这里做数据校验
    if (this.editColumn === 'age' && !/^\d+$/.test(this.editValue)) {
      this.$message.warning('年龄必须为数字')
      return
    }

    // 更新数据
    this.editRow[this.editColumn] = this.editValue

    // 清空编辑状态
    this.editRow = null
    this.editColumn = null
    this.editValue = ''

    this.$message.success('保存成功')
  }
}
```

## 关键要点

### 1. 为什么用 `cell-dblclick` 而不是 `row-dblclick`？

`cell-dblclick` 能直接拿到 `column` 参数，包含了 `property`（对应列的 `prop`），而 `row-dblclick` 只能拿到行数据，无法知道用户点了哪一列。

### 2. 输入框自动聚焦

用 `this.$nextTick()` 包裹 `focus()` 调用，因为 `v-if` 切换后输入框的 DOM 还未插入，要等 Vue 完成一次更新周期。

### 3. 如何避免保存错乱

同时只能编辑一个单元格，所以在开启新编辑前，先判断 `this.editRow` 是否存在，存在则先执行 `handleSave()`。

### 4. 数据校验

`handleSave` 里可以对特定字段做校验，比如年龄必须是数字、邮箱格式等。校验不通过时阻止保存并给出提示。

## 效果预览

实际效果就是：**双击任意单元格** → 该单元格变成输入框并自动聚焦 → **回车或点击外部** → 数据更新并恢复为普通文本。

## 写在最后

这种方式适合字段较少、编辑频率不高的场景。如果列数很多，可以考虑封装一个 **可编辑表格组件**，通过 `render` 函数动态生成插槽，避免重复写大量模板代码。如果有更多行内操作需求，也可以结合 `el-popover` 做成浮层编辑面板，体验会更好。
