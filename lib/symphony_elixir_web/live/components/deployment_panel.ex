defmodule SymphonyElixirWeb.DeploymentPanel do
  @moduledoc """
  部署状态面板组件
  """

  use Phoenix.LiveComponent
  import Phoenix.HTML
  alias SymphonyElixir.CICDManager

  @impl true
  def render(assigns) do
    ~H"""
    <div class="deployment-panel">
      <div class="panel-header">
        <h2 class="panel-title">🚀 部署状态</h2>
        <button class="refresh-button" phx-click="refresh_deployments">
          🔄 刷新
        </button>
      </div>

      <!-- 环境部署卡片 -->
      <div class="environment-cards">
        <.environment_card
          name="Staging"
          status={@staging_status}
          last_deploy={@staging_last_deploy}
          url="https://staging.example.com"
        />

        <.environment_card
          name="Production"
          status={@production_status}
          last_deploy={@production_last_deploy}
          url="https://example.com"
        />
      </div>

      <!-- 部署历史 -->
      <div class="deployment-history">
        <h3 class="history-title">最近部署</h3>
        <.deployment_history_list deployments={@deployments} />
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("refresh_deployments", _params, socket) do
    deployments = load_recent_deployments()
    {:noreply, assign(socket, :deployments, deployments)}
  end

  # 子组件

  defp environment_card(assigns) do
    ~H"""
    <div class={"environment-card env-#{@name |> String.downcase()}"}>
      <div class="env-header">
        <h3 class="env-name"><%= @name %></h3>
        <%= case @status do
          :success -> "<span class='env-badge env-badge-success'>✅ 运行中</span>"
          :pending -> "<span class='env-badge env-badge-pending'>⏳ 部署中</span>"
          :failure -> "<span class='env-badge env-badge-failure'>❌ 失败</span>"
          _ -> "<span class='env-badge env-badge-unknown'>❓ 未知</span>"
        end |> raw() %>
      </div>

      <div class="env-info">
        <div class="env-info-row">
          <span class="label">最后部署:</span>
          <span class="value"><%= format_deploy_time(@last_deploy) %></span>
        </div>
        <div class="env-info-row">
          <span class="label">访问地址:</span>
          <a class="value link" href={@url} target="_blank">
            <%= @url %>
          </a>
        </div>
      </div>

      <div class="env-actions">
        <button class="deploy-button" phx-click="deploy_to_env" phx-value-env={@name}>
          部署到 <%= @name %>
        </button>
      </div>
    </div>
    """
  end

  defp deployment_history_list(assigns) do
    ~H"""
    <div class="history-list">
      <%= for deployment <- @deployments do %>
        <.deployment_history_item deployment={deployment} />
      <% end %>
    </div>
    """
  end

  defp deployment_history_item(assigns) do
    ~H"""
    <div class="history-item">
      <div class="history-item-header">
        <span class="history-env"><%= @deployment.env %></span>
        <%= case @deployment.status do
          :success -> "<span class='status-icon'>✅</span>"
          :failure -> "<span class='status-icon'>❌</span>"
          :pending -> "<span class='status-icon'>⏳</span>"
          _ -> "<span class='status-icon'>❓</span>"
        end |> raw() %>
      </div>

      <div class="history-item-body">
        <div class="history-time"><%= format_deploy_time(@deployment.timestamp) %></div>
        <div class="history-details">
          <span class="history-platform"><%= format_platform(@deployment.platform) %></span>
          <span class="history-sha"><%= @deployment.sha %></span>
        </div>
        <%= if @deployment.error do %>
          <div class="history-error"><%= @deployment.error %></div>
        <% end %>
      </div>
    </div>
    """
  end

  # 数据加载

  defp load_recent_deployments do
    # 从 CICDManager 或数据库加载最近部署记录
    [
      %{
        timestamp: DateTime.utc_now() |> DateTime.add(-120, :second),
        env: :staging,
        status: :success,
        platform: :github_actions,
        sha: "abc123f"
      },
      %{
        timestamp: DateTime.utc_now() |> DateTime.add(-300, :second),
        env: :production,
        status: :success,
        platform: :github_actions,
        sha: "def456a"
      },
      %{
        timestamp: DateTime.utc_now() |> DateTime.add(-600, :second),
        env: :staging,
        status: :failure,
        platform: :github_actions,
        sha: "ghi789b",
        error: "测试失败"
      }
    ]
  end

  # 格式化函数

  defp format_deploy_time(nil), do: "未知"
  defp format_deploy_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "刚刚"
      diff < 3600 -> "#{div(diff, 60)} 分钟前"
      diff < 86_400 -> "#{div(diff, 3600)} 小时前"
      true -> Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
    end
  end

  defp format_platform(:github_actions), do: "GitHub Actions"
  defp format_platform(:gitlab_ci), do: "GitLab CI"
  defp format_platform(:jenkins), do: "Jenkins"
  defp format_platform(_), do: "其他"
end
