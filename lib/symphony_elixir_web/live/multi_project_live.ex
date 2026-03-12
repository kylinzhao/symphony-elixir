defmodule SymphonyElixirWeb.MultiProjectLive do
  @moduledoc """
  多项目概览 LiveView
  """

  use Phoenix.LiveView, layout: {SymphonyElixirWeb.Layouts, :app}
  import Phoenix.HTML

  alias SymphonyElixir.{MultiProject.ProjectRegistry, CICDManager}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:projects, load_projects())
      |> assign(:deployments, load_deployments())
      |> assign(:now, DateTime.utc_now())

    if connected?(socket) do
      :timer.send_interval(5000, self(), :refresh)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign(:projects, load_projects())
     |> assign(:deployments, load_deployments())
     |> assign(:now, DateTime.utc_now())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="multi-project-dashboard">
      <header class="dashboard-header">
        <h1 class="dashboard-title">Symphony 多项目看板</h1>
        <p class="dashboard-subtitle">实时监控所有项目的任务和部署状态</p>
      </header>

      <!-- 项目概览 -->
      <div class="projects-grid">
        <%= for project <- @projects do %>
          <.project_card project={project} />
        <% end %>
      </div>

      <!-- 部署状态面板 -->
      <div class="deployments-panel">
        <h2 class="panel-title">最近部署</h2>
        <.deployments_table deployments={@deployments} />
      </div>

      <!-- 全局统计 -->
      <div class="global-stats">
        <.stat_card title="总项目数" value={length(@projects)} icon="📁" />
        <.stat_card title="运行中任务" value={running_count(@projects)} icon="🚀" />
        <.stat_card title="今日部署" value={length(@deployments)} icon="🎉" />
        <.stat_card title="全局并发" value="10/10" icon="⚡" />
      </div>
    </section>
    """
  end

  # 组件函数

  defp project_card(assigns) do
    ~H"""
    <div class={"project-card project-card-#{@project.status}"}>
      <div class="project-header">
        <h3 class="project-name"><%= @project.name %></h3>
        <span class={"project-status project-status-#{@project.status}"}>
          <%= format_status(@project.status) %>
        </span>
      </div>

      <div class="project-stats">
        <div class="stat">
          <span class="stat-label">工作空间</span>
          <span class="stat-value"><%= @project.workspace_root %></span>
        </div>
        <div class="stat">
          <span class="stat-label">最大并发</span>
          <span class="stat-value"><%= @project.max_concurrent_agents %></span>
        </div>
        <div class="stat">
          <span class="stat-label">Tracker</span>
          <span class="stat-value"><%= format_tracker(@project.tracker_config) %></span>
        </div>
      </div>

      <div class="project-footer">
        <span class="project-updated">
          更新于: <%= format_time(@project.updated_at) %>
        </span>
      </div>
    </div>
    """
  end

  defp deployments_table(assigns) do
    ~H"""
    <table class="deployments-table">
      <thead>
        <tr>
          <th>时间</th>
          <th>环境</th>
          <th>状态</th>
          <th>平台</th>
        </tr>
      </thead>
      <tbody>
        <%= for deployment <- @deployments do %>
          <.deployment_row deployment={deployment} />
        <% end %>
      </tbody>
    </table>
    """
  end

  defp deployment_row(assigns) do
    ~H"""
    <tr class="deployment-row">
      <td class="deployment-time"><%= format_time(@deployment.timestamp) %></td>
      <td class="deployment-env"><%= @deployment.env %></td>
      <td class="deployment-status">
        <%= case @deployment.status do
          :success -> "<span class='badge badge-success'>✅ 成功</span>"
          :failure -> "<span class='badge badge-failure'>❌ 失败</span>"
          :pending -> "<span class='badge badge-pending'>⏳ 进行中</span>"
          status -> "<span class='badge badge-unknown'>#{status}</span>"
        end |> raw() %>
      </td>
      <td class="deployment-platform"><%= format_platform(@deployment.platform) %></td>
    </tr>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="stat-card">
      <div class="stat-icon"><%= @icon %></div>
      <div class="stat-info">
        <div class="stat-value"><%= @value %></div>
        <div class="stat-label"><%= @title %></div>
      </div>
    </div>
    """
  end

  # 数据加载函数

  defp load_projects do
    case ProjectRegistry.list_projects() do
      projects when is_list(projects) -> projects
      _ -> []
    end
  end

  defp load_deployments do
    # 从 CICDManager 获取最近的部署记录
    # 这里返回模拟数据,实际应该从数据库或日志中读取
    [
      %{
        timestamp: DateTime.utc_now() |> DateTime.add(-300, :second),
        env: :staging,
        status: :success,
        platform: :github_actions
      },
      %{
        timestamp: DateTime.utc_now() |> DateTime.add(-1800, :second),
        env: :production,
        status: :success,
        platform: :github_actions
      }
    ]
  end

  defp running_count(projects) do
    # 这里应该从 Orchestrator 获取实际的运行数
    # 简化处理,返回一个示例值
    Enum.count(projects) * 2
  end

  # 格式化函数

  defp format_status(:active), do: "活跃"
  defp format_status(:paused), do: "暂停"
  defp format_status(:archived), do: "已归档"
  defp format_status(_), do: "未知"

  defp format_tracker(%{"kind" => "feishu"}), do: "飞书"
  defp format_tracker(%{"kind" => "linear"}), do: "Linear"
  defp format_tracker(%{"kind" => "jira"}), do: "Jira"
  defp format_tracker(%{"kind" => "memory"}), do: "内存"
  defp format_tracker(_), do: "其他"

  defp format_platform(:github_actions), do: "GitHub Actions"
  defp format_platform(:gitlab_ci), do: "GitLab CI"
  defp format_platform(:jenkins), do: "Jenkins"
  defp format_platform(_), do: "其他"

  defp format_time(nil), do: "未知"
  defp format_time(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end
end
