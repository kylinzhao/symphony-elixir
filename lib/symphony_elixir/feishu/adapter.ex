defmodule SymphonyElixir.FeishuAdapter do
  @moduledoc """
  飞书多维表格 Tracker Adapter
  """

  @behaviour SymphonyElixir.Tracker

  require Logger
  alias SymphonyElixir.FeishuClient
  alias SymphonyElixir.Feishu.Issue

  @field_cache_name :feishu_field_cache
  @cache_ttl 3600  # 字段映射缓存 1 小时

  @impl true
  def fetch_candidate_issues do
    config = SymphonyElixir.Config.settings!().tracker
    fetch_candidate_issues(config)
  end

  @impl true
  def fetch_candidate_issues(config) do
    IO.puts("[DEBUG] Fetching candidate issues from Feishu")

    with {:ok, app_token} <- get_config(config, :app_token),
         {:ok, table_id} <- get_config(config, :table_id),
         {:ok, active_states} <- get_config(config, :active_states) do
      IO.puts("[DEBUG] Feishu config: app_token=#{app_token}, table_id=#{table_id}, active_states=#{inspect(active_states)}")

      # 获取选项 ID 到名称的映射
      case get_option_id_to_name_mapping(app_token, table_id, "状态") do
        {:ok, option_mapping} ->
          # 获取所有记录（不使用状态过滤）
          case FeishuClient.get_table_fields(app_token, table_id) do
            {:ok, _fields_data} ->
              # 获取所有记录
              all_records_url = "/bitable/v1/apps/#{app_token}/tables/#{table_id}/records"

              case FeishuClient.make_request(:get, all_records_url, %{}) do
                {:ok, data} ->
                  items = Map.get(data, "items", [])
                  IO.puts("[DEBUG] Feishu returned #{length(items)} total records")

                  # 转换选项 ID 为显示名称
                  converted_items = Enum.map(items, &convert_option_ids_to_names(&1, option_mapping))

                  issues =
                    converted_items
                    |> Enum.map(&Issue.normalize/1)
                    |> Enum.filter(&dispatch_eligible?/1)
                    |> Enum.filter(fn issue ->
                        # 过滤出 active_states 中的记录
                        Map.get(issue, :state) in active_states
                      end)

                  IO.puts("[DEBUG] After normalization and filtering: #{length(issues)} eligible issues")

                  if length(issues) > 0 do
                    Enum.each(issues, fn issue ->
                      IO.puts("[DEBUG] Eligible issue: id=#{inspect(issue.id)}, title=#{inspect(issue.title)}, state=#{inspect(issue.state)}")
                    end)
                  end

                  {:ok, issues}

                {:error, reason} ->
                  IO.puts("[ERROR] Failed to fetch records: #{inspect(reason)}")
                  {:error, reason}
              end

            {:error, reason} ->
              IO.puts("[ERROR] Failed to get table fields: #{inspect(reason)}")
              {:error, reason}
          end

        {:error, reason} ->
          IO.puts("[ERROR] Failed to get option mapping: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @impl true
  def fetch_issues_by_states(states) do
    config = SymphonyElixir.Config.settings!().tracker
    fetch_issues_by_states(states, config)
  end

  @impl true
  def fetch_issues_by_states(states, config) do
    with {:ok, app_token} <- get_config(config, :app_token),
         {:ok, table_id} <- get_config(config, :table_id),
         {:ok, data} <-
           FeishuClient.fetch_records_by_states(app_token, table_id, states) do
      # 获取选项 ID 到名称的映射并转换
      case get_option_id_to_name_mapping(app_token, table_id, "状态") do
        {:ok, option_mapping} ->
          items = Map.get(data, "items", [])
          converted_items = Enum.map(items, &convert_option_ids_to_names(&1, option_mapping))

          issues =
            converted_items
            |> Enum.map(&Issue.normalize/1)

          {:ok, issues}

        {:error, _reason} ->
          # Fallback: normalize without conversion
          issues =
            data
            |> Map.get("items", [])
            |> Enum.map(&Issue.normalize/1)

          {:ok, issues}
      end
    end
  end

  @impl true
  def fetch_issues_by_ids(ids, config) do
    IO.puts("[DEBUG] fetch_issues_by_ids: ids=#{inspect(ids)}")

    with {:ok, app_token} <- get_config(config, :app_token),
         {:ok, table_id} <- get_config(config, :table_id),
         {:ok, data} <- FeishuClient.fetch_records_by_ids(app_token, table_id, ids) do
      # batch_get API 返回 "records" 键而不是 "items"
      items = Map.get(data, "records", [])
      IO.puts("[DEBUG] fetch_issues_by_ids: Feishu returned #{length(items)} items")

      # 获取选项 ID 到名称的映射并转换
      case get_option_id_to_name_mapping(app_token, table_id, "状态") do
        {:ok, option_mapping} ->
          converted_items = Enum.map(items, &convert_option_ids_to_names(&1, option_mapping))

          issues =
            converted_items
            |> Enum.map(&Issue.normalize/1)

          {:ok, issues}

        {:error, reason} ->
          IO.puts("[ERROR] Failed to get option mapping for fetch_issues_by_ids: #{inspect(reason)}")
          # Fallback: normalize without conversion
          issues =
            items
            |> Enum.map(&Issue.normalize/1)

          {:ok, issues}
      end
    else
      {:error, reason} ->
        IO.puts("[DEBUG] fetch_issues_by_ids: error=#{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def fetch_issue_states_by_ids(issue_ids) do
    config = SymphonyElixir.Config.settings!().tracker
    fetch_issue_states_by_ids(issue_ids, config)
  end

  @impl true
  def fetch_issue_states_by_ids(issue_ids, config) do
    fetch_issues_by_ids(issue_ids, config)
  end

  @impl true
  def create_comment(issue_id, _body) do
    # 飞书多维表格的评论功能需要通过不同的 API 实现
    # 这里先返回 :ok,后续可以通过飞书机器人或 webhook 实现
    Logger.warning("Feishu create_comment not implemented yet for issue: #{issue_id}")
    :ok
  end

  @impl true
  def update_issue_state(issue_id, state_name) do
    config = SymphonyElixir.Config.settings!().tracker

    case {Map.get(config, :app_token), Map.get(config, :table_id)} do
      {nil, _} ->
        {:error, :missing_app_token}

      {_, nil} ->
        {:error, :missing_table_id}

      {app_token, table_id} ->
        Logger.info("FeishuAdapter: Updating issue #{issue_id} state to '#{state_name}'")
        IO.puts("[FeishuAdapter] Updating issue #{issue_id} state to '#{state_name}'")

        # SingleSelect 字段：直接使用选项名称（而不是选项 ID）
        # 参考 "优先级" 字段的存储方式，它存储的是名称 'P1' 而不是 ID
        FeishuClient.update_record(app_token, table_id, issue_id, %{
          "状态" => state_name
        })
    end
  end

  @doc """
  更新任务进度到飞书

  支持更新进度字段，字段名可以是 "进度" 或 "progress"
  当进度达到 100% 时，自动将状态更新为 "finished"
  """
  @spec update_issue_progress(String.t(), float(), String.t() | nil) :: :ok | {:error, term()}
  def update_issue_progress(issue_id, percentage, current_task \\ nil)
      when is_binary(issue_id) and is_number(percentage) do
    config = SymphonyElixir.Config.settings!().tracker

    case {Map.get(config, :app_token), Map.get(config, :table_id)} do
      {nil, _} ->
        {:error, :missing_app_token}

      {_, nil} ->
        {:error, :missing_table_id}

      {app_token, table_id} ->
        # 构建更新字段映射（直接使用字段名）
        raw_fields =
          %{
            "进度" => "#{Float.round(percentage, 1)}%"
          }
          |> maybe_add_current_task(current_task)

        # 如果需要标记为完成，获取"已完成"的选项 ID
        fields =
          if percentage >= 100.0 do
            case get_select_option_id(app_token, table_id, "状态", "已完成") do
              {:ok, _field_id, option_id} ->
                Map.put(raw_fields, "状态", option_id)
              {:error, _} ->
                raw_fields
            end
          else
            raw_fields
          end

        case FeishuClient.update_record(app_token, table_id, issue_id, fields) do
          {:ok, _response} ->
            if percentage >= 100.0 do
              Logger.info("Task completed: issue_id=#{issue_id}, marked as finished")
            else
              Logger.info("Updated Feishu progress: issue_id=#{issue_id}, progress=#{percentage}%")
            end
            :ok

          {:error, reason} ->
            Logger.warning("Failed to update Feishu progress: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  # 私有辅助函数

  defp get_config(config, key) do
    case Map.get(config, key) do
      nil -> {:error, {:missing_config, "Feishu adapter requires :#{key}"}}
      value -> {:ok, value}
    end
  end

  defp maybe_add_current_task(fields, nil), do: fields
  defp maybe_add_current_task(fields, current_task) when is_binary(current_task) do
    Map.put(fields, "当前任务", current_task)
  end

  defp maybe_mark_as_finished(fields, percentage) when percentage >= 100.0 do
    # 注意：这里仍然使用字段名，后续在 update_record 时会转换为 field_id
    Map.put(fields, "状态", "finished")
  end
  defp maybe_mark_as_finished(fields, _percentage), do: fields

  defp dispatch_eligible?(%SymphonyElixir.Feishu.Issue{state: state}) when is_binary(state) do
    # 简单的检查:有状态就可以调度
    not is_nil(state) and state != ""
  end

  defp dispatch_eligible?(_), do: false

  # 获取字段 ID 映射（带缓存）
  defp get_field_id(app_token, table_id, field_name) do
    cache_key = {app_token, table_id}

    case cached_field_mapping(cache_key) do
      {:ok, mapping} ->
        case Map.get(mapping, field_name) do
          nil ->
            Logger.warning("Field '#{field_name}' not found in table fields")
            {:error, :field_not_found}
          field_id ->
            {:ok, field_id}
        end

      :error ->
        # 缓存未命中，获取字段映射
        fetch_and_cache_field_mapping(cache_key, app_token, table_id, field_name)
    end
  end

  defp cached_field_mapping(cache_key) do
    try do
      case :ets.lookup(@field_cache_name, cache_key) do
        [{^cache_key, mapping, expire_at}] ->
          if System.system_time(:second) < expire_at do
            {:ok, mapping}
          else
            # 缓存过期
            :ets.delete(@field_cache_name, cache_key)
            :error
          end

        [] ->
          :error
      end
    rescue
      ArgumentError -> :error
    end
  end

  defp fetch_and_cache_field_mapping(cache_key, app_token, table_id, field_name) do
    Logger.info("Fetching field mapping for table #{table_id}")
    IO.puts("[FeishuAdapter] Fetching field mapping for table #{table_id}...")

    case FeishuClient.get_table_fields(app_token, table_id) do
      {:ok, data} ->
        fields = Map.get(data, "items", [])

        # 构建字段名 -> field_id 映射
        mapping =
          Enum.reduce(fields, %{}, fn field, acc ->
            field_id = Map.get(field, "field_id")
            field_name = Map.get(field, "field_name")

            if field_id && field_name do
              Map.put(acc, field_name, field_id)
            else
              acc
            end
          end)

        IO.puts("[FeishuAdapter] Field mapping: #{inspect(mapping)}")

        # 缓存映射
        cache_field_mapping(cache_key, mapping)

        case Map.get(mapping, field_name) do
          nil ->
            Logger.warning("Field '#{field_name}' not found in table. Available fields: #{inspect(Map.keys(mapping))}")
            {:error, :field_not_found}

          field_id ->
            {:ok, field_id}
        end

      {:error, reason} ->
        Logger.error("Failed to fetch table fields: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # 获取 SingleSelect 字段的选项 ID
  defp get_select_option_id(app_token, table_id, field_name, option_name) do
    cache_key = {app_token, table_id}

    case cached_field_mapping(cache_key) do
      {:ok, mapping} ->
        case Map.get(mapping, field_name) do
          nil ->
            Logger.warning("Field '#{field_name}' not found in table fields")
            {:error, :field_not_found}

          field_id ->
            # 检查是否有选项映射
            options_key = {:options_name_to_id, field_id}
            case cached_field_mapping(options_key) do
              {:ok, options_mapping} ->
                case Map.get(options_mapping, option_name) do
                  nil ->
                    Logger.warning("Option '#{option_name}' not found for field '#{field_name}'")
                    {:error, :option_not_found}

                  option_id ->
                    {:ok, field_id, option_id}
                end

              :error ->
                # 缓存未命中，获取选项映射
                fetch_and_cache_option_name_to_id_mapping(options_key, app_token, table_id, field_name, option_name, field_id)
            end
        end

      :error ->
        # 字段映射未缓存，先获取字段映射
        case fetch_and_cache_field_mapping(cache_key, app_token, table_id, field_name) do
          {:ok, field_id} ->
            # 现在获取选项映射
            options_key = {:options_name_to_id, field_id}
            fetch_and_cache_option_name_to_id_mapping(options_key, app_token, table_id, field_name, option_name, field_id)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp fetch_and_cache_option_mapping(options_key, app_token, table_id, field_name, option_name, field_id) do
    Logger.info("Fetching options for field '#{field_name}'")
    IO.puts("[FeishuAdapter] Fetching options for field '#{field_name}'...")

    case FeishuClient.get_table_fields(app_token, table_id) do
      {:ok, data} ->
        fields = Map.get(data, "items", [])

        # 查找指定字段
        case Enum.find(fields, fn f -> Map.get(f, "field_id") == field_id end) do
          nil ->
            Logger.error("Field '#{field_name}' (id=#{field_id}) not found in fields response")
            {:error, :field_not_found}

          field ->
            # 构建选项名 -> 选项 ID 映射
            options = Map.get(field, "property", %{}) |> Map.get("options", [])

            options_mapping =
              Enum.reduce(options, %{}, fn option, acc ->
                option_id = Map.get(option, "id")
                option_name = Map.get(option, "name")

                if option_id && option_name do
                  Map.put(acc, option_name, option_id)
                else
                  acc
                end
              end)

            IO.puts("[FeishuAdapter] Options for '#{field_name}': #{inspect(Map.keys(options_mapping))}")

            # 缓存选项映射
            cache_field_mapping(options_key, options_mapping)

            case Map.get(options_mapping, option_name) do
              nil ->
                Logger.warning("Option '#{option_name}' not found. Available: #{inspect(Map.keys(options_mapping))}")
                {:error, :option_not_found}

              option_id ->
                {:ok, field_id, option_id}
            end
        end

      {:error, reason} ->
        Logger.error("Failed to fetch field options: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp cache_field_mapping(cache_key, mapping) do
    try do
      :ets.new(@field_cache_name, [:named_table, :public])
    rescue
      ArgumentError ->
        # 表已存在
        :ok
    end

    expire_at = System.system_time(:second) + @cache_ttl
    :ets.insert(@field_cache_name, {cache_key, mapping, expire_at})
    :ok
  end

  # 获取选项 ID 到名称的映射（反向映射）
  def get_option_id_to_name_mapping(app_token, table_id, field_name) do
    cache_key = {app_token, table_id}
    IO.puts("[DEBUG] get_option_id_to_name_mapping: field=#{field_name}")

    case cached_field_mapping(cache_key) do
      {:ok, _mapping} ->
        # 获取字段 ID
        case get_field_id(app_token, table_id, field_name) do
          {:ok, field_id} ->
            options_key = {:options, field_id}
            IO.puts("[DEBUG] get_option_id_to_name_mapping: field_id=#{field_id}, options_key=#{inspect(options_key)}")

            case cached_field_mapping(options_key) do
              {:ok, id_to_name_mapping} ->
                # Cached id_to_name_mapping (already in correct format)
                IO.puts("[DEBUG] get_option_id_to_name_mapping: CACHE HIT for id_to_name_mapping")
                {:ok, id_to_name_mapping}

              :error ->
                IO.puts("[DEBUG] get_option_id_to_name_mapping: CACHE MISS, fetching...")
                fetch_and_cache_option_id_to_name_mapping(options_key, app_token, table_id, field_name, field_id)
            end

          {:error, reason} ->
            IO.puts("[DEBUG] get_option_id_to_name_mapping: get_field_id error=#{inspect(reason)}")
            {:error, reason}
        end

      :error ->
        # 先获取字段映射
        IO.puts("[DEBUG] get_option_id_to_name_mapping: field_mapping CACHE MISS, fetching...")
        case fetch_and_cache_field_mapping(cache_key, app_token, table_id, field_name) do
          {:ok, field_id} ->
            options_key = {:options, field_id}
            fetch_and_cache_option_id_to_name_mapping(options_key, app_token, table_id, field_name, field_id)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def fetch_and_cache_option_id_to_name_mapping(options_key, app_token, table_id, field_name, field_id) do
    IO.puts("[DEBUG] fetch_and_cache_option_id_to_name_mapping: field=#{field_name}, field_id=#{field_id}")
    case FeishuClient.get_table_fields(app_token, table_id) do
      {:ok, data} ->
        fields = Map.get(data, "items", [])

        case Enum.find(fields, fn f -> Map.get(f, "field_id") == field_id end) do
          nil ->
            IO.puts("[ERROR] Field #{field_id} not found in fields response")
            {:error, :field_not_found}

          field ->
            options = Map.get(field, "property", %{}) |> Map.get("options", [])
            IO.puts("[DEBUG] Options for #{field_name}: #{inspect(Enum.map(options, fn o -> {Map.get(o, "name"), Map.get(o, "id")} end))}")

            # 构建 id -> name 映射，过滤掉无效的选项（name 不应该是 option ID）
            id_to_name_mapping =
              Enum.reduce(options, %{}, fn option, acc ->
                option_id = Map.get(option, "id")
                option_name = Map.get(option, "name")

                # 检查 option_id 和 option_name 都存在，且 option_name 不是 option ID 格式
                valid? = option_id && option_name &&
                          !String.starts_with?(option_name, "opt") &&
                          option_name != ""

                if valid? do
                  Map.put(acc, option_id, option_name)
                else
                  acc
                end
              end)

            IO.puts("[DEBUG] id_to_name_mapping: #{inspect(id_to_name_mapping)}")
            cache_field_mapping(options_key, id_to_name_mapping)
            {:ok, id_to_name_mapping}
        end

      {:error, reason} ->
        IO.puts("[ERROR] Failed to fetch table fields: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_and_cache_option_name_to_id_mapping(options_key, app_token, table_id, field_name, option_name, field_id) do
    IO.puts("[DEBUG] fetch_and_cache_option_name_to_id_mapping: field=#{field_name}, option_name=#{option_name}, field_id=#{field_id}")
    case FeishuClient.get_table_fields(app_token, table_id) do
      {:ok, data} ->
        fields = Map.get(data, "items", [])

        case Enum.find(fields, fn f -> Map.get(f, "field_id") == field_id end) do
          nil ->
            IO.puts("[ERROR] Field #{field_id} not found in fields response")
            {:error, :field_not_found}

          field ->
            options = Map.get(field, "property", %{}) |> Map.get("options", [])

            # 构建 name -> id 映射，过滤掉错误选项（name 不应该是 option ID 格式）
            name_to_id_mapping =
              Enum.reduce(options, %{}, fn option, acc ->
                option_id = Map.get(option, "id")
                option_name = Map.get(option, "name")

                # 检查选项数据有效性
                valid_id? = option_id && is_binary(option_id) && String.starts_with?(option_id, "opt")
                valid_name? = option_name && is_binary(option_name) && !String.starts_with?(option_name, "opt")

                if valid_id? && valid_name? do
                  Map.put(acc, option_name, option_id)
                else
                  acc
                end
              end)

            IO.puts("[DEBUG] name_to_id_mapping: #{inspect(name_to_id_mapping)}")
            cache_field_mapping(options_key, name_to_id_mapping)

            case Map.get(name_to_id_mapping, option_name) do
              nil ->
                Logger.warning("Option '#{option_name}' not found. Available: #{inspect(Map.keys(name_to_id_mapping))}")
                {:error, :option_not_found}

              option_id ->
                {:ok, field_id, option_id}
            end
        end

      {:error, reason} ->
        IO.puts("[ERROR] Failed to fetch table fields: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # 将记录中的选项 ID 转换为显示名称
  def convert_option_ids_to_names(record, option_mapping) do
    fields = Map.get(record, "fields", {})

    # 转换"状态"字段
    converted_fields =
      case Map.get(fields, "状态") do
        nil -> fields
        option_id when is_binary(option_id) ->
          IO.puts("[DEBUG] Converting state option_id=#{option_id} using mapping")
          case Map.get(option_mapping, option_id) do
            nil ->
              IO.puts("[DEBUG] No mapping found for option_id=#{option_id}")
              fields
            display_name ->
              IO.puts("[DEBUG] Converted to state=#{display_name}")
              Map.put(fields, "状态", display_name)
          end
        _ -> fields
      end

    Map.put(record, "fields", converted_fields)
  end
end
