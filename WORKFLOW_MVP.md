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
    make setup  # 或 npm install, pip install -r requirements.txt 等

  before_run: |
    make lint  # 或 npm run lint 等

  after_run: |
    # 运行测试
    make test  # 或 npm test, pytest 等
    TEST_RESULT=$?

    if [ $TEST_RESULT -eq 0 ]; then
      echo "✅ 测试通过"

      # 获取当前分支
      BRANCH=$(git branch --show-current)
      echo "当前分支: $BRANCH"

      # 触发部署 (staging 或 production 根据分支自动判断)
      if [[ "$BRANCH" == *"develop"* ]] || [[ "$BRANCH" == *"feature"* ]]; then
        echo "触发 Staging 部署..."
        gh workflow run deploy.yml -f env=staging -f branch=$BRANCH
      elif [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
        echo "触发 Production 部署..."
        gh workflow run deploy.yml -f env=production -f branch=$BRANCH
      else
        echo "默认触发 Staging 部署..."
        gh workflow run deploy.yml -f env=staging -f branch=$BRANCH
      fi

      # 获取最新的 workflow run ID
      sleep 2
      RUN_ID=$(gh run list --workflow=deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')
      echo "Workflow Run ID: $RUN_ID"

      # 等待部署完成 (最多等待 5 分钟)
      echo "等待部署完成..."
      TIMEOUT=300
      ELAPSED=0

      while [ $ELAPSED -lt $TIMEOUT ]; do
        sleep 10
        ELAPSED=$((ELAPSED + 10))

        STATUS=$(gh run view $RUN_ID --json status --jq '.status')
        CONCLUSION=$(gh run view $RUN_ID --json conclusion --jq '.conclusion')

        echo "状态: $STATUS, 结论: $CONCLUSION"

        if [ "$STATUS" = "completed" ]; then
          if [ "$CONCLUSION" = "success" ]; then
            echo "✅ 部署成功"
            exit 0
          else
            echo "❌ 部署失败: $CONCLUSION"
            exit 1
          fi
        fi
      done

      echo "⏱️ 部署超时"
      exit 1
    else
      echo "❌ 测试失败"
      exit 1
    fi

  before_remove: |
    make clean  # 清理临时文件

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

  # 环境配置
  environments:
    - name: staging
      auto_deploy: true
      branch_pattern: "develop|feature.*"  # 匹配 develop 或 feature- 开头的分支

    - name: production
      auto_deploy: true  # MVP 直接部署,不需要审批
      branch_pattern: "main|master"        # 匹配 main 或 master 分支

  # 部署状态映射
  status_mapping:
    success:
      state: "已完成"
      comment_template: "✅ 部署成功: {env} | SHA: {sha} | 分支: {branch}"
    failure:
      state: "需修改"
      comment_template: "❌ 部署失败: {env}\n错误: {error}\n分支: {branch}"

# Web Dashboard
server:
  port: 4000
---

# Symphony CI/CD 工作流

你正在处理需求 **`{{ issue.identifier }}`**

## 📋 需求信息

**标题**: {{ issue.title }}
**当前状态**: {{ issue.state }}
**优先级**: {{ issue.priority }}
**标签**: {{ issue.labels | join: ", " }}
**链接**: {{ issue.url }}

{% if issue.description %}
### 需求描述
{{ issue.description }}
{% else %}
*无描述*
{% endif %}

---

## 🚀 CI/CD 集成说明

此工作流集成了 **GitHub Actions** CI/CD 自动化部署:

### 自动化流程

```
代码开发 → 测试 → 构建 → 自动部署 → 验证 → 完成
```

### 环境策略

- **Staging 环境**:
  - 分支: `develop`, `feature-*`
  - 自动部署: ✅ 是
  - 触发方式: 推送代码或 PR 合并

- **Production 环境**:
  - 分支: `main`, `master`
  - 自动部署: ✅ 是 (MVP 直接部署)
  - 触发方式: 合并到主分支

### Workflow 文件

GitHub Actions workflow 位于 `.github/workflows/deploy.yml`:

```yaml
jobs:
  test      → 运行测试和 lint
  build     → 构建项目
  deploy    → 部署到环境
```

### 部署状态反馈

部署结果会自动反馈到飞书多维表格:
- ✅ 成功 → 状态: "已完成", 记录 SHA 和分支
- ❌ 失败 → 状态: "需修改", 记录错误信息

---

## 📝 执行指南

### 1. 开发阶段

```bash
# 同步最新代码
git pull origin main

# 创建功能分支
git checkout -b feature/TASK-123

# 开发功能
# ...

# 运行测试
make test

# 运行 lint
make lint
```

### 2. 提交代码

```bash
# 提交代码
git add .
git commit -m "实现 TASK-123: 用户登录功能"

# 推送到远程
git push origin feature/TASK-123
```

### 3. 触发部署

代码推送后,会自动触发 CI/CD 流水线:

1. **测试阶段**: 运行所有测试
2. **构建阶段**: 构建项目
3. **部署阶段**: 根据分支自动选择环境
   - `feature-*` → Staging
   - `develop` → Staging
   - `main/master` → Production

### 4. 监控部署

部署过程会自动在后台运行,你可以通过以下方式监控:

- **GitHub Actions**: 查看 workflow 运行状态
- **飞书多维表格**: 自动更新部署结果
- **Symphony Dashboard**: 实时查看部署进度

### 5. 验证部署

部署完成后,进行以下验证:

- [ ] 访问 Staging/Production 环境
- [ ] 测试核心功能
- [ ] 检查日志和错误
- [ ] 确认性能指标

---

## 🔧 自定义部署

### 修改部署步骤

编辑 `.github/workflows/deploy.yml`:

```yaml
- name: Deploy to Staging
  run: |
    # TODO: 替换为你的部署命令
    kubectl apply -f k8s/staging/
    # 或
    docker-compose -f docker-compose.staging.yml up -d
    # 或
    rsync -avz ./build/ user@server:/var/www/
```

### 修改测试命令

编辑 `hooks.after_run`:

```yaml
after_run: |
  # 替换为你的测试命令
  npm test  # 或 pytest, make test 等
```

### 添加环境变量

在 Workflow 文件中添加:

```yaml
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  API_KEY: ${{ secrets.API_KEY }}
```

---

## ✅ 检查清单

在提交代码前,确保:

- [ ] 所有测试通过 (`make test`)
- [ ] Lint 检查通过 (`make lint`)
- [ ] 代码已提交 (`git commit`)
- [ ] 代码已推送 (`git push`)
- [ ] 分支命名正确 (`feature/TASK-123` 或 `develop` 或 `main`)
- [ ] 飞书需求状态正确

---

## 🎉 开始执行

所有准备工作已完成,现在可以开始开发!

**记住**:
- 自动化部署会在代码推送后自动触发
- 不需要手动部署
- 部署结果会自动反馈到飞书

开始执行吧! 🚀
