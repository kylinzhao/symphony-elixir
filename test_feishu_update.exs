# Test Feishu status update
# This will run as a separate elixir process

Code.require_file("lib/symphony_elixir/feishu/adapter.ex")

# Test updating issue state
issue_id = "recajevnCU"  # "实现网页版五子棋"
new_state = "需求评估中"

result = SymphonyElixir.FeishuAdapter.update_issue_state(issue_id, new_state)
IO.puts("Update result: #{inspect(result)}")
