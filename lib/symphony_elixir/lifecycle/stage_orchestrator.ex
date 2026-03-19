defmodule SymphonyElixir.Lifecycle.StageOrchestrator do
  @moduledoc """
  阶段编排器 - 管理多阶段工作流的执行

  此模块负责：
  - 处理飞书多维表格中的 issues
  - 根据状态自动判断并执行对应的阶段 Agent
  - 管理阶段之间的流转
  - 处理人工确认逻辑
  """

  use GenServer
  require Logger

  alias SymphonyElixir.{
    Orchestrator,
    AgentRunner,
    PromptBuilder,
    Lifecycle.StageStateMachine,
    Config,
    FeishuAdapter
  }

  @doc """
  启动阶段编排器 GenServer
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Client API

  @doc """
  处理一个 issue，自动判断并执行对应阶段

  ## 参数
    - issue: 飞书 issue 结构体

  ## 返回
    - {:ok, :awaiting_confirmation, stage_name} - 需要人工确认
    - {:ok, :completed, stage_name} - 阶段完成
    - {:ok, :use_legacy_flow} - 生命周期未启用，使用传统流程
    - {:error, reason} - 错误原因
  """
  @spec process_issue(map()) :: {:ok, atom(), String.t() | atom()} | {:error, term()}
  def process_issue(issue) do
    # 直接调用业务逻辑，不通过 GenServer（避免超时和竞争问题）
    do_process_issue_direct(issue)
  end

  # 不通过 GenServer 的直接调用版本
  defp do_process_issue_direct(issue) do
    lifecycle_enabled = Config.settings!().lifecycle.enabled

    if not lifecycle_enabled do
      {:ok, :use_legacy_flow}
    else
      case determine_and_execute_stage(issue) do
        {:ok, :awaiting_confirmation, stage} ->
          {:ok, :awaiting_confirmation, stage}

        {:ok, :completed, stage} ->
          {:ok, :completed, stage}

        {:error, reason} ->
          Logger.error("Stage processing failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  手动确认阶段结果

  ## 参数
    - issue_id: 飞书记录 ID
    - stage_name: 阶段名称
    - decision: 决策 (:approved 或 :rejected)
    - comment: 可选的评论

  ## 返回
    - {:ok, :transitioned, next_stage} - 已转换到下一阶段
    - {:ok, :completed} - 所有阶段已完成
    - {:error, reason} - 错误原因
  """
  @spec confirm_stage(String.t(), String.t(), :approved | :rejected, String.t() | nil) ::
          {:ok, atom(), String.t() | atom()} | {:error, term()}
  def confirm_stage(issue_id, stage_name, decision, comment \\ nil) do
    # 直接调用业务逻辑，不通过 GenServer
    log_confirmation(issue_id, stage_name, decision, comment)

    confirmation_result =
      case decision do
        :approved -> :approved
        :rejected -> :rejected
        _ -> :approved
      end

    case StageStateMachine.transition_to_next_stage(issue_id, stage_name, confirmation_result) do
      {:ok, next_stage} ->
        Logger.info("Stage #{stage_name} confirmed, transitioning to #{next_stage}")
        {:ok, :transitioned, next_stage}

      :completed ->
        Logger.info("All stages completed for issue #{issue_id}")
        FeishuAdapter.update_issue_state(issue_id, "已完成")
        {:ok, :completed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # GenServer Callbacks

  def init(_opts) do
    # Don't cache lifecycle_enabled - always fetch fresh from Config
    # Start polling regardless of config - it will check lifecycle status each time
    schedule_poll()
    {:ok, %{}}
  end

  def handle_info(:poll_stages, state) do
    # Always fetch fresh config to handle workflow file changes
    lifecycle_enabled = Config.settings!().lifecycle.enabled

    if lifecycle_enabled do
      # 获取需要处理的 issues
      case SymphonyElixir.Tracker.fetch_candidate_issues() do
        {:ok, issues} ->
          Enum.each(issues, &process_issue_async/1)

        {:error, reason} ->
          Logger.error("Failed to fetch issues for stage processing: #{inspect(reason)}")
      end

      schedule_poll()
    end

    {:noreply, state}
  end

  def handle_call({:process_issue, issue}, _from, state) do
    # Deprecated: use process_issue/1 directly instead
    result = do_process_issue_direct(issue)
    {:reply, result, state}
  end

  def handle_call({:confirm_stage, issue_id, stage_name, decision, comment}, _from, state) do
    # Deprecated: use confirm_stage/4 directly instead
    result = handle_stage_confirmation(issue_id, stage_name, decision, comment)
    {:reply, result, state}
  end

  # Private Functions

  defp do_process_issue(issue, _state) do
    # Always fetch fresh config to handle workflow file changes
    lifecycle_enabled = Config.settings!().lifecycle.enabled

    if not lifecycle_enabled do
      # 生命周期未启用，使用传统流程
      {:ok, :use_legacy_flow}
    else
      case determine_and_execute_stage(issue) do
        {:ok, :awaiting_confirmation, stage} ->
          # 需要人工确认
          {:ok, :awaiting_confirmation, stage}

        {:ok, :completed, stage} ->
          # 阶段完成
          {:ok, :completed, stage}

        {:error, reason} ->
          Logger.error("Stage processing failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp determine_and_execute_stage(issue) do
    issue_state = Map.get(issue, :state)
    issue_identifier = Map.get(issue, :identifier)
    issue_id = Map.get(issue, :id)
    IO.puts("[StageOrchestrator] determine_and_execute_stage for #{issue_identifier}, state: #{issue_state}")

    case StageStateMachine.determine_stage(issue_state) do
      {:ok, stage} ->
        stage_name = Map.get(stage, "name") || Map.get(stage, :name)
        IO.puts("[StageOrchestrator] Stage determined: #{stage_name}")

        # 检查该阶段是否已在执行中（防止重复执行）
        stage_status = get_stage_status(issue_id, stage_name)
        if stage_status == "in_progress" do
          Logger.warning("Stage #{stage_name} is already in progress for issue #{issue_identifier}, skipping")
          IO.puts("[StageOrchestrator] Stage #{stage_name} already in progress, skipping")
          {:ok, :already_in_progress, stage_name}
        else
          execute_stage_agent(issue, stage)
        end

      {:error, :lifecycle_disabled} ->
        Logger.debug("Lifecycle disabled for issue state: #{issue_state}")
        {:ok, :use_legacy_flow}

      {:error, :no_matching_stage} ->
        Logger.warning("No matching stage for issue state: #{issue_state}")
        {:error, :no_matching_stage}

      {:error, reason} ->
        Logger.error("Error determining stage: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp execute_stage_agent(issue, stage) do
    stage_name = Map.get(stage, "name") || Map.get(stage, :name)
    target_states = Map.get(stage, "target_states", []) || Map.get(stage, :target_states, [])
    prompt_template = Map.get(stage, "prompt_template") || Map.get(stage, :prompt_template)
    max_turns = Map.get(stage, "max_turns", 20)

    issue_identifier = Map.get(issue, :identifier)
    issue_id = Map.get(issue, :id)
    IO.puts("[StageOrchestrator] Executing stage: #{stage_name} for issue: #{issue_identifier}")
    IO.puts("[StageOrchestrator] target_states: #{inspect(target_states)}")
    Logger.info("Executing stage: #{stage_name} for issue: #{issue_identifier}")

    # 更新阶段状态为进行中
    StageStateMachine.update_stage_status(issue_id, stage_name, "in_progress")

    # 更新飞书状态到目标状态（进行中）
    target_state = List.first(target_states)
    IO.puts("[StageOrchestrator] target_state: #{inspect(target_state)}")
    if target_state do
      Logger.info("Updating Feishu state for issue #{issue_id} to '#{target_state}'")
      IO.puts("[StageOrchestrator] Calling FeishuAdapter.update_issue_state for #{issue_id} to '#{target_state}'")
      case FeishuAdapter.update_issue_state(issue_id, target_state) do
        :ok ->
          Logger.info("Feishu state updated successfully to '#{target_state}'")
          IO.puts("[StageOrchestrator] Feishu state updated successfully")

        {:ok, _response} ->
          Logger.info("Feishu state updated successfully to '#{target_state}'")
          IO.puts("[StageOrchestrator] Feishu state updated successfully")

        {:error, reason} ->
          Logger.error("Failed to update Feishu state: #{inspect(reason)}")
          IO.puts("[StageOrchestrator] Failed to update Feishu state: #{inspect(reason)}")
      end
    else
      IO.puts("[StageOrchestrator] WARNING: target_state is nil!")
    end

    # 使用现有的 PromptBuilder 构建提示
    # TODO: 后续可以扩展为使用阶段特定的 Prompt 模板
    prompt = PromptBuilder.build_prompt(issue, [])

    # 执行 Agent
    opts = [
      max_turns: max_turns
    ]

    IO.puts("[StageOrchestrator] About to call AgentRunner.run for issue: #{issue_identifier}")
    Logger.info("Calling AgentRunner.run for issue: #{issue_identifier}")

    result = AgentRunner.run(issue, nil, opts)

    IO.puts("[StageOrchestrator] AgentRunner.run returned for #{issue_identifier}: #{inspect(result)}")

    case result do
      :ok ->
        # 检查是否需要确认
        case StageStateMachine.requires_confirmation?(stage_name) do
          true ->
            StageStateMachine.update_stage_status(Map.get(issue, :id), stage_name, "awaiting_confirmation")

            # 更新飞书状态到等待确认
            update_to_awaiting_confirmation(issue, stage)

            {:ok, :awaiting_confirmation, stage_name}

          false ->
            # 不需要确认，自动进入下一阶段
            case StageStateMachine.transition_to_next_stage(Map.get(issue, :id), stage_name, :approved) do
              {:ok, next_stage} ->
                Logger.info("Auto-transitioned from #{stage_name} to #{next_stage}")
                {:ok, :completed, stage_name}

              :completed ->
                Logger.info("All stages completed for issue: #{Map.get(issue, :identifier)}")
                {:ok, :completed, stage_name}

              {:error, reason} ->
                Logger.error("Stage transition failed: #{inspect(reason)}")
                {:error, reason}
            end
        end

      {:error, reason} ->
        Logger.error("Stage execution failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp update_to_awaiting_confirmation(issue, stage) do
    output_states = Map.get(stage, "output_states", []) || Map.get(stage, :output_states, [])

    awaiting_state =
      Enum.find(output_states, fn s ->
        String.contains?(s, "确认") or String.contains?(s, "confirmation")
      end) || List.first(output_states)

    if awaiting_state do
      FeishuAdapter.update_issue_state(Map.get(issue, :id), awaiting_state)
    end
  end

  defp handle_stage_confirmation(issue_id, stage_name, decision, comment) do
    # 记录确认结果
    log_confirmation(issue_id, stage_name, decision, comment)

    # 根据决策转换到下一阶段
    confirmation_result =
      case decision do
        :approved -> :approved
        :rejected -> :rejected
        _ -> :approved
      end

    case StageStateMachine.transition_to_next_stage(issue_id, stage_name, confirmation_result) do
      {:ok, next_stage} ->
        Logger.info("Stage #{stage_name} confirmed, transitioning to #{next_stage}")
        {:ok, :transitioned, next_stage}

      :completed ->
        Logger.info("All stages completed for issue #{issue_id}")
        # 更新到最终状态
        FeishuAdapter.update_issue_state(issue_id, "已完成")
        {:ok, :completed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_issue_async(issue) do
    Task.start(fn ->
      process_issue(issue)
    end)
  end

  defp schedule_poll do
    # 每 30 秒检查一次
    Process.send_after(self(), :poll_stages, 30_000)
  end

  defp log_confirmation(issue_id, stage_name, decision, comment) do
    Logger.info("""
    Stage Confirmation:
    Issue ID: #{issue_id}
    Stage: #{stage_name}
    Decision: #{decision}
    Comment: #{comment || "N/A"}
    """)
  end

  defp get_stage_status(issue_id, stage_name) do
    StageStateMachine.get_stage_status(issue_id, stage_name)
  end
end
