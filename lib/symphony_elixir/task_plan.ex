defmodule SymphonyElixir.TaskPlan do
  @moduledoc """
  任务计划管理和进度追踪模块

  解析 Codex 生成的 TASK_PLAN.json，追踪执行进度，
  并将进度同步到 StateStore 和飞书。
  """

  require Logger
  alias SymphonyElixir.{StateStore, Config}

  @task_plan_file "TASK_PLAN.json"

  @type task_status :: :pending | :in_progress | :completed | :failed
  @type task :: %{
    id: integer(),
    name: String.t(),
    status: String.t(),
    estimated_percentage: float(),
    started_at: String.t() | nil,
    completed_at: String.t() | nil
  }
  @type task_plan :: %{
    version: String.t(),
    total_tasks: integer(),
    tasks: [task()],
    created_at: String.t()
  }

  @doc """
  从工作空间读取任务计划
  """
  @spec read_plan(String.t()) :: {:ok, task_plan()} | {:error, term()}
  def read_plan(workspace_path) when is_binary(workspace_path) do
    plan_file = Path.join(workspace_path, @task_plan_file)

    case File.read(plan_file) do
      {:ok, content} ->
        try do
          plan = parse_plan_json(content)
          Logger.info("Task plan loaded: #{plan.total_tasks} tasks")
          {:ok, plan}
        rescue
          error ->
            Logger.error("Failed to parse task plan: #{inspect(error)}")
            {:error, :invalid_plan_format}
        end

      {:error, :enoent} ->
        {:error, :plan_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  计算任务完成百分比
  """
  @spec calculate_percentage(task_plan()) :: float()
  def calculate_percentage(%{tasks: tasks}) when is_list(tasks) do
    total = length(tasks)

    if total > 0 do
      completed =
        Enum.count(tasks, fn task ->
          Map.get(task, :status) == "completed"
        end)

      Float.round(completed / total * 100, 1)
    else
      0.0
    end
  end

  @doc """
  获取当前正在进行的任务
  """
  @spec get_current_task(task_plan()) :: task() | nil
  def get_current_task(%{tasks: tasks}) when is_list(tasks) do
    Enum.find(tasks, fn task ->
      Map.get(task, :status) == "in_progress"
    end)
  end

  @doc """
  获取任务进度摘要
  """
  @spec get_progress_summary(String.t()) :: {:ok, map()} | {:error, term()}
  def get_progress_summary(workspace_path) do
    with {:ok, plan} <- read_plan(workspace_path) do
      current_task = get_current_task(plan)
      percentage = calculate_percentage(plan)
      completed_count = Enum.count(plan.tasks, fn t -> Map.get(t, :status) == "completed" end)

      summary = %{
        total_tasks: plan.total_tasks,
        completed_tasks: completed_count,
        percentage: percentage,
        current_task: if(current_task, do: Map.get(current_task, :name), else: nil),
        status: cond do
          percentage == 100.0 -> :completed
          percentage > 0 -> :in_progress
          true -> :pending
        end,
        created_at: Map.get(plan, :created_at),
        tasks: plan.tasks
      }

      {:ok, summary}
    end
  end

  @doc """
  更新 StateStore 中的任务进度
  """
  @spec sync_progress_to_store(String.t(), String.t(), map()) :: :ok
  def sync_progress_to_store(issue_id, issue_identifier, summary) when is_binary(issue_id) do
    progress = %{
      issue_id: issue_id,
      issue_identifier: issue_identifier,
      total_tasks: Map.get(summary, :total_tasks, 0),
      completed_tasks: Map.get(summary, :completed_tasks, 0),
      percentage: Map.get(summary, :percentage, 0.0),
      current_task: Map.get(summary, :current_task),
      status: Map.get(summary, :status),
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    StateStore.update_task_progress(issue_id, progress)
    :ok
  end

  @doc """
  检查工作空间是否有任务计划文件
  """
  @spec has_plan?(String.t()) :: boolean()
  def has_plan?(workspace_path) do
    plan_file = Path.join(workspace_path, @task_plan_file)
    File.exists?(plan_file)
  end

  # Private Functions

  defp parse_plan_json(content) when is_binary(content) do
    data = Jason.decode!(content, keys: :atoms)

    # 确保必要字段存在
    %{
      version: Map.get(data, :version, "1.0"),
      total_tasks: Map.get(data, :total_tasks, length(Map.get(data, :tasks, []))),
      tasks: normalize_tasks(Map.get(data, :tasks, [])),
      created_at: Map.get(data, :created_at, DateTime.utc_now() |> DateTime.to_iso8601())
    }
  end

  defp normalize_tasks(tasks) when is_list(tasks) do
    Enum.map(tasks, fn task ->
      %{
        id: Map.get(task, :id, 0),
        name: Map.get(task, :name, "Unknown Task"),
        status: Map.get(task, :status, "pending"),
        estimated_percentage: Map.get(task, :estimated_percentage, 0.0),
        started_at: Map.get(task, :started_at),
        completed_at: Map.get(task, :completed_at)
      }
    end)
  end
end
