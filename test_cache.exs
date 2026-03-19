# 检查 ETS 缓存中的字段映射
:ets.new(:feishu_field_cache, [:named_table, :public])

# 启动 Finches
Application.ensure_all_started(:finch)

# 导入模块
Code.require_file("lib/symphony_elixir/feishu/adapter.ex")

# 获取字段映射
app_token = "J6NBbj3uEa3wlOsNxedcQWO9nPc"
table_id = "tblJyNAWMLG1TanI"

IO.puts("Fetching field options for '状态' field...")

case SymphonyElixir.FeishuAdapter.fetch_and_cache_option_name_to_id_mapping(app_token, table_id, "状态") do
  {:ok, mapping} ->
    IO.puts("Success! Mapping:")
    IO.inspect(mapping, label: "NAME_TO_ID")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
