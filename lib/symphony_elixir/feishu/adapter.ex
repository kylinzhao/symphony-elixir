defmodule SymphonyElixir.FeishuAdapter do
  @moduledoc """
  飞书多维表格 Tracker Adapter
  """

  @behaviour SymphonyElixir.Tracker

  require Logger
  alias SymphonyElixir.FeishuClient
  alias SymphonyElixir.Feishu.Issue

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

      case FeishuClient.fetch_records_by_states(app_token, table_id, active_states) do
        {:ok, data} ->
          items = Map.get(data, "items", [])
          IO.puts("[DEBUG] Feishu returned #{length(items)} records")
          IO.puts("[DEBUG] Raw data: #{inspect(data)}")

          issues =
            items
            |> Enum.map(&Issue.normalize/1)
            |> Enum.filter(&dispatch_eligible?/1)

          IO.puts("[DEBUG] After normalization and filtering: #{length(issues)} eligible issues")

          if length(issues) > 0 do
            Enum.each(issues, fn issue ->
              IO.puts("[DEBUG] Eligible issue: id=#{inspect(issue.id)}, title=#{inspect(issue.title)}, state=#{inspect(issue.state)}")
            end)
          end

          {:ok, issues}

        {:error, reason} ->
          IO.puts("[ERROR] Failed to fetch from Feishu: #{inspect(reason)}")
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
      issues =
        data
        |> Map.get("items", [])
        |> Enum.map(&Issue.normalize/1)

      {:ok, issues}
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
      IO.puts("[DEBUG] fetch_issues_by_ids: data keys=#{inspect(Map.keys(data))}")

      issues =
        items
        |> Enum.map(&Issue.normalize/1)

      {:ok, issues}
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
        # 更新飞书记录的状态字段
        FeishuClient.update_record(app_token, table_id, issue_id, %{
          "status" => state_name
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
        # 构建更新字段
        fields =
          %{
            "进度" => "#{Float.round(percentage, 1)}%"
          }
          |> maybe_add_current_task(current_task)
          |> maybe_mark_as_finished(percentage)

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
    Map.put(fields, "状态", "finished")
  end
  defp maybe_mark_as_finished(fields, _percentage), do: fields

  defp dispatch_eligible?(%SymphonyElixir.Feishu.Issue{state: state}) when is_binary(state) do
    # 简单的检查:有状态就可以调度
    not is_nil(state) and state != ""
  end

  defp dispatch_eligible?(_), do: false
end
