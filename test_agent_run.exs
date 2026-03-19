# 测试 AgentRunner 是否能被正常调用
config = SymphonyElixir.Config.settings!().tracker

# 创建一个测试 issue
test_issue = %SymphonyElixir.Feishu.Issue{
  id: "test001",
  identifier: "test001",
  title: "测试 Agent",
  description: "测试 AgentRunner 是否正常工作",
  state: "需求评估中"
}

IO.puts("Testing AgentRunner.run with test issue...")
IO.puts("Issue: #{inspect(test_issue)}")

# 尝试运行 Agent
try do
  result = SymphonyElixir.AgentRunner.run(test_issue, nil, max_turns: 1)
  IO.puts("AgentRunner.run result: #{inspect(result)}")
rescue
  e ->
    IO.puts("Error running AgentRunner: #{inspect(e)}")
    IO.puts("Stacktrace: #{Exception.format_stacktrace()}")
end
