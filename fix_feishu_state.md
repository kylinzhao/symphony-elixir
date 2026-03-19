# 飞书状态字段修复方案

## 问题分析

经过测试发现：

1. **字段类型**: "状态" 字段类型为 3 (MultiSelect)
2. **存储格式**: 当前存储的值为字符串 `'optdMZkimD'`
3. **显示问题**: 飞书 UI 显示原始 ID (`optdMZkimD`) 而不是选项名称 ("需求评估中")
4. **API 测试结果**:
   - 字符串格式 (`{"状态": "optHsybOol"}`): API 返回成功，但实际值未存储
   - 数组格式 (`{"状态": ["optHsybOol"]}`): API 返回错误 "Single Option must be a string"

## 根本原因

"状态" 字段可能存在以下问题之一：
1. 字段创建时的类型与当前配置不一致
2. 字段配置损坏（选项列表中有损坏的条目）
3. API 与实际字段类型不匹配

## 建议解决方案

### 方案 1: 在飞书界面重新创建 "状态" 字段（推荐）

1. 备份当前数据
2. 在飞书多维表格中删除 "状态" 字段
3. 重新创建 "状态" 字段，选择 **单选** 类型
4. 添加所有状态选项
5. 重新设置每条记录的状态

### 方案 2: 通过 API 修复字段类型

使用飞书 API 更新字段类型为 SingleSelect。

### 方案 3: 临时解决方案 - 使用文本字段

1. 创建一个新的文本字段 "状态文本"
2. 在更新状态时同时设置这两个字段：
   - "状态" 字段：存储选项 ID
   - "状态文本" 字段：存储中文状态名称

## 具体操作步骤（方案 1）

### 步骤 1: 备份当前数据

使用 Python 脚本备份所有记录的状态：

```python
import requests
import json

APP_ID = "cli_a93b804500badbd6"
APP_SECRET = "4V2hQQH4jsOD6ZFO0a4ZPbhcsVPXrXEH"
APP_TOKEN = "J6NBbj3uEa3wlOsNxedcQWO9nPc"
TABLE_ID = "tblJyNAWMLG1TanI"
BASE_URL = "https://open.feishu.cn/open-apis"

# 获取所有记录并保存状态映射
# ... (备份代码)
```

### 步骤 2: 在飞书界面操作

1. 打开飞书多维表格
2. 删除 "状态" 字段
3. 重新创建 "状态" 字段：
   - 类型选择：**单选**
   - 添加选项：待处理、需求评估中、待设计确认、设计中、待开发、开发中、待产物确认、确认中、已完成、需修改、需求需补充、设计需修改、开发需修改、已关闭
4. 保存字段

### 步骤 3: 更新 Elixir 代码

修改 `update_issue_state` 函数，确保使用正确的格式：

```elixir
# 对于 SingleSelect 字段，使用字符串格式
FeishuClient.update_record(app_token, table_id, issue_id, %{
  "状态" => option_id  # 字符串格式的选项 ID
})
```

## 当前状态

- ✅ 选项 ID 映射正确
- ✅ Dashboard 显示正确（有转换逻辑）
- ❌ 飞书 UI 显示选项 ID 而不是名称
- ❌ API 更新格式不确定

## 下一步

请用户：
1. 检查飞书表格中 "状态" 字段的实际类型
2. 如果是 MultiSelect，考虑改为 SingleSelect
3. 或者尝试在飞书界面手动设置一条记录的状态，然后我们读取其格式
