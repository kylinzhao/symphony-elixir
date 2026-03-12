---
# Symphony 多项目配置示例

# 全局配置
polling:
  interval_ms: 30000

# 多项目定义
projects:
  # 项目 A: 前端应用
  - name: "前端应用"
    id: "frontend_app"
    tracker:
      kind: feishu
      bitable:
        app_token: "frontend_app_token"
        table_id: "frontend_table_id"
      api_key: $FEISHU_API_KEY
      active_states:
        - 待处理
        - 进行中
      terminal_states:
        - 已完成
        - 已关闭

    workspace:
      root: ~/symphony-workspaces/frontend

    agent:
      max_concurrent_agents: 3  # 该项目的最大并发数

    hooks:
      after_create: |
        git clone https://github.com/your-org/frontend-app.git .
        npm install

      after_run: |
        npm test
        npm run build

  # 项目 B: 后端服务
  - name: "后端服务"
    id: "backend_service"
    tracker:
      kind: feishu
      bitable:
        app_token: "backend_app_token"
        table_id: "backend_table_id"
      api_key: $FEISHU_API_KEY
      active_states:
        - 待处理
        - 进行中
      terminal_states:
        - 已完成
        - 已关闭

    workspace:
      root: ~/symphony-workspaces/backend

    agent:
      max_concurrent_agents: 5

    hooks:
      after_create: |
        git clone https://github.com/your-org/backend-service.git .
        pip install -r requirements.txt

      after_run: |
        pytest
        make deploy

  # 项目 C: 移动应用
  - name: "移动应用"
    id: "mobile_app"
    tracker:
      kind: linear
      project_slug: "mobile-app"
      api_key: $LINEAR_API_KEY
      active_states:
        - Todo
        - In Progress
      terminal_states:
        - Done
        - Closed

    workspace:
      root: ~/symphony-workspaces/mobile

    agent:
      max_concurrent_agents: 2

    hooks:
      after_create: |
        git clone https://github.com/your-org/mobile-app.git .
        flutter pub get

      after_run: |
        flutter test
        flutter build apk

# 全局 Agent 限制
agent:
  global_max_concurrent_agents: 10  # 所有项目的总并发限制

# Codex 配置 (全局)
codex:
  command: codex app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
  turn_timeout_ms: 3600000

# Web Dashboard
server:
  port: 4000
---

# Symphony 多项目工作流

你正在处理多项目需求 **`{{ issue.identifier }}`**

## 项目信息

**项目**: {{ issue.project_name }}
**项目 ID**: {{ issue.project_id }}

## 需求信息

**标题**: {{ issue.title }}
**状态**: {{ issue.state }}
**优先级**: {{ issue.priority }}

{% if issue.description %}
**描述**:
{{ issue.description }}
{% endif %}

---

## 📊 多项目说明

此 Symphony 实例管理 **多个项目**:

### 项目列表

| 项目 | 最大并发 | 状态 | 工作空间 |
|------|----------|------|----------|
| 前端应用 | 3 | ✅ 活跃 | ~/symphony-workspaces/frontend |
| 后端服务 | 5 | ✅ 活跃 | ~/symphony-workspaces/backend |
| 移动应用 | 2 | ✅ 活跃 | ~/symphony-workspaces/mobile |

### 资源分配

- **全局并发限制**: 10 个 Agent
- **跨项目调度**: 自动平衡
- **优先级排序**: 跨项目统一排序

### 任务调度

Symphony 会:

1. **轮询所有项目**: 获取各项目的候选任务
2. **统一排序**: 按优先级和时间排序
3. **分配槽位**: 根据项目限制和全局限制分配
4. **隔离执行**: 每个任务在独立的工作空间中执行

---

## 🚀 执行指南

### 1. 确认项目上下文

```bash
# 当前项目: {{ issue.project_name }}
# 工作空间: ~/symphony-workspaces/{{ issue.project_id }}
```

### 2. 项目特定操作

根据不同项目,执行相应的操作:

**前端应用**:
```bash
npm install
npm test
npm run build
```

**后端服务**:
```bash
pip install -r requirements.txt
pytest
make deploy
```

**移动应用**:
```bash
flutter pub get
flutter test
flutter build apk
```

### 3. 跨项目依赖

如果当前任务依赖其他项目:

1. 检查依赖项目的工作空间
2. 确认依赖项目的状态
3. 等待依赖任务完成

### 4. 更新需求状态

完成任务后,更新项目对应的 Tracker:

- **飞书项目**: 通过 `feishu_bitable` 工具更新
- **Linear 项目**: 通过 `linear_graphql` 工具更新

---

## 📈 监控和报告

### 项目统计

Symphony Dashboard 会显示:

- 各项目的任务分布
- 各项目的 Agent 使用情况
- 各项目的完成率

### 资源使用

- 全局并发: X / 10
- 项目并发: 按项目分配
- 工作空间: 独立隔离

---

## ✅ 开始执行

你正在处理项目 **`{{ issue.project_name }}`** 的需求。

请确保:
- [ ] 理解当前项目的上下文
- [ ] 使用正确的工作空间
- [ ] 执行项目特定的命令
- [ ] 更新正确的 Tracker

开始执行! 🚀
