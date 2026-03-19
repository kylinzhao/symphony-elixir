defmodule SymphonyElixir.StateStore do
  @moduledoc """
  状态持久化存储模块
  """
  require Logger
  use GenServer

  @table_name :symphony_state_store
  @stage_transitions_table :symphony_stage_transitions

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_global_tokens do
    case :ets.lookup(@table_name, :global_tokens) do
      [{:global_tokens, tokens}] -> tokens
      [] -> %{input_tokens: 0, output_tokens: 0, total_tokens: 0}
    end
  end

  def update_global_tokens(input_delta, output_delta, total_delta) do
    GenServer.cast(__MODULE__, {:update_global_tokens, input_delta, output_delta, total_delta})
  end

  def get_global_runtime do
    case :ets.lookup(@table_name, :global_runtime) do
      [{:global_runtime, seconds}] -> seconds
      [] -> 0
    end
  end

  def update_global_runtime(seconds_delta) do
    GenServer.cast(__MODULE__, {:update_global_runtime, seconds_delta})
  end

  def get_issue_stats(issue_id) when is_binary(issue_id) do
    case :ets.lookup(@table_name, {:issue_stats, issue_id}) do
      [{_, stats}] -> stats
      [] -> nil
    end
  end

  def upsert_issue_stats(issue_id, stats) when is_binary(issue_id) and is_map(stats) do
    GenServer.cast(__MODULE__, {:upsert_issue_stats, issue_id, stats})
  end

  def get_task_progress(issue_id) when is_binary(issue_id) do
    case :ets.lookup(@table_name, {:task_progress, issue_id}) do
      [{_, progress}] -> progress
      [] -> nil
    end
  end

  def update_task_progress(issue_id, progress) when is_binary(issue_id) and is_map(progress) do
    GenServer.cast(__MODULE__, {:update_task_progress, issue_id, progress})
  end

  def get_all_progress do
    :ets.tab2list(@table_name)
    |> Enum.filter(fn
      {{:task_progress, _issue_id}, _progress} -> true
      _ -> false
    end)
    |> Enum.map(fn
      {{:task_progress, issue_id}, progress} ->
        %{
          issue_id: issue_id,
          progress: Map.get(progress, :percentage, 0.0),
          current_task: Map.get(progress, :current_task),
          total_tasks: Map.get(progress, :total_tasks, 0),
          completed_tasks: Map.get(progress, :completed_tasks, 0)
        }
    end)
  end

  def init(_opts) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@stage_transitions_table, [:named_table, :duplicate_bag, :public, read_concurrency: true])
    :ets.insert(@table_name, {:global_tokens, %{input_tokens: 0, output_tokens: 0, total_tokens: 0}})
    :ets.insert(@table_name, {:global_runtime, 0})
    {:ok, %{}}
  end

  def handle_cast({:update_global_tokens, input_delta, output_delta, total_delta}, state) do
    current = get_global_tokens()
    updated = %{
      input_tokens: current.input_tokens + input_delta,
      output_tokens: current.output_tokens + output_delta,
      total_tokens: current.total_tokens + total_delta
    }
    :ets.insert(@table_name, {:global_tokens, updated})
    {:noreply, state}
  end

  def handle_cast({:update_global_runtime, seconds_delta}, state) do
    current = get_global_runtime()
    updated = current + seconds_delta
    :ets.insert(@table_name, {:global_runtime, updated})
    {:noreply, state}
  end

  def handle_cast({:upsert_issue_stats, issue_id, new_stats}, state) do
    current = get_issue_stats(issue_id) || %{}
    merged = Map.merge(current, new_stats)
    :ets.insert(@table_name, {{:issue_stats, issue_id}, merged})
    {:noreply, state}
  end

  def handle_cast({:update_task_progress, issue_id, progress}, state) do
    :ets.insert(@table_name, {{:task_progress, issue_id}, progress})
    {:noreply, state}
  end

  # 阶段转换记录功能

  @doc """
  记录阶段转换

  ## 参数
    - transition: 包含 issue_id, from_stage, to_stage, confirmation_result, timestamp 的 map

  ## 返回
    - :ok
  """
  @spec record_stage_transition(map()) :: :ok
  def record_stage_transition(transition) when is_map(transition) do
    GenServer.cast(__MODULE__, {:record_stage_transition, transition})
  end

  @doc """
  获取阶段转换历史

  ## 参数
    - issue_id: 飞书记录 ID

  ## 返回
    - 阶段转换历史列表，按时间排序
  """
  @spec get_stage_history(String.t()) :: [map()]
  def get_stage_history(issue_id) do
    :ets.tab2list(@stage_transitions_table)
    |> Enum.filter(fn [{_key, transition}] -> Map.get(transition, :issue_id) == issue_id end)
    |> Enum.map(fn [{_key, transition}] -> transition end)
    |> Enum.sort_by(fn transition -> Map.get(transition, :timestamp) end)
  end

  def handle_cast({:record_stage_transition, transition}, state) do
    issue_id = Map.get(transition, :issue_id)
    timestamp = Map.get(transition, :timestamp)
    key = {issue_id, timestamp}
    :ets.insert(@stage_transitions_table, [{key, transition}])
    {:noreply, state}
  end
end
