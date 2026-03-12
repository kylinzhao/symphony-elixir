defmodule SymphonyElixir.ProgressMonitor do
  @moduledoc """
  任务进度监控服务

  定期检查所有运行中任务的工作空间，读取 TASK_PLAN.json，
  计算进度百分比，并更新到 StateStore 和飞书。
  """

  use GenServer
  require Logger

  alias SymphonyElixir.{TaskPlan, StateStore, FeishuAdapter, Config}

  @check_interval_ms 30_000  # 每 30 秒检查一次进度

  # Client API

  @doc """
  启动进度监控服务
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  手动触发进度检查
  """
  @spec check_all_progress() :: :ok
  def check_all_progress do
    GenServer.cast(__MODULE__, :check_all_progress)
  end

  @doc """
  检查特定 issue 的进度
  """
  @spec check_issue_progress(String.t(), String.t(), String.t()) :: :ok
  def check_issue_progress(issue_id, issue_identifier, workspace_path) do
    GenServer.cast(__MODULE__, {:check_issue_progress, issue_id, issue_identifier, workspace_path})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("ProgressMonitor started")

    # 启动后立即检查一次
    send(self(), :check_all_progress)

    # 定期检查
    schedule_check()

    {:ok, %{}}
  end

  @impl true
  def handle_cast(:check_all_progress, state) do
    do_check_all_progress()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:check_issue_progress, issue_id, issue_identifier, workspace_path}, state) do
    check_and_update_progress(issue_id, issue_identifier, workspace_path)
    {:noreply, state}
  end

  @impl true
  def handle_info(:check_all_progress, state) do
    do_check_all_progress()
    schedule_check()
    {:noreply, state}
  end

  # Private Functions

  defp do_check_all_progress do
    # 从 StateStore 获取所有有进度记录的 issue
    all_progress = StateStore.get_all_progress()

    Logger.debug("ProgressMonitor: checking #{length(all_progress)} issues")

    Enum.each(all_progress, fn progress ->
      issue_id = Map.get(progress, :issue_id)
      issue_identifier = Map.get(progress, :issue_identifier)

      # 构建工作空间路径
      workspace_root = Config.settings!().workspace.root
      workspace_path = Path.join(workspace_root, issue_identifier)

      check_and_update_progress(issue_id, issue_identifier, workspace_path)
    end)
  end

  defp check_and_update_progress(issue_id, issue_identifier, workspace_path) do
    case TaskPlan.get_progress_summary(workspace_path) do
      {:ok, summary} ->
        percentage = Map.get(summary, :percentage, 0.0)
        current_task = Map.get(summary, :current_task)
        status = Map.get(summary, :status)

        Logger.info("Progress: #{issue_identifier} - #{percentage}% (#{current_task || "无活动任务"})")

        # 更新 StateStore
        TaskPlan.sync_progress_to_store(issue_id, issue_identifier, summary)

        # 同步到飞书（如果进度有变化）
        sync_progress_to_feishu(issue_id, percentage, current_task, status)

      {:error, :plan_not_found} ->
        # 没有任务计划文件，跳过
        Logger.debug("No task plan found for #{issue_identifier}")

      {:error, reason} ->
        Logger.error("Failed to check progress for #{issue_identifier}: #{inspect(reason)}")
    end
  end

  defp sync_progress_to_feishu(issue_id, percentage, current_task, _status) do
    # 只有当进度有实际变化时才更新飞书
    # 这里可以添加更智能的逻辑，比如只更新超过一定阈值的变化

    case FeishuAdapter.update_issue_progress(issue_id, percentage, current_task) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to sync progress to Feishu: #{inspect(reason)}")
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check_all_progress, @check_interval_ms)
  end
end
