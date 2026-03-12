defmodule SymphonyElixir.MultiProject.Coordinator do
  @moduledoc """
  多项目协调器

  负责跨项目的任务调度和资源分配。
  """

  require Logger
  alias SymphonyElixir.{Config, MultiProject.ProjectRegistry}

  @doc """
  从所有活跃项目获取候选任务
  """
  def fetch_all_candidate_issues do
    projects = ProjectRegistry.get_active_projects()

    Logger.info("Fetching issues from #{length(projects)} active projects")

    issues =
      projects
      |> Enum.flat_map(fn project ->
        fetch_project_issues(project)
      end)
      |> sort_and_deduplicate()

    Logger.info("Found #{length(issues)} candidate issues across all projects")
    {:ok, issues}
  end

  @doc """
  获取全局并发限制
  """
  def global_max_concurrent_agents do
    Config.settings!().agent.max_concurrent_agents
  end

  @doc """
  计算可用并发槽位
  """
  def available_slots do
    running_count = get_running_count()
    max_count = global_max_concurrent_agents()
    max(max_count - running_count, 0)
  end

  @doc """
  检查是否有可用槽位
  """
  def has_available_slots? do
    available_slots() > 0
  end

  @doc """
  获取当前运行中的任务数
  """
  def get_running_count do
    # 从 Orchestrator 获取当前运行数
    # 这里简化处理,实际应该查询 Orchestrator 状态
    0
  end

  @doc """
  刷新项目配置
  """
  def reload_projects do
    case Config.settings() do
      {:ok, settings} ->
        case Map.get(settings, :projects) do
          nil ->
            Logger.warning("No projects configured")
            :ok

          projects when is_list(projects) ->
            Enum.each(projects, fn project_config ->
              ProjectRegistry.register_project(project_config)
            end)

            Logger.info("Reloaded #{length(projects)} projects")
            :ok
        end

      {:error, reason} ->
        Logger.error("Failed to reload projects: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private Functions

  defp fetch_project_issues(project) do
    Logger.debug("Fetching issues for project: #{project.name}")

    adapter = get_adapter_for_project(project)

    case adapter.fetch_candidate_issues(project.tracker_config) do
      {:ok, issues} ->
        # 为每个 issue 添加项目信息
        issues_with_project =
          Enum.map(issues, fn issue ->
            %{issue | project_id: project.id, project_name: project.name}
          end)

        Logger.debug("Found #{length(issues_with_project)} issues for #{project.name}")
        issues_with_project

      {:error, reason} ->
        Logger.error("Failed to fetch issues for #{project.name}: #{inspect(reason)}")
        []
    end
  end

  defp get_adapter_for_project(project) do
    case Map.get(project.tracker_config, :kind) do
      "feishu" -> SymphonyElixir.FeishuAdapter
      "memory" -> SymphonyElixir.Tracker.Memory
      _ -> SymphonyElixir.Linear.Adapter
    end
  end

  defp sort_and_deduplicate(issues) do
    issues
    |> Enum.sort_by(fn issue ->
      # 排序规则:
      # 1. 优先级 (数字越小越优先)
      # 2. 创建时间 (越早越优先)
      # 3. 项目名称 (字母序)
      {
        Map.get(issue, :priority, 99),
        Map.get(issue, :created_at, DateTime.utc_now()),
        Map.get(issue, :project_name, "")
      }
    end)
    |> Enum.uniq_by(fn issue -> Map.get(issue, :id) end)
  end
end
