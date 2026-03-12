---
# Tracker 配置
tracker:
  kind: feishu
  bitable:
    app_token: "your_app_token"
    table_id: "your_table_id"
  api_key: $FEISHU_API_KEY
  active_states:
    - 待处理
    - 进行中
    - 待审核
    - 需修改
  terminal_states:
    - 已完成
    - 已关闭

# Polling 配置
polling:
  interval_ms: 30000

# Workspace 配置
workspace:
  root: ~/symphony-workspaces

# Hooks 配置 (与 CI/CD 集成)
hooks:
  after_create: |
    git clone https://github.com/your-org/your-repo.git .
    make setup

  before_run: |
    make lint

  after_run: |
    # 运行测试
    make test
    TEST_RESULT=$?

    if [ $TEST_RESULT -eq 0 ]; then
      echo "✅ 测试通过"

      # 触发 Staging 部署
      echo "触发 Staging 部署..."
      gh workflow run deploy.yml -f env=staging -f branch=$(git branch --show-current)

      # 获取最新的 workflow run ID
      RUN_ID=$(gh run list --workflow=deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')

      # 等待部署完成
      echo "等待部署完成..."
      sleep 30

      # 检查部署状态
      STATUS=$(gh run view $RUN_ID --json conclusion --jq '.conclusion')
      if [ "$STATUS" = "success" ]; then
        echo "✅ 部署成功"
        # 通过 AI 工具更新飞书状态
        exit 0
      else
        echo "❌ 部署失败: $STATUS"
        exit 1
      fi
    else
      echo "❌ 测试失败"
      exit 1
    fi

  before_remove: |
    make clean

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

# CI/CD 配置 (新增)
ci_cd:
  enabled: true
  platform: github_actions  # github_actions | gitlab_ci | jenkins | custom
  workflow: deploy.yml

  # 环境配置
  environments:
    - name: staging
      auto_deploy: true  # 测试环境自动部署
      required_checks:
        - test
        - lint

    - name: production
      auto_deploy: false  # 生产环境需要手动确认
      required_checks:
        - test
        - lint
        - security_scan

  # 部署状态映射回 Tracker
  status_mapping:
    success:
      state: "已完成"
      comment_template: "✅ 部署成功: {env} ({sha})"
    failure:
      state: "需修改"
      comment_template: "❌ 部署失败: {env}\n错误: {error}"

# Web Dashboard
server:
  port: 4000
---

# Symphony CI/CD 工作流

你正在处理需求 **`{{ issue.identifier }}`**

## CI/CD 集成说明

此工作流集成了 CI/CD 自动化部署:

### 自动化流程

1. **代码提交** → 自动触发测试
2. **测试通过** → 自动部署到 Staging
3. **Staging 验证** → 人工审核
4. **审核通过** → 部署到 Production (需要手动确认)

### 环境说明

- **Staging**: 自动部署,用于测试验证
- **Production**: 需要手动审批,用于生产环境

### 部署状态

部署状态会自动反馈到飞书多维表格:
- ✅ 成功 → 状态更新为"已完成"
- ❌ 失败 → 状态更新为"需修改",并记录错误信息

## 执行指南

1. **开发和测试**
   - 编写代码
   - 运行本地测试: `make test`
   - 确保所有测试通过

2. **提交代码**
   - 创建 commit
   - 推送到远程分支
   - 自动触发 CI 流水线

3. **部署验证**
   - 等待 CI/CD 流水线完成
   - 在 Staging 环境验证功能
   - 记录验证结果

4. **完成需求**
   - 更新飞书状态为"待审核"
   - 等待人工审核和 Production 部署

开始执行吧! 🚀
