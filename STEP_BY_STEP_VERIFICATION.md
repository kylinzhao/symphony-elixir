# 🎯 Symphony 生命周期自动化 - 逐步验证指南

本文档提供完整的、一步一步的验证流程，确保系统正常运行。

---

## 📋 准备工作

### 第 0 步: 打开两个终端窗口

**终端 A**: 用于启动和监控服务
**终端 B**: 用于执行验证命令

---

## 🚀 第一部分: 快速验证（5分钟）

### 步骤 1: 环境检查

在 **终端 A** 中执行：

```bash
cd /Users/zhaoliang/guazi/work/temp/symphony-elixir/symphony-elixir

# 检查 Elixir 版本
elixir --version
```

**预期输出**:
```
Erlang/OTP 27 [erts-15.2.7]
Elixir 1.18.4 (compiled with Erlang/OTP 27)
```

✅ **检查点**: 确认 Elixir 版本 ≥ 1.18

---

### 步骤 2: 安装依赖

在 **终端 A** 中执行：

```bash
mix deps.get
```

**预期输出**:
```
Resolving Hex dependencies...
Resolution completed in X.XXs
Unchanged:
  [依赖列表]
All dependencies are up to date
```

✅ **检查点**: 所有依赖已安装

---

### 步骤 3: 编译项目

在 **终端 A** 中执行：

```bash
mix compile
```

**预期输出**:
```
Generated symphony_elixir app
```

✅ **检查点**: 编译成功

---

### 步骤 4: 运行测试

在 **终端 A** 中执行：

```bash
mix test test/lifecycle/ --no-start
```

**预期输出**:
```
...
Finished in X.XX seconds
7 tests, 0 failures
```

✅ **检查点**: 所有测试通过

---

## 🎮 第二部分: 交互式验证（10分钟）

### 步骤 5: 启动 IEx 控制台

在 **终端 A** 中启动 Elixir 交互式控制台：

```bash
iex -S mix
```

**预期输出**:
```
Erlang/OTP 27 [erts-15.2.7] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:1]
Interactive Elixir (1.18.4) - press Ctrl+C to exit (type h() ENTER for help)
```

---

### 步骤 6: 验证配置加载

在 **IEx 控制台**（终端 A）中执行：

```elixir
# 读取配置
config = SymphonyElixir.Config.settings!()

# 检查生命周期配置
lifecycle = config.lifecycle
IO.inspect(lifecycle.enabled)
IO.inspect(length(lifecycle.stages))
```

**预期输出**:
```
true
4
```

✅ **检查点**: 
- 生命周期已启用 (enabled: true)
- 定义了 4 个阶段

---

### 步骤 7: 测试阶段状态机

在 **IEx 控制台**中执行：

```elixir
# 测试 1: 判断阶段
SymphonyElixir.Lifecycle.StageStateMachine.determine_stage("待处理")

# 测试 2: 检查确认点
SymphonyElixir.Lifecycle.StageStateMachine.requires_confirmation?("requirement_assessment")

# 测试 3: 检查不需要确认的阶段
SymphonyElixir.Lifecycle.StageStateMachine.requires_confirmation?("development")
```

**预期输出**:
```
{:ok, %{name: "requirement_assessment", ...}}
true
false
```

✅ **检查点**: 阶段判断和确认点检查正常

---

### 步骤 8: 测试阶段转换

在 **IEx 控制台**中执行：

```elixir
# 模拟完整的阶段转换流程
issue_id = "test-001"

# 需求评估 -> 设计文档
{:ok, next1} = SymphonyElixir.Lifecycle.StageStateMachine.transition_to_next_stage(
  issue_id,
  "requirement_assessment",
  :approved
)
IO.inspect(next1)

# 设计文档 -> 开发
{:ok, next2} = SymphonyElixir.Lifecycle.StageStateMachine.transition_to_next_stage(
  issue_id,
  "design_document",
  :approved
)
IO.inspect(next2)

# 开发 -> 产物确认
{:ok, next3} = SymphonyElixir.Lifecycle.StageStateMachine.transition_to_next_stage(
  issue_id,
  "development",
  :approved
)
IO.inspect(next3)

# 产物确认 -> 完成
:completed = SymphonyElixir.Lifecycle.StageStateMachine.transition_to_next_stage(
  issue_id,
  "artifact_confirmation",
  :approved
)
IO.inspect(:completed)
```

**预期输出**:
```
{:ok, "design_document"}
{:ok, "development"}
{:ok, "artifact_confirmation"}
:completed
```

✅ **检查点**: 完整的阶段转换流程正常

---

### 步骤 9: 查看阶段历史

在 **IEx 控制台**中执行：

```elixir
# 获取阶段转换历史
history = SymphonyElixir.Lifecycle.StageStateMachine.get_stage_history("test-001")
IO.inspect(length(history))

# 查看历史记录
Enum.each(history, fn record ->
  IO.inspect("#{record.from_stage} -> #{record.to_stage}")
end)
```

**预期输出**:
```
4
"requirement_assessment -> design_document"
"design_document -> development"
"development -> artifact_confirmation"
```

✅ **检查点**: 历史记录功能正常

---

### 步骤 10: 测试阶段编排器

在 **IEx 控制台**中执行：

```elixir
# 创建测试 issue
test_issue = %{
  id: "test-002",
  identifier: "TEST-002",
  title: "测试需求",
  description: "这是一个测试需求",
  state: "待处理"
}

# 处理 issue
result = SymphonyElixir.Lifecycle.StageOrchestrator.process_issue(test_issue)
IO.inspect(result)
```

**预期输出**:
```
{:ok, :use_legacy_flow}
```

⚠️ **说明**: 这是正常的，因为我们在测试模式下没有实际的飞书连接。

---

## 🌐 第三部分: Web Dashboard 验证（可选）

### 步骤 11: 启动 Web 服务

**注意**: 此步骤需要完整的 Symphony 服务。

在 **终端 A** 中（先退出 IEx: `Ctrl+C`），然后执行：

```bash
./bin/symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails --port 4000 WORKFLOW_TEST.md
```

**预期输出**:
```
[info]  Application symphony_elixir started
[info]  Lifecycle Stage Orchestrator started
[info]  Listening on http://127.0.0.1:4000
```

---

### 步骤 12: 访问 Dashboard

在浏览器中打开：

```
http://127.0.0.1:4000/
```

**应该看到**: Symphony Dashboard 界面

---

### 步骤 13: 测试 API 端点

在 **终端 B** 中执行：

```bash
# 获取状态
curl http://127.0.0.1:4000/api/v1/state

# 或者用浏览器打开
open http://127.0.0.1:4000/api/v1/state
```

✅ **检查点**: API 正常响应

---

## ✅ 验证检查清单

使用此清单确保所有步骤都已完成：

### 环境准备
- [ ] Elixir 版本 ≥ 1.18
- [ ] 所有依赖已安装
- [ ] 项目编译成功

### 单元测试
- [ ] 7/7 测试通过
- [ ] 无失败用例

### 核心功能
- [ ] 生命周期配置加载成功
- [ ] 阶段状态机判断正确
- [ ] 确认点检查正常
- [ ] 阶段转换功能正常
- [ ] 历史记录功能正常

### 交互功能
- [ ] IEx 控制台测试通过
- [ ] 完整流程模拟成功

### Web 界面（可选）
- [ ] 服务启动成功
- [ ] Dashboard 可访问
- [ ] API 端点正常响应

---

## 🎯 快速命令参考

### 一键测试所有功能

```bash
# 运行所有测试
mix test test/lifecycle/ --no-start

# 启动 IEx 并验证
iex -S mix
```

然后在 IEx 中：

```elixir
# 快速验证
config = SymphonyElixir.Config.settings!().lifecycle
IO.inspect({enabled: config.enabled, stages: length(config.stages)})

# 测试阶段转换
SymphonyElixir.Lifecycle.StageStateMachine.transition_to_next_stage("test", "requirement_assessment", :approved)
```

---

## 📊 验证结果记录

| 步骤 | 验证项 | 结果 | 备注 |
|------|--------|------|------|
| 1 | Elixir 环境 | ✅ | 版本 1.18.4 |
| 2 | 依赖安装 | ✅ | 所有依赖正常 |
| 3 | 项目编译 | ✅ | 编译成功 |
| 4 | 单元测试 | ✅ | 7/7 通过 |
| 6 | 配置加载 | ✅ | lifecycle.enabled: true |
| 7 | 阶段判断 | ✅ | 正确识别阶段 |
| 8 | 确认点检查 | ✅ | 正确识别确认点 |
| 9 | 阶段转换 | ✅ | 完整流程正常 |
| 10 | 历史记录 | ✅ | 记录功能正常 |

---

## 🚀 下一步行动

验证完成后，你可以：

1. **配置飞书集成** - 替换为真实的飞书应用
2. **创建测试需求** - 在飞书中创建测试需求
3. **观察自动化流程** - 查看完整的生命周期执行
4. **自定义配置** - 根据实际需求调整阶段配置

---

## 💡 提示

- 所有验证命令都可以在 IEx 控制台中重复执行
- 如果遇到错误，检查前面步骤是否都已完成
- VERIFICATION_GUIDE.md 提供更详细的故障排查信息

---

**祝你使用愉快！** 🎉
