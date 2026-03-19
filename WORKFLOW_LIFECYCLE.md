---
# Symphony 全生命周期自动化配置示例

# Tracker 配置
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
    - name: "requirement_assessment"
      display_name: "需求评估"
      agent_type: "requirement_agent"
      prompt_template: "REQUIREMENT_ASSESSMENT.md"
      initial_states: ["待处理"]
      target_states: ["需求评估中"]
      output_states: ["待设计确认", "需求需补充"]
      max_turns: 10
      confirmation_required: true

    - name: "design_document"
      display_name: "设计文档"
      agent_type: "design_agent"
      prompt_template: "DESIGN_DOCUMENT.md"
      initial_states: ["待设计确认"]
      target_states: ["设计中"]
      output_states: ["待开发", "设计需修改"]
      max_turns: 15
      confirmation_required: true

    - name: "development"
      display_name: "开发实施"
      agent_type: "development_agent"
      prompt_template: "DEVELOPMENT.md"
      initial_states: ["待开发"]
      target_states: ["开发中"]
      output_states: ["待产物确认", "开发需修改"]
      max_turns: 20
      confirmation_required: false

    - name: "artifact_confirmation"
      display_name: "产物确认"
      agent_type: "confirmation_agent"
      prompt_template: "ARTIFACT_CONFIRMATION.md"
      initial_states: ["待产物确认"]
      target_states: ["确认中"]
      output_states: ["已完成", "需修改"]
      max_turns: 5
      confirmation_required: true

  confirmation_points:
    - "requirement_assessment"
    - "design_document"
    - "artifact_confirmation"

  stage_transitions:
    "待处理": "requirement_assessment"
    "需求评估中": "requirement_assessment"
    "待设计确认": "design_document"
    "设计中": "design_document"
    "待开发": "development"
    "开发中": "development"
    "待产物确认": "artifact_confirmation"
    "确认中": "artifact_confirmation"
    "需求需补充": "requirement_assessment"
    "设计需修改": "design_document"
    "开发需修改": "development"
    "需修改": "artifact_confirmation"

# Polling 配置
polling:
  interval_ms: 30000

# Workspace 配置
workspace:
  root: ~/symphony-workspaces

# Hooks 配置
hooks:
  after_create: |
    git clone https://github.com/your-org/your-repo.git .
    make setup

  before_run: |
    make lint

  after_run: |
    make test
    TEST_RESULT=$?

    if [ $TEST_RESULT -eq 0 ]; then
      echo "✅ 测试通过"
      # 触发部署 (根据分支自动判断)
      BRANCH=$(git branch --show-current)
      if [[ "$BRANCH" == *"develop"* ]] || [[ "$BRANCH" == *"feature"* ]]; then
        echo "触发 Staging 部署..."
        gh workflow run deploy.yml -f env=staging -f branch=$BRANCH
      elif [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
        echo "触发 Production 部署..."
        gh workflow run deploy.yml -f env=production -f branch=$BRANCH
      fi
    else
      echo "❌ 测试失败"
    fi

  before_remove: |
    make clean
    mix workspace.before_remove --repo myorg/myrepo

# Agent 配置
agent:
  max_concurrent_agents: 5
  max_turns: 20
  max_retry_backoff_ms: 300000

# Codex 配置
codex:
  command: codex app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
  turn_timeout_ms: 3600000
  read_timeout_ms: 5000
  stall_timeout_ms: 300000

# CI/CD 配置
ci_cd:
  enabled: true
  platform: github_actions
  workflow: deploy.yml
  environments:
    - name: staging
      auto_deploy: true
      branch_pattern: "develop|feature.*"
    - name: production
      auto_deploy: true
      branch_pattern: "main|master"
  status_mapping:
    success:
      state: "已完成"
      comment_template: "✅ 部署成功: {env} | SHA: {sha} | 分支: {branch}"
    failure:
      state: "需修改"
      comment_template: "❌ 部署失败: {env}\n错误: {error}\n分支: {branch}"

# Server 配置
server:
  port: 4000
  host: "127.0.0.1"
---

# Symphony 全生命周期自动化工作流

你正在处理需求 **`{{ issue.identifier }}`**

## 需求信息

**标题**: {{ issue.title }}
**当前状态**: {{ issue.state }}
**当前阶段**: <自动检测>

---

## 全生命周期自动化说明

此工作流启用了**全生命周期自动化**，包含以下四个阶段：

### 阶段流程

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ 需求评估     │────▶│ 设计文档     │────▶│ 开发实施     │────▶│ 产物确认     │
│ (需确认)     │     │ (需确认)     │     │ (自动)       │     │ (需确认)     │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

### 1. 需求评估阶段

**目标**: 填充、检查需求合理性、待确认项

**输出**:
- `REQUIREMENT_ASSESSMENT.md` - 需求评估报告

**状态流转**:
- 输入: `待处理`
- 输出: `待设计确认` ✅ 或 `需求需补充` ❌

### 2. 设计文档阶段

**目标**: 生成技术设计文档 (spec)

**输出**:
- `DESIGN_DOCUMENT.md` - 技术设计文档

**状态流转**:
- 输入: `待设计确认`
- 输出: `待开发` ✅ 或 `设计需修改` ❌

### 3. 开发实施阶段

**目标**: 生成开发计划 + 实施落地 + 产物确认

**输出**:
- `TASK_PLAN.json` - 开发任务计划
- 源代码和测试

**状态流转**:
- 输入: `待开发`
- 输出: `待产物确认` ✅ 或 `开发需修改` ❌

### 4. 产物确认阶段

**目标**: 验证开发产物，准备合入主干

**输出**:
- `ARTIFACT_CONFIRMATION.md` - 产物确认报告

**状态流转**:
- 输入: `待产物确认`
- 输出: `已完成` ✅ 或 `需修改` ❌

---

## 执行指南

### 人工确认操作

当任务进入需要确认的阶段时：

1. 查看工作空间中的对应文档
2. 验证内容是否符合要求
3. 通过 Dashboard 或 API 确认：
   - **批准**: 进入下一阶段
   - **拒绝**: 返回当前阶段修改

### 工作空间位置

每个需求都有独立的工作空间：
```
~/symphony-workspaces/{{ issue.identifier }}/
```

### 监控进度

访问 Dashboard: http://127.0.0.1:4000/

---

## 成功标准

一个成功的全生命周期自动化应该包括：

1. ✅ 需求评估完整且合理
2. ✅ 设计文档规范且可行
3. ✅ 代码实现符合设计
4. ✅ 测试覆盖充分
5. ✅ 产物验证通过
6. ✅ 自动合入主干

---

**现在开始执行你的任务！记住：每个阶段完成后会自动更新飞书状态。**
