# Symphony 全生命周期自动化系统 - MVP 使用指南

## 概述

本 MVP 基于 symphony-elixir 项目扩展，实现了从需求到部署的全流程自动化系统，包括：

1. **需求评估 Agent** - 填充、检查需求合理性、待确认项
2. **设计文档 Agent** - 生成技术文档 (spec)
3. **开发 Agent** - 生成开发计划 + 实施落地
4. **产物确认 Agent** - 产物验证后自动合入主干

## 快速开始

### 1. 配置飞书多维表格

创建飞书多维表格，包含以下字段：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| 标题 | 文本 | 需求标题 |
| 描述 | 多行文本 | 需求描述 |
| 状态 | 单选 | 见下方状态列表 |
| 进度 | 进度 | 0-100% |
| 当前任务 | 文本 | 当前正在进行的任务 |
| 优先级 | 单选 | P1/P2/P3/P4 |

### 2. 配置状态选项

在飞书多维表格中配置"状态"字段的选项：

```
待处理
需求评估中
待设计确认
设计中
待开发
开发中
待产物确认
确认中
已完成
需修改
已关闭
```

### 3. 配置 WORKFLOW.md

复制 `WORKFLOW_LIFECYCLE.md` 到你的项目根目录，并根据需要修改：

```bash
cp WORKFLOW_LIFECYCLE.md WORKFLOW.md
```

修改以下配置项：
- `tracker.app_token` - 你的飞书应用 token
- `tracker.table_id` - 你的飞书多维表格 ID
- `workspace.root` - 工作空间根目录
- `hooks` - 根据你的项目配置 hooks

### 4. 启动 Symphony

```bash
# 设置飞书环境变量
export FEISHU_APP_ID=your_app_id
export FEISHU_APP_SECRET=your_app_secret

# 启动 Symphony
./bin/symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails --port 4000 WORKFLOW.md
```

### 5. 访问 Dashboard

打开浏览器访问：http://127.0.0.1:4000/

## 工作流程

### 自动化流程

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ 需求评估     │────▶│ 设计文档     │────▶│ 开发实施     │────▶│ 产物确认     │
│ Agent        │     │ Agent        │     │ Agent        │     │ Agent        │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
      │                    │                    │                    │
      ▼                    ▼                    ▼                    ▼
  [人工确认]           [人工确认]           [自动执行]           [人工确认]
```

### 人工确认操作

当任务进入需要确认的阶段时，你可以在 Dashboard 中看到"确认"按钮。

确认选项：
- **批准**: 进入下一阶段
- **拒绝**: 返回当前阶段修改

## 目录结构

```
symphony-elixir/
├── lib/symphony_elixir/
│   └── lifecycle/                    # 新增：生命周期模块
│       ├── stage_state_machine.ex    # 阶段状态机
│       ├── stage_orchestrator.ex    # 阶段编排器
│       └── stage_prompt_builder.ex  # 阶段 Prompt 构建器
│
├── templates/                        # 新增：Prompt 模板
│   ├── REQUIREMENT_ASSESSMENT.md    # 需求评估模板
│   ├── DESIGN_DOCUMENT.md           # 设计文档模板
│   ├── DEVELOPMENT.md               # 开发实施模板
│   └── ARTIFACT_CONFIRMATION.md     # 产物确认模板
│
├── test/lifecycle/                   # 新增：测试文件
│   ├── stage_state_machine_test.exs
│   ├── stage_orchestrator_test.exs
│   └── stage_prompt_builder_test.exs
│
└── WORKFLOW_LIFECYCLE.md            # 新增：生命周期配置示例
```

## 配置说明

### Lifecycle 配置

```yaml
lifecycle:
  enabled: true  # 启用生命周期功能
  stages:        # 阶段定义
    - name: "requirement_assessment"
      display_name: "需求评估"
      prompt_template: "REQUIREMENT_ASSESSMENT.md"
      initial_states: ["待处理"]
      target_states: ["需求评估中"]
      output_states: ["待设计确认", "需求需补充"]
      max_turns: 10
      confirmation_required: true  # 需要人工确认

  confirmation_points:  # 需要确认的阶段
    - "requirement_assessment"
    - "design_document"
    - "artifact_confirmation"

  stage_transitions:  # 状态到阶段的映射
    "待处理": "requirement_assessment"
    "需求评估中": "requirement_assessment"
    # ...
```

### 阶段配置说明

每个阶段包含以下配置：

| 配置项 | 说明 | 示例 |
|--------|------|------|
| name | 阶段唯一标识 | "requirement_assessment" |
| display_name | 阶段显示名称 | "需求评估" |
| prompt_template | Prompt 模板文件 | "REQUIREMENT_ASSESSMENT.md" |
| initial_states | 触发此阶段的状态列表 | ["待处理"] |
| target_states | 执行时的目标状态 | ["需求评估中"] |
| output_states | 完成后的输出状态 | ["待设计确认", "需求需补充"] |
| max_turns | 最大执行轮数 | 10 |
| confirmation_required | 是否需要人工确认 | true |

## API 接口

### 阶段状态机 API

```elixir
# 确定当前阶段
SymphonyElixir.Lifecycle.StageStateMachine.determine_stage("待处理")
# => {:ok, %{name: "requirement_assessment", ...}}

# 转换到下一阶段
SymphonyElixir.Lifecycle.StageStateMachine.transition_to_next_stage("issue_id", "requirement_assessment", :approved)
# => {:ok, "design_document"}

# 检查是否需要确认
SymphonyElixir.Lifecycle.StageStateMachine.requires_confirmation?("requirement_assessment")
# => true
```

### 阶段编排器 API

```elixir
# 处理 issue
SymphonyElixir.Lifecycle.StageOrchestrator.process_issue(issue)
# => {:ok, :awaiting_confirmation, "requirement_assessment"}

# 确认阶段
SymphonyElixir.Lifecycle.StageOrchestrator.confirm_stage("issue_id", "requirement_assessment", :approved, "通过了")
# => {:ok, :transitioned, "design_document"}
```

## 故障排查

### 问题：阶段没有自动启动

**检查**：
1. 确保 `lifecycle.enabled: true`
2. 检查飞书状态是否在 `active_states` 中
3. 查看日志中的错误信息

### 问题：确认后没有进入下一阶段

**检查**：
1. 确保 `stage_transitions` 配置正确
2. 检查 `output_states` 是否包含下一阶段的 `initial_states`

### 问题：Agent 执行失败

**检查**：
1. 确保 Codex 已安装并可用
2. 检查工作空间权限
3. 查看 Agent 执行日志

## 扩展指南

### 添加新阶段

1. 在 `WORKFLOW.md` 中添加阶段配置
2. 在 `templates/` 目录创建对应的 Prompt 模板
3. 更新 `stage_transitions` 映射

### 自定义 Agent

实现自定义 Agent 逻辑，在 `StageOrchestrator.execute_stage_agent/2` 中调用。

### 集成其他系统

通过 Hooks 系统集成 CI/CD、监控系统等。

## 限制和注意事项

1. **并发限制**: 同时运行的 Agent 数量受 `max_concurrent_agents` 限制
2. **状态同步**: 飞书状态更新可能有 30 秒延迟
3. **确认超时**: 需要确认的阶段会一直等待，无超时机制
4. **工作空间**: 每个 issue 创建独立工作空间，占用磁盘空间

## 下一步

- [ ] 添加更多 Prompt 模板
- [ ] 支持自定义 Agent 类型
- [ ] 添加超时机制
- [ ] 改进错误处理和重试逻辑
- [ ] 添加更多监控指标

## 许可证

本项目基于 Apache License 2.0 开源。
