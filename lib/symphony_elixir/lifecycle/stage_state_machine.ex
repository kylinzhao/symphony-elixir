defmodule SymphonyElixir.Lifecycle.StageStateMachine do
  @moduledoc """
  阶段状态机 - 管理多阶段工作流的状态转换

  此模块负责：
  - 根据飞书状态确定当前应该执行的阶段
  - 管理阶段之间的状态转换
  - 检查阶段是否需要人工确认
  - 记录阶段转换历史
  """

  use GenServer
  require Logger

  alias SymphonyElixir.{Config, StateStore, FeishuAdapter}

  # 阶段状态常量
  @stage_status %{
    pending: "pending",
    in_progress: "in_progress",
    awaiting_confirmation: "awaiting_confirmation",
    confirmed: "confirmed",
    rejected: "rejected",
    completed: "completed"
  }

  @doc """
  启动阶段状态机 GenServer
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Client API

  @doc """
  根据飞书状态确定当前应该执行的阶段

  ## 参数
    - issue_state: 飞书多维表格中的状态值

  ## 返回
    - {:ok, stage_map} - 找到匹配的阶段
    - {:error, :no_matching_stage} - 没有找到匹配的阶段
    - {:error, :stage_not_found} - 阶段配置错误
    - {:error, :lifecycle_disabled} - 生命周期功能未启用
  """
  @spec determine_stage(String.t()) :: {:ok, map()} | {:error, atom()}
  def determine_stage(issue_state) when is_binary(issue_state) do
    GenServer.call(__MODULE__, {:determine_stage, issue_state})
  end

  @doc """
  转换到下一个阶段

  ## 参数
    - issue_id: 飞书记录 ID
    - current_stage: 当前阶段名称
    - confirmation_result: 确认结果 (:approved 或 :rejected)

  ## 返回
    - {:ok, next_stage_name} - 下一阶段的名称
    - :completed - 所有阶段已完成
    - {:error, reason} - 错误原因
  """
  @spec transition_to_next_stage(String.t(), String.t(), :approved | :rejected) ::
          {:ok, String.t()} | :completed | {:error, term()}
  def transition_to_next_stage(issue_id, current_stage, confirmation_result \\ :approved) do
    GenServer.call(__MODULE__, {:transition_to_next, issue_id, current_stage, confirmation_result})
  end

  @doc """
  更新阶段状态

  ## 参数
    - issue_id: 飞书记录 ID
    - stage_name: 阶段名称
    - status: 阶段状态

  ## 返回
    - :ok - 更新成功
  """
  @spec update_stage_status(String.t(), String.t(), String.t()) :: :ok
  def update_stage_status(issue_id, stage_name, status) do
    GenServer.call(__MODULE__, {:update_stage_status, issue_id, stage_name, status})
  end

  @doc """
  检查阶段是否需要人工确认

  ## 参数
    - stage_name: 阶段名称

  ## 返回
    - true - 需要确认
    - false - 不需要确认
  """
  @spec requires_confirmation?(String.t()) :: boolean()
  def requires_confirmation?(stage_name) do
    GenServer.call(__MODULE__, {:requires_confirmation, stage_name})
  end

  @doc """
  获取阶段历史记录

  ## 参数
    - issue_id: 飞书记录 ID

  ## 返回
    - 阶段转换历史列表
  """
  @spec get_stage_history(String.t()) :: [map()]
  def get_stage_history(issue_id) do
    GenServer.call(__MODULE__, {:get_stage_history, issue_id})
  end

  @doc """
  获取阶段状态

  ## 参数
    - issue_id: 飞书记录 ID
    - stage_name: 阶段名称

  ## 返回
    - 阶段状态字符串或 nil
  """
  @spec get_stage_status(String.t(), String.t()) :: String.t() | nil
  def get_stage_status(issue_id, stage_name) do
    GenServer.call(__MODULE__, {:get_stage_status, issue_id, stage_name})
  end

  # GenServer Callbacks

  def init(_opts) do
    # Don't cache lifecycle_config - always fetch fresh from Config
    {:ok, %{stage_states: %{}}}
  end

  def handle_call({:determine_stage, issue_state}, _from, state) do
    # Always fetch fresh config to handle workflow file changes
    lifecycle_config = Config.settings!().lifecycle
    Logger.info("[StageStateMachine] determine_stage called for issue_state: #{issue_state}, lifecycle_enabled: #{lifecycle_config.enabled}")

    if not lifecycle_config.enabled do
      {:reply, {:error, :lifecycle_disabled}, state}
    else
      case find_stage_for_state(issue_state, lifecycle_config) do
        {:ok, stage} ->
          stage_name = Map.get(stage, "name") || Map.get(stage, :name)

          # 检查该阶段是否已在执行中（防止重复执行）
          # 注意：这里无法检查 issue_id，因为 determine_stage 只接收 issue_state
          # 真正的并发保护在 StageOrchestrator.process_issue 中实现
          Logger.info("[StageStateMachine] determine_stage result: #{stage_name}")
          {:reply, {:ok, stage}, state}

        error ->
          Logger.info("[StageStateMachine] determine_stage result: #{inspect(error)}")
          {:reply, error, state}
      end
    end
  end

  def handle_call({:transition_to_next, issue_id, current_stage, confirmation_result}, _from, state) do
    # Always fetch fresh config to handle workflow file changes
    lifecycle_config = Config.settings!().lifecycle

    if not lifecycle_config.enabled do
      {:reply, {:error, :lifecycle_disabled}, state}
    else
      case find_next_stage(current_stage, confirmation_result, lifecycle_config) do
        {:ok, next_stage} ->
          # 更新飞书状态到下一阶段的初始状态
          update_feishu_state(issue_id, next_stage, lifecycle_config)

          # 记录阶段转换
          record_stage_transition(issue_id, current_stage, next_stage, confirmation_result)

          {:reply, {:ok, next_stage}, state}

        :completed ->
          {:reply, :completed, state}
      end
    end
  end

  def handle_call({:requires_confirmation, stage_name}, _from, state) do
    # Always fetch fresh config to handle workflow file changes
    lifecycle_config = Config.settings!().lifecycle
    requires = stage_name in (lifecycle_config.confirmation_points || [])
    {:reply, requires, state}
  end

  def handle_call({:update_stage_status, issue_id, stage_name, status}, _from, state) do
    stage_states = Map.put(state.stage_states, {issue_id, stage_name}, status)
    Logger.debug("Stage status updated: issue_id=#{issue_id}, stage=#{stage_name}, status=#{status}")
    {:reply, :ok, %{state | stage_states: stage_states}}
  end

  def handle_call({:get_stage_history, issue_id}, _from, state) do
    history = StateStore.get_stage_history(issue_id)
    {:reply, history, state}
  end

  def handle_call({:get_stage_status, issue_id, stage_name}, _from, state) do
    stage_status = Map.get(state.stage_states, {issue_id, stage_name})
    {:reply, stage_status, state}
  end

  # Private Functions

  defp find_stage_for_state(issue_state, lifecycle_config) do
    stage_transitions = lifecycle_config.stage_transitions || %{}

    case Map.get(stage_transitions, issue_state) do
      nil ->
        # 如果没有明确映射，查找包含此状态的阶段
        find_stage_by_initial_state(issue_state, lifecycle_config.stages)

      stage_name ->
        find_stage_by_name(stage_name, lifecycle_config.stages)
    end
  end

  defp find_stage_by_name(stage_name, stages) do
    Enum.find(stages, fn stage ->
      Map.get(stage, "name") == stage_name or
        Map.get(stage, :name) == stage_name
    end)
    |> case do
      nil -> {:error, :stage_not_found}
      stage -> {:ok, stage}
    end
  end

  defp find_stage_by_initial_state(issue_state, stages) do
    Enum.find(stages, fn stage ->
      initial_states = Map.get(stage, "initial_states", []) ++ Map.get(stage, :initial_states, [])
      issue_state in initial_states
    end)
    |> case do
      nil -> {:error, :no_matching_stage}
      stage -> {:ok, stage}
    end
  end

  defp find_next_stage(current_stage, :approved, lifecycle_config) do
    stages = lifecycle_config.stages

    current_index =
      Enum.find_index(stages, fn s ->
        Map.get(s, "name") == current_stage or Map.get(s, :name) == current_stage
      end)

    if current_index && current_index < length(stages) - 1 do
      next_stage = Enum.at(stages, current_index + 1)
      next_stage_name = Map.get(next_stage, "name") || Map.get(next_stage, :name)
      {:ok, next_stage_name}
    else
      :completed
    end
  end

  defp find_next_stage(current_stage, :rejected, _lifecycle_config) do
    # 拒绝后保持在当前阶段，等待重新提交
    {:ok, current_stage}
  end

  defp update_feishu_state(issue_id, next_stage, lifecycle_config) do
    # 找到下一阶段的 target_states
    stage = find_stage_by_name(next_stage, lifecycle_config.stages)

    with {:ok, stage_map} <- stage,
         target_states when is_list(target_states) <- Map.get(stage_map, "target_states", []),
         target_state when is_binary(target_state) <- List.first(target_states) do
      FeishuAdapter.update_issue_state(issue_id, target_state)
    else
      _ ->
        Logger.warning("Could not update Feishu state for stage: #{next_stage}")
    end
  end

  defp record_stage_transition(issue_id, from_stage, to_stage, confirmation_result) do
    transition = %{
      issue_id: issue_id,
      from_stage: from_stage,
      to_stage: to_stage,
      confirmation_result: confirmation_result,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    StateStore.record_stage_transition(transition)
    Logger.info("Stage transition recorded: #{from_stage} -> #{to_stage} for issue #{issue_id}")
  end
end
