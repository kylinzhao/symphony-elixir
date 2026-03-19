defmodule SymphonyElixirWeb.DashboardLive do
  @moduledoc """
  Live observability dashboard for Symphony.
  """

  require Logger
  use Phoenix.LiveView, layout: {SymphonyElixirWeb.Layouts, :app}

  alias SymphonyElixirWeb.{Endpoint, ObservabilityPubSub, Presenter}
  @runtime_tick_ms 1_000

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("[DASHBOARD] mount called")

    completed = try do
      load_completed_issues()
    rescue
      e ->
        Logger.error("[DASHBOARD] Error loading completed issues: #{inspect(e)}")
        Logger.error("[DASHBOARD] Stacktrace: #{Exception.format_stacktrace()}")
        []
    end

    socket =
      socket
      |> assign(:payload, load_payload())
      |> assign(:completed_issues, completed)
      |> assign(:now, DateTime.utc_now())
      |> assign(:selected_agent, nil)
      |> assign(:is_paused, false)

    Logger.info("[DASHBOARD] mount completed, completed_issues=#{length(socket.assigns.completed_issues)}")

    if connected?(socket) do
      :ok = ObservabilityPubSub.subscribe()
      schedule_runtime_tick()
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("show_agent_details", %{"issue_id" => issue_id}, socket) do
    selected_entry = Enum.find(socket.assigns.payload.running, fn e -> e.issue_identifier == issue_id end)
    {:noreply, assign(socket, :selected_agent, selected_entry)}
  end

  @impl true
  def handle_event("close_agent_modal", _, socket) do
    {:noreply, assign(socket, :selected_agent, nil)}
  end

  @impl true
  def handle_event("toggle_pause", _, socket) do
    new_paused_state = !socket.assigns.is_paused
    paused_state = if new_paused_state, do: :paused, else: :running

    # Notify orchestrator about pause state change
    case Process.whereis(SymphonyElixir.Orchestrator) do
      pid when is_pid(pid) ->
        send(pid, {:set_paused_state, paused_state})
      _ ->
        :ok
    end

    {:noreply, assign(socket, :is_paused, new_paused_state)}
  end

  @impl true
  def handle_info(:runtime_tick, socket) do
    schedule_runtime_tick()
    {:noreply, assign(socket, :now, DateTime.utc_now())}
  end

  @impl true
  def handle_info(:observability_updated, socket) do
    {:noreply,
     socket
     |> assign(:payload, load_payload())
     |> assign(:completed_issues, load_completed_issues())
     |> assign(:now, DateTime.utc_now())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      .action-stack {
        display: flex;
        flex-direction: column;
        gap: 0.25rem;
      }
      .action-link {
        display: inline-flex;
        align-items: center;
        gap: 0.25rem;
        padding: 0.25rem 0.5rem;
        font-size: 0.75rem;
        text-decoration: none;
        border-radius: 0.25rem;
        transition: all 0.15s ease;
        cursor: pointer;
        border: 1px solid #e5e7eb;
        background: white;
        color: #374151;
        width: fit-content;
      }
      .action-link:hover {
        background: #f9fafb;
        border-color: #d1d5db;
      }
      .action-link-preview {
        background: #ecfdf5;
        border-color: #a7f3d0;
        color: #065f46;
      }
      .action-link-preview:hover {
        background: #d1fae5;
        border-color: #6ee7b7;
      }
      .action-link-folder {
        background: #eff6ff;
        border-color: #bfdbfe;
        color: #1e40af;
      }
      .action-link-folder:hover {
        background: #dbeafe;
        border-color: #93c5fd;
      }

      .state-badge-success {
        background: #d1fae5;
        border-color: #6ee7b7;
        color: #065f46;
      }

      /* Agent Activity Cell - Inline Display */
      .agent-activity-inline {
        min-width: 180px;
        max-width: 250px;
      }
      .agent-activity-preview {
        padding: 0.5rem 0.75rem;
        background: #f9fafb;
        border: 1px solid #e5e7eb;
        border-radius: 0.375rem;
        cursor: pointer;
        transition: all 0.15s ease;
        text-align: left;
      }
      .agent-activity-preview:hover {
        background: #f3f4f6;
        border-color: #d1d5db;
      }
      .agent-activity-status {
        font-size: 0.8rem;
        font-weight: 500;
        color: #374151;
        margin-bottom: 0.25rem;
      }
      .agent-activity-message {
        font-size: 0.75rem;
        color: #6b7280;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }
      .agent-activity-time {
        font-size: 0.7rem;
        color: #9ca3af;
        margin-top: 0.25rem;
      }

      /* Modal Styles */
      .modal-backdrop {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
      }
      .modal-content {
        background: white;
        border-radius: 0.75rem;
        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
        max-width: 800px;
        width: 90%;
        max-height: 80vh;
        overflow: hidden;
        display: flex;
        flex-direction: column;
      }
      .modal-header {
        padding: 1.5rem;
        border-bottom: 1px solid #e5e7eb;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      .modal-title {
        margin: 0;
        font-size: 1.25rem;
        font-weight: 600;
        color: #1f2937;
      }
      .modal-close {
        background: none;
        border: none;
        font-size: 1.5rem;
        color: #6b7280;
        cursor: pointer;
        padding: 0.25rem;
        line-height: 1;
      }
      .modal-close:hover {
        color: #1f2937;
      }
      .modal-body {
        padding: 1.5rem;
        overflow-y: auto;
        flex: 1;
      }
      .modal-section {
        margin-bottom: 1.5rem;
      }
      .modal-section:last-child {
        margin-bottom: 0;
      }
      .modal-section-title {
        font-size: 0.875rem;
        font-weight: 600;
        color: #374151;
        margin-bottom: 0.75rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
      }
      .modal-info-row {
        display: flex;
        margin-bottom: 0.5rem;
      }
      .modal-info-label {
        font-weight: 500;
        color: #6b7280;
        min-width: 120px;
      }
      .modal-info-value {
        color: #1f2937;
      }
      .modal-message-box {
        background: #f9fafb;
        border: 1px solid #e5e7eb;
        border-radius: 0.5rem;
        padding: 1rem;
        margin-top: 0.5rem;
      }
      .modal-message-text {
        color: #374151;
        line-height: 1.6;
        word-break: break-word;
      }
      .modal-path-box {
        background: #ffffff;
        border: 1px solid #d1d5db;
        border-radius: 0.375rem;
        padding: 0.75rem;
        margin-top: 0.5rem;
      }
      .modal-path-text {
        font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
        font-size: 0.875rem;
        color: #4b5563;
        word-break: break-all;
      }

      /* Pause Button Styles */
      .pause-button {
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.5rem 1rem;
        border-radius: 0.375rem;
        font-size: 0.875rem;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.15s ease;
        border: 1px solid #e5e7eb;
      }
      .pause-button.paused {
        background: #fef3c7;
        border-color: #fbbf24;
        color: #92400e;
      }
      .pause-button.running {
        background: #d1fae5;
        border-color: #34d399;
        color: #065f46;
      }
      .pause-button:hover {
        opacity: 0.9;
      }
    </style>
    <section class="dashboard-shell">
      <%= if @selected_agent do %>
        <div class="modal-backdrop" phx-click="close_agent_modal">
          <div class="modal-content" phx-click-stop>
            <div class="modal-header">
              <h2 class="modal-title">
                Agent Details: <%= @selected_agent.issue_identifier %>
              </h2>
              <button class="modal-close" phx-click="close_agent_modal">&times;</button>
            </div>
            <div class="modal-body">
              <div class="modal-section">
                <h3 class="modal-section-title">Current Activity</h3>
                <div class="modal-info-row">
                  <span class="modal-info-label">Status:</span>
                  <span class="modal-info-value">
                    <span class={state_badge_class(@selected_agent.state)}>
                      <%= @selected_agent.state %>
                    </span>
                  </span>
                </div>
                <div class="modal-info-row">
                  <span class="modal-info-label">Event:</span>
                  <span class="modal-info-value"><code><%= @selected_agent.last_event || "N/A" %></code></span>
                </div>
                <div class="modal-message-box">
                  <p class="modal-message-text">
                    <%= @selected_agent.last_message || "Waiting for update..." %>
                  </p>
                </div>
                <%= if @selected_agent.last_event_at do %>
                  <p style="margin-top: 0.5rem; font-size: 0.875rem; color: #6b7280;">
                    Last updated: <%= @selected_agent.last_event_at %>
                  </p>
                <% end %>
              </div>

              <div class="modal-section">
                <h3 class="modal-section-title">Session Information</h3>
                <div class="modal-info-row">
                  <span class="modal-info-label">Turns:</span>
                  <span class="modal-info-value"><%= @selected_agent.turn_count || 0 %></span>
                </div>
                <div class="modal-info-row">
                  <span class="modal-info-label">Runtime:</span>
                  <span class="modal-info-value">
                    <%= format_runtime_seconds(runtime_seconds_from_started_at(@selected_agent.started_at, @now)) %>
                  </span>
                </div>
                <div class="modal-info-row">
                  <span class="modal-info-label">Tokens:</span>
                  <span class="modal-info-value">
                    In: <%= format_int(@selected_agent.tokens.input_tokens) %> /
                    Out: <%= format_int(@selected_agent.tokens.output_tokens) %> /
                    Total: <%= format_int(@selected_agent.tokens.total_tokens) %>
                  </span>
                </div>
              </div>

              <%= if @selected_agent.issue_identifier do %>
                <% workspace_path = Path.join([System.get_env("HOME") || "~", "symphony-workspaces", @selected_agent.issue_identifier]) %>
                <div class="modal-section">
                  <h3 class="modal-section-title">Workspace</h3>
                  <div class="modal-path-box">
                    <p class="modal-path-text"><%= workspace_path %></p>
                  </div>
                  <div style="margin-top: 1rem; display: flex; gap: 0.5rem;">
                    <a
                      class="action-link action-link-folder"
                      href={"file://#{workspace_path}"}
                      target="_blank"
                    >
                      📁 Open Folder
                    </a>
                    <%= if File.exists?(Path.join(workspace_path, "TASK_PLAN.json")) do %>
                      <a
                        class="action-link action-link-preview"
                        href={"file://#{workspace_path}/TASK_PLAN.json"}
                        target="_blank"
                      >
                        📋 View Plan
                      </a>
                    <% end %>
                    <%= if File.exists?(Path.join(workspace_path, "index.html")) do %>
                      <a
                        class="action-link action-link-preview"
                        href={"file://#{workspace_path}/index.html"}
                        target="_blank"
                      >
                        👁️ Preview
                      </a>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <header class="hero-card">
        <div class="hero-grid">
          <div>
            <p class="eyebrow">
              Symphony Observability
            </p>
            <h1 class="hero-title">
              Operations Dashboard
            </h1>
            <p class="hero-copy">
              Current state, retry pressure, token usage, and orchestration health for the active Symphony runtime.
            </p>
          </div>

          <div class="status-stack">
            <span class="status-badge status-badge-live">
              <span class="status-badge-dot"></span>
              Live
            </span>
            <button
              type="button"
              class={"pause-button #{if @is_paused, do: "paused", else: "running"}"}
              phx-click="toggle_pause"
            >
              <span><%= if @is_paused, do: "▶ Resume", else: "⏸ Pause" %></span>
            </button>
          </div>
        </div>
      </header>

      <%= if @payload[:error] do %>
        <section class="error-card">
          <h2 class="error-title">
            Snapshot unavailable
          </h2>
          <p class="error-copy">
            <strong><%= @payload.error.code %>:</strong> <%= @payload.error.message %>
          </p>
        </section>
      <% else %>
        <section class="metric-grid">
          <article class="metric-card">
            <p class="metric-label">Running</p>
            <p class="metric-value numeric"><%= @payload.counts.running %></p>
            <p class="metric-detail">Active issue sessions in the current runtime.</p>
          </article>

          <article class="metric-card">
            <p class="metric-label">Queued</p>
            <p class="metric-value numeric"><%= @payload.counts.queued %></p>
            <p class="metric-detail">Issues fetched and waiting to start.</p>
          </article>

          <article class="metric-card">
            <p class="metric-label">Retrying</p>
            <p class="metric-value numeric"><%= @payload.counts.retrying %></p>
            <p class="metric-detail">Issues waiting for the next retry window.</p>
          </article>

          <article class="metric-card">
            <p class="metric-label">Total tokens</p>
            <p class="metric-value numeric"><%= format_int(@payload.codex_totals.total_tokens) %></p>
            <p class="metric-detail numeric">
              In <%= format_int(@payload.codex_totals.input_tokens) %> / Out <%= format_int(@payload.codex_totals.output_tokens) %>
            </p>
          </article>

          <article class="metric-card">
            <p class="metric-label">Runtime</p>
            <p class="metric-value numeric"><%= format_runtime_seconds(total_runtime_seconds(@payload, @now)) %></p>
            <p class="metric-detail">Total Codex runtime across completed and active sessions.</p>
          </article>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">Running sessions</h2>
              <p class="section-copy">Active issues, last known agent activity, and token usage. <strong>Click on Agent Activity to view details.</strong></p>
            </div>
          </div>

          <%= if @payload.running == [] do %>
            <p class="empty-state">No active sessions.</p>
          <% else %>
            <div class="table-wrap">
              <table class="data-table data-table-running">
                <colgroup>
                  <col style="width: 10rem;" />
                  <col style="width: 6rem;" />
                  <col style="width: 6rem;" />
                  <col style="width: 8rem;" />
                  <col style="width: 8rem;" />
                  <col style="width: 12rem;" />
                  <col style="width: 10rem;" />
                </colgroup>
                <thead>
                  <tr>
                    <th>Issue</th>
                    <th>State</th>
                    <th>Actions</th>
                    <th>Session ID</th>
                    <th>Runtime / Turns</th>
                    <th>Agent Activity</th>
                    <th>Tokens</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @payload.running}>
                    <td>
                      <div class="issue-stack">
                        <span class="issue-id"><%= entry.issue_identifier %></span>
                        <a class="issue-link" href={"/api/v1/#{entry.issue_identifier}"}>JSON</a>
                      </div>
                    </td>
                    <td>
                      <span class={state_badge_class(entry.state)}>
                        <%= entry.state %>
                      </span>
                    </td>
                    <td>
                      <div class="action-stack">
                        <%= if entry.issue_identifier do %>
                          <% workspace_path = Path.join([System.get_env("HOME") || "~", "symphony-workspaces", entry.issue_identifier]) %>
                          <%= if File.exists?(Path.join(workspace_path, "index.html")) do %>
                            <a
                              class="action-link action-link-preview"
                              href={"file://#{workspace_path}/index.html"}
                              target="_blank"
                            >
                              👁️
                            </a>
                          <% end %>
                          <a
                            class="action-link action-link-folder"
                            href={"file://#{workspace_path}"}
                            target="_blank"
                          >
                            📁
                          </a>
                        <% else %>
                          <span class="muted">n/a</span>
                        <% end %>
                      </div>
                    </td>
                    <td>
                      <div class="session-stack">
                        <%= if entry.session_id do %>
                          <button
                            type="button"
                            class="subtle-button"
                            data-label="Copy"
                            data-copy={entry.session_id}
                            onclick="navigator.clipboard.writeText(this.dataset.copy); this.textContent = 'Copied'; clearTimeout(this._copyTimer); this._copyTimer = setTimeout(() => { this.textContent = this.dataset.label }, 1200);"
                          >
                            Copy
                          </button>
                        <% else %>
                          <span class="muted">n/a</span>
                        <% end %>
                      </div>
                    </td>
                    <td class="numeric"><%= format_runtime_and_turns(entry.started_at, entry.turn_count, @now) %></td>
                    <td>
                      <div class="agent-activity-inline">
                        <div
                          class="agent-activity-preview"
                          phx-click="show_agent_details"
                          phx-value-issue_id={entry.issue_identifier}
                        >
                          <div class="agent-activity-status">
                            <%= entry.last_event || "Initializing" %>
                          </div>
                          <div class="agent-activity-message">
                            <%= entry.last_message || "Waiting for update..." %>
                          </div>
                          <%= if entry.last_event_at do %>
                            <div class="agent-activity-time">
                              <%= entry.last_event_at %>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div class="token-stack numeric">
                        <span><%= format_int(entry.tokens.total_tokens) %></span>
                        <span class="muted" style="font-size: 0.75rem;">
                          <%= format_int(entry.tokens.input_tokens) %> in / <%= format_int(entry.tokens.output_tokens) %> out
                        </span>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">Queued issues</h2>
              <p class="section-copy">Issues fetched from tracker but waiting for available agent slot.</p>
            </div>
          </div>

          <%= if @payload[:queued] == [] or @payload[:queued] == nil do %>
            <p class="empty-state">No issues are queued.</p>
          <% else %>
            <div class="table-wrap">
              <table class="data-table" style="min-width: 680px;">
                <thead>
                  <tr>
                    <th>Issue</th>
                    <th>State</th>
                    <th>Actions</th>
                    <th>Description</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @payload[:queued]}>
                    <td>
                      <div class="issue-stack">
                        <span class="issue-id"><%= entry.issue_identifier %></span>
                      </div>
                    </td>
                    <td>
                      <span class={state_badge_class(entry.state)}>
                        <%= entry.state %>
                      </span>
                    </td>
                    <td>
                      <div class="action-stack">
                        <%= if entry.issue_identifier do %>
                          <% workspace_path = Path.join([System.get_env("HOME") || "~", "symphony-workspaces", entry.issue_identifier]) %>
                          <a
                            class="action-link action-link-folder"
                            href={"file://#{workspace_path}"}
                            target="_blank"
                          >
                            📁
                          </a>
                        <% else %>
                          <span class="muted">n/a</span>
                        <% end %>
                      </div>
                    </td>
                    <td>
                      <div class="detail-stack">
                        <span class="event-text"><%= entry.title || "n/a" %></span>
                        <%= if entry.description do %>
                          <span class="muted event-meta" style="max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: block;">
                            <%= String.slice(entry.description, 0, 100) %><%= if String.length(entry.description) > 100, do: "...", else: "" %>
                          </span>
                        <% end %>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">Retry queue</h2>
              <p class="section-copy">Issues waiting for the next retry window.</p>
            </div>
          </div>

          <%= if @payload.retrying == [] do %>
            <p class="empty-state">No issues are currently backing off.</p>
          <% else %>
            <div class="table-wrap">
              <table class="data-table" style="min-width: 800px;">
                <thead>
                  <tr>
                    <th>Issue</th>
                    <th>Attempt</th>
                    <th>Due at</th>
                    <th>Error</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @payload.retrying}>
                    <td>
                      <div class="issue-stack">
                        <span class="issue-id"><%= entry.issue_identifier %></span>
                      </div>
                    </td>
                    <td><%= entry.attempt %></td>
                    <td class="mono"><%= entry.due_at || "n/a" %></td>
                    <td><%= entry.error || "n/a" %></td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">Completed issues</h2>
              <p class="section-copy">Issues that have been completed or closed.</p>
            </div>
          </div>

          <%= if @completed_issues == [] or @completed_issues == nil do %>
            <p class="empty-state">No completed issues.</p>
          <% else %>
            <div class="table-wrap">
              <table class="data-table" style="min-width: 800px;">
                <thead>
                  <tr>
                    <th>Issue</th>
                    <th>State</th>
                    <th>Actions</th>
                    <th>Description</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @completed_issues}>
                    <td>
                      <div class="issue-stack">
                        <span class="issue-id"><%= entry.issue_identifier || entry.issue_id %></span>
                      </div>
                    </td>
                    <td>
                      <span class={state_badge_class(entry.state)}>
                        <%= entry.state %>
                      </span>
                    </td>
                    <td>
                      <div class="action-stack">
                        <%= if entry.issue_identifier do %>
                          <% workspace_path = Path.join([System.get_env("HOME") || "~", "symphony-workspaces", entry.issue_identifier]) %>
                          <a
                            class="action-link action-link-folder"
                            href={"file://#{workspace_path}"}
                            target="_blank"
                          >
                            📁
                          </a>
                        <% else %>
                          <span class="muted">n/a</span>
                        <% end %>
                      </div>
                    </td>
                    <td>
                      <div class="detail-stack">
                        <span class="event-text"><%= entry.title || "n/a" %></span>
                        <%= if entry.description do %>
                          <span class="muted event-meta" style="max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: block;">
                            <%= String.slice(entry.description, 0, 100) %><%= if String.length(entry.description) > 100, do: "...", else: "" %>
                          </span>
                        <% end %>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>
      <% end %>
    </section>
    """
  end

  defp load_payload do
    Presenter.state_payload(orchestrator(), snapshot_timeout_ms())
  end

  defp load_completed_issues do
    config = SymphonyElixir.Config.settings!().tracker
    kind = Map.get(config, :kind)
    app_token = Map.get(config, :app_token)
    table_id = Map.get(config, :table_id)

    case {kind, app_token, table_id} do
      {"feishu", app_token, table_id} when is_binary(app_token) and is_binary(table_id) ->
        case SymphonyElixir.FeishuClient.get_all_records(app_token, table_id) do
          {:ok, data} ->
            items = Map.get(data, "items", [])

            all_issues =
              items
              |> Enum.map(&SymphonyElixir.Feishu.Issue.normalize/1)

            completed_issues =
              all_issues
              |> Enum.filter(fn issue ->
                Map.get(issue, :state) in ["已完成", "已关闭"]
              end)

            completed_issues
            |> Enum.map(fn issue ->
              %{
                issue_id: Map.get(issue, :id),
                issue_identifier: Map.get(issue, :identifier),
                title: Map.get(issue, :title),
                state: Map.get(issue, :state),
                description: Map.get(issue, :description),
                workspace: %{
                  path: Path.join([System.get_env("HOME") || "~", "symphony-workspaces", Map.get(issue, :identifier)])
                }
              }
            end)

          {:error, _reason} ->
            []
        end

      _ ->
        []
    end
  end

  defp orchestrator do
    Endpoint.config(:orchestrator) || SymphonyElixir.Orchestrator
  end

  defp snapshot_timeout_ms do
    Endpoint.config(:snapshot_timeout_ms) || 15_000
  end

  defp completed_runtime_seconds(payload) do
    payload.codex_totals.seconds_running || 0
  end

  defp total_runtime_seconds(payload, now) do
    completed_runtime_seconds(payload) +
      Enum.reduce(payload.running, 0, fn entry, total ->
        total + runtime_seconds_from_started_at(entry.started_at, now)
      end)
  end

  defp format_runtime_and_turns(started_at, turn_count, now) when is_integer(turn_count) and turn_count > 0 do
    "#{format_runtime_seconds(runtime_seconds_from_started_at(started_at, now))} / #{turn_count}"
  end

  defp format_runtime_and_turns(started_at, _turn_count, now),
    do: format_runtime_seconds(runtime_seconds_from_started_at(started_at, now))

  defp format_runtime_seconds(seconds) when is_number(seconds) do
    whole_seconds = max(trunc(seconds), 0)
    mins = div(whole_seconds, 60)
    secs = rem(whole_seconds, 60)
    "#{mins}m #{secs}s"
  end

  defp runtime_seconds_from_started_at(%DateTime{} = started_at, %DateTime{} = now) do
    DateTime.diff(now, started_at, :second)
  end

  defp runtime_seconds_from_started_at(started_at, %DateTime{} = now) when is_binary(started_at) do
    case DateTime.from_iso8601(started_at) do
      {:ok, parsed, _offset} -> runtime_seconds_from_started_at(parsed, now)
      _ -> 0
    end
  end

  defp runtime_seconds_from_started_at(_started_at, _now), do: 0

  defp format_int(value) when is_integer(value) do
    value
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0,")
    |> String.reverse()
  end

  defp format_int(_value), do: "n/a"

  defp state_badge_class(state) do
    base = "state-badge"
    normalized = state |> to_string() |> String.downcase()

    cond do
      String.contains?(normalized, ["progress", "running", "active"]) -> "#{base} state-badge-active"
      String.contains?(normalized, ["blocked", "error", "failed"]) -> "#{base} state-badge-danger"
      String.contains?(normalized, ["completed", "已完成", "closed", "已关闭", "done", "finished"]) -> "#{base} state-badge-success"
      String.contains?(normalized, ["todo", "queued", "pending", "retry"]) -> "#{base} state-badge-warning"
      true -> base
    end
  end

  defp schedule_runtime_tick do
    Process.send_after(self(), :runtime_tick, @runtime_tick_ms)
  end

  defp pretty_value(nil), do: "n/a"
  defp pretty_value(value), do: inspect(value, pretty: true, limit: :infinity)
end
