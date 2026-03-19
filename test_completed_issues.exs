# 测试已完成任务的获取
config = SymphonyElixir.Config.settings!().tracker

IO.puts("Fetching records from Feishu...")

case SymphonyElixir.FeishuClient.get_all_records(config.app_token, config.table_id) do
  {:ok, data} ->
    items = Map.get(data, "items", [])
    IO.puts("Got #{length(items)} total records")

    # 转换并过滤
    completed_issues =
      items
      |> Enum.map(fn record -> SymphonyElixir.Feishu.Issue.normalize(record) end)
      |> Enum.filter(fn issue -> Map.get(issue, :state) in ["已完成", "已关闭"] end)
      |> Enum.map(fn issue ->
        %{
          issue_id: Map.get(issue, :id),
          issue_identifier: Map.get(issue, :identifier),
          title: Map.get(issue, :title),
          state: Map.get(issue, :state)
        }
      end)

    IO.puts("\nCompleted issues (#{length(completed_issues)}):")
    Enum.each(completed_issues, fn issue ->
      IO.puts("  - [#{issue.issue_id}] #{issue.title} - #{issue.state}")
    end)

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
