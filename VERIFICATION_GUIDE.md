# Symphony 生命周期自动化 - 启动和验证指南

## 📋 前置条件检查

### 1. 检查 Elixir 环境

```bash
elixir --version
# 应该显示: Elixir 1.18+ 或更高版本
```

### 2. 检查项目依赖

```bash
mix deps.get
```

### 3. 检查编译状态

```bash
mix compile
# 应该显示: Generated symphony_elixir app
```

---

## 🚀 启动服务

### 步骤 1: 启动 Symphony 服务

```bash
./bin/symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails --port 4000 WORKFLOW_TEST.md
```

**预期输出**:
```
info:  Application symphony_elixir started
info:  Lifecycle Stage Orchestrator started
info:  Listening on http://127.0.0.1:4000
```

### 步骤 2: 验证服务启动

打开新终端，检查服务状态：

```bash
curl http://127.0.0.1:4000/api/v1/state
```

**预期输出**: JSON 格式的状态信息

---

## ✅ 验证步骤

### 验证 1: 检查生命周期模块加载

在 IEx 控制台中执行：

```elixir
# 检查配置
SymphonyElixir.Config.settings!().lifecycle
# 应该返回: %{enabled: true, stages: [...], ...}
```

### 验证 2: 测试阶段状态机

```elixir
# 测试阶段判断
SymphonyElixir.Lifecycle.StageStateMachine.determine_stage("待处理")
# 应该返回: {:ok, %{name: "requirement_assessment", ...}}
```

### 验证 3: 测试确认点检查

```elixir
# 测试确认点
SymphonyElixir.Lifecycle.StageStateMachine.requires_confirmation?("requirement_assessment")
# 应该返回: true

SymphonyElixir.Lifecycle.StageStateMachine.requires_confirmation?("development")
# 应该返回: false
```

### 验证 4: 访问 Web Dashboard

在浏览器中打开：

```
http://127.0.0.1:4000/
```

**应该看到**: Symphony Dashboard 界面

### 验证 5: 运行单元测试

```bash
mix test test/lifecycle/
```

**预期结果**: 所有测试通过

```
...
Finished in 0.05 seconds
7 tests, 0 failures
```

---

## 📊 完整的端到端测试流程

### 测试场景: 模拟完整生命周期

#### 步骤 1: 创建测试 Issue

在 IEx 控制台中：

```elixir
# 创建一个测试 issue
test_issue = %{
  id: "test-001",
  identifier: "TEST-001",
  title: "实现用户登录功能",
  description: "实现基于邮箱和密码的用户登录功能",
  state: "待处理"
}

# 处理 issue
SymphonyElixir.Lifecycle.StageOrchestrator.process_issue(test_issue)
```

#### 步骤 2: 验证阶段判断

```elixir
# 确认进入需求评估阶段
SymphonyElixir.Lifecycle.StageStateMachine.determine_stage("待处理")
# => {:ok, %{name: "requirement_assessment", ...}}
```

#### 步骤 3: 测试阶段转换

```elixir
# 模拟需求评估完成，转换到下一阶段
SymphonyElixir.Lifecycle.StageStateMachine.transition_to_next_stage(
  "test-001",
  "requirement_assessment",
  :approved
)
# => {:ok, "design_document"}
```

#### 步骤 4: 验证阶段历史

```elixir
# 查看阶段转换历史
SymphonyElixir.Lifecycle.StageStateMachine.get_stage_history("test-001")
# => [
#      %{from_stage: "requirement_assessment", to_stage: "design_document", ...}
#    ]
```

#### 步骤 5: 测试人工确认

```elixir
# 模拟人工确认设计文档
SymphonyElixir.Lifecycle.StageOrchestrator.confirm_stage(
  "test-001",
  "design_document",
  :approved,
  "设计方案合理"
)
# => {:ok, :transitioned, "development"}
```

---

## 🔍 故障排查

### 问题 1: 端口被占用

**错误信息**: `eaddrinuse`

**解决方案**:
```bash
# 查找占用 4000 端口的进程
lsof -i :4000

# 杀死进程或使用其他端口
./bin/symphony ... --port 4001 WORKFLOW_TEST.md
```

### 问题 2: 生命周期未启用

**现象**: Dashboard 中没有看到阶段信息

**解决方案**:
1. 检查 `WORKFLOW_TEST.md` 中 `lifecycle.enabled: true`
2. 重新启动服务

### 问题 3: 配置解析错误

**错误信息**: `workflow_parse_error`

**解决方案**:
1. 检查 YAML 格式是否正确
2. 确保 YAML 前后都有 `---` 分隔符

---

## 📈 验证检查清单

使用此检查清单确保系统正常工作：

- [ ] Elixir 版本正确 (1.18+)
- [ ] 依赖安装完成 (`mix deps.get`)
- [ ] 编译成功 (`mix compile`)
- [ ] 服务启动成功
- [ ] Dashboard 可访问 (http://127.0.0.1:4000)
- [ ] 生命周期功能启用
- [ ] 阶段状态机工作正常
- [ ] 单元测试全部通过
- [ ] 阶段转换功能正常
- [ ] 确认点检查正常

---

## 🎯 下一步

验证完成后，你可以：

1. **配置飞书集成** - 设置真实的飞书应用
2. **创建 WORKFLOW.md** - 根据实际需求配置
3. **添加自定义阶段** - 扩展现有阶段
4. **自定义 Prompt 模板** - 优化 Agent 提示
