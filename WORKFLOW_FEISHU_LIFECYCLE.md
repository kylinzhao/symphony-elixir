---
# Symphony 飞书集成 + 全生命周期自动化配置

# Tracker 配置 - 使用飞书多维表格
tracker:
  kind: feishu
  app_token: $FEISHU_APP_TOKEN
  table_id: $FEISHU_TABLE_ID
  active_states:
    - 待处理
    - 需求评估中
    - 设计中
    - 开发中
    - 确认中
  terminal_states:
    - 已完成
    - 已关闭

# 生命周期配置
lifecycle:
  enabled: true
  stages:
    - name: requirement_assessment
      display_name: 需求评估
      agent_type: requirement_agent
      prompt_template: REQUIREMENT_ASSESSMENT.md
      initial_states: [待处理]
      target_states: [需求评估中]
      output_states: [待设计确认, 需求需补充]
      max_turns: 10
      confirmation_required: true

    - name: design_document
      display_name: 设计文档
      agent_type: design_agent
      prompt_template: DESIGN_DOCUMENT.md
      initial_states: [待设计确认]
      target_states: [设计中]
      output_states: [待开发, 设计需修改]
      max_turns: 15
      confirmation_required: true

    - name: development
      display_name: 开发实施
      agent_type: development_agent
      prompt_template: DEVELOPMENT.md
      initial_states: [待开发]
      target_states: [开发中]
      output_states: [待产物确认, 开发需修改]
      max_turns: 20
      confirmation_required: false

    - name: artifact_confirmation
      display_name: 产物确认
      agent_type: confirmation_agent
      prompt_template: ARTIFACT_CONFIRMATION.md
      initial_states: [待产物确认]
      target_states: [确认中]
      output_states: [已完成, 需修改]
      max_turns: 5
      confirmation_required: true

  confirmation_points:
    - requirement_assessment
    - design_document
    - artifact_confirmation

  stage_transitions:
    待处理: requirement_assessment
    需求评估中: requirement_assessment
    待设计确认: design_document
    设计中: design_document
    待开发: development
    开发中: development
    待产物确认: artifact_confirmation
    确认中: artifact_confirmation
    需求需补充: requirement_assessment
    设计需修改: design_document
    开发需修改: development
    需修改: artifact_confirmation

# Polling 配置
polling:
  interval_ms: 30000

# Workspace 配置
workspace:
  root: ~/symphony-workspaces

# Agent 配置
agent:
  max_concurrent_agents: 2
  max_turns: 20

# Codex 配置
codex:
  command: codex app-server
  approval_policy: never
  thread_sandbox: workspace-write
  model: gpt-5.4-mini
  provider: anthropic
  turn_sandbox_policy:
    type: workspaceWrite
  turn_timeout_ms: 3600000

# Server 配置
server:
  port: 4000
  host: 127.0.0.1
---

# Symphony 飞书集成 - 全生命周期自动化

你正在处理需求 **`{{ issue.identifier }}`**

## 需求信息

**标题**: {{ issue.title }}
**当前状态**: {{ issue.state }}

---

## 全生命周期流程

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ 需求评估     │────▶│ 设计文档     │────▶│ 开发实施     │────▶│ 产物确认     │
│ (需确认)     │     │ (需确认)     │     │ (自动)       │     │ (需确认)     │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

### 阶段说明

1. **需求评估** - 填充、检查需求合理性、待确认项
2. **设计文档** - 生成技术设计文档 (spec)
3. **开发实施** - 生成开发计划 + 实施落地
4. **产物确认** - 验证开发产物，自动合入主干

---

## 飞书状态映射

| 飞书状态 | 阶段 | 说明 |
|---------|------|------|
| 待处理 | 初始 | 新创建的需求 |
| 需求评估中 | 需求评估 | Agent 正在评估 |
| 待设计确认 | 需求评估 | 等待人工确认 |
| 设计中 | 设计文档 | Agent 正在设计 |
| 待开发 | 设计文档 | 等待人工确认 |
| 开发中 | 开发实施 | Agent 正在开发 |
| 待产物确认 | 开发完成 | 等待产物验证 |
| 确认中 | 产物确认 | Agent 正在验证 |
| 已完成 | 完成 | 全流程完成 |
| 需修改 | 需要修改 | 产物验证不通过 |
| 已关闭 | 已关闭 | 任务关闭 |

---

## 使用说明

### 1. 在飞书多维表格创建新需求

- 状态设为 **"待处理"**
- 填写标题和描述

### 2. 观察 Agent 自动执行

- 访问 Dashboard: http://127.0.0.1:4000/
- 查看工作空间: `~/symphony-workspaces/{{ issue.identifier }}/`

### 3. 人工确认

当状态变为 **"待设计确认"**、**"待开发"** 或 **"待产物确认"** 时：

1. 查看工作空间中的文档
2. 验证内容是否符合要求
3. 在飞书中修改状态继续流程：
   - 批准 → 下一阶段
   - 需修改 → 返回当前阶段

---

**现在开始执行你的任务！**
