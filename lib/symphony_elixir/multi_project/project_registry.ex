defmodule SymphonyElixir.MultiProject.ProjectRegistry do
  @moduledoc """
  多项目注册表

  管理所有配置的项目,提供项目查询和更新功能。
  """

  use GenServer
  require Logger

  @table_name :symphony_projects

  # Client API

  @doc """
  启动项目注册表
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  列出所有项目
  """
  def list_projects do
    GenServer.call(__MODULE__, :list_projects)
  end

  @doc """
  获取单个项目
  """
  def get_project(project_id) do
    GenServer.call(__MODULE__, {:get_project, project_id})
  end

  @doc """
  注册项目
  """
  def register_project(project_config) do
    GenServer.call(__MODULE__, {:register_project, project_config})
  end

  @doc """
  更新项目状态
  """
  def update_project_status(project_id, status) do
    GenServer.call(__MODULE__, {:update_project_status, project_id, status})
  end

  @doc """
  获取活跃项目
  """
  def get_active_projects do
    GenServer.call(__MODULE__, :get_active_projects)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # 创建 ETS 表
    table =
      :ets.new(@table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true
      ])

    Logger.info("ProjectRegistry started")
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call(:list_projects, _from, state) do
    projects =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, project} -> project end)

    {:reply, projects, state}
  end

  @impl true
  def handle_call({:get_project, project_id}, _from, state) do
    case :ets.lookup(@table_name, project_id) do
      [{^project_id, project}] ->
        {:reply, {:ok, project}, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:register_project, project_config}, _from, state) do
    project = normalize_project(project_config)
    project_id = project.id

    :ets.insert(@table_name, {project_id, project})

    Logger.info("Registered project: #{project.name} (#{project_id})")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_project_status, project_id, status}, _from, state) do
    case :ets.lookup(@table_name, project_id) do
      [{^project_id, project}] ->
        updated_project = %{project | status: status}
        :ets.insert(@table_name, {project_id, updated_project})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:get_active_projects, _from, state) do
    active_projects =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, project} -> project end)
      |> Enum.filter(fn project -> project.status == :active end)

    {:reply, active_projects, state}
  end

  # Private Functions

  defp normalize_project(config) when is_map(config) do
    %{
      id: generate_id(config),
      name: Map.get(config, :name, "Unnamed Project"),
      tracker_config: Map.get(config, :tracker, %{}),
      workspace_root: Map.get(config, :workspace_root),
      max_concurrent_agents: Map.get(config, :max_concurrent_agents, 5),
      status: Map.get(config, :status, :active),
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp generate_id(config) do
    name = Map.get(config, :name, "project")
    name |> String.downcase() |> String.replace(" ", "_") |> then(&"project_#{&1}")
  end
end
