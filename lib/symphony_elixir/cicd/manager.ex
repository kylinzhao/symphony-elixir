defmodule SymphonyElixir.CICDManager do
  @moduledoc """
  CI/CD 流水线管理器

  支持:
  - GitHub Actions
  - GitLab CI
  - Jenkins (通过 Webhook)
  """

  require Logger

  @doc """
  触发部署

  ## 参数
  - workspace_path: 工作空间路径
  - env: 部署环境 (:staging, :production, 等)
  - config: CI/CD 配置

  ## 返回
  {:ok, run_info} 或 {:error, reason}
  """
  def trigger_deployment(workspace_path, env, config \\ nil) do
    config = config || get_ci_cd_config()

    if !config.enabled do
      Logger.info("CI/CD is disabled, skipping deployment")
      {:ok, :disabled}
    else
      case config.platform do
        "github_actions" -> trigger_github_actions(workspace_path, env, config)
        "gitlab_ci" -> trigger_gitlab_ci(workspace_path, env, config)
        "jenkins" -> trigger_jenkins(workspace_path, env, config)
        "custom" -> {:error, :custom_platform_not_implemented}
        _ -> {:error, :unknown_platform}
      end
    end
  end

  @doc """
  获取部署状态

  ## 参数
  - run_id: 运行 ID
  - config: CI/CD 配置

  ## 返回
  {:ok, status_info} 或 {:error, reason}
  """
  def get_deployment_status(run_id, config \\ nil) do
    config = config || get_ci_cd_config()

    case config.platform do
      "github_actions" -> get_github_actions_status(run_id, config)
      "gitlab_ci" -> get_gitlab_ci_status(run_id, config)
      "jenkins" -> get_jenkins_status(run_id, config)
      _ -> {:error, :unknown_platform}
    end
  end

  @doc """
  等待部署完成

  ## 参数
  - run_id: 运行 ID
  - timeout_ms: 超时时间 (毫秒)
  - interval_ms: 轮询间隔 (毫秒)

  ## 返回
  :ok 或 {:error, reason}
  """
  def wait_for_completion(run_id, timeout_ms \\ 300_000, interval_ms \\ 5000) do
    start_time = System.monotonic_time(:millisecond)

    wait_for_completion_loop(run_id, start_time, timeout_ms, interval_ms)
  end

  # GitHub Actions 实现

  defp trigger_github_actions(workspace_path, env, config) do
    workflow = config.workflow || "deploy.yml"

    cmd = """
    cd #{workspace_path} && \
    gh workflow run #{workflow} -f env=#{env} -f branch=$(git branch --show-current)
    """

    case exec_cmd(cmd) do
      {output, 0} ->
        run_id = extract_github_run_id(output)
        Logger.info("GitHub Actions triggered: #{run_id}")
        {:ok, %{run_id: run_id, platform: :github_actions}}

      {error, _} ->
        Logger.error("Failed to trigger GitHub Actions: #{error}")
        {:error, {:trigger_failed, error}}
    end
  end

  defp get_github_actions_status(run_id, _config) do
    cmd = "gh run view #{run_id} --json status,conclusion"

    case exec_cmd(cmd) do
      {output, 0} ->
        data = Jason.decode!(output)
        {:ok,
         %{
           status: data["status"],
           conclusion: data["conclusion"]
         }}

      {error, _} ->
        {:error, {:status_fetch_failed, error}}
    end
  end

  # GitLab CI 实现

  defp trigger_gitlab_ci(workspace_path, env, config) do
    workflow = config.workflow || "deploy.yml"

    cmd = """
    cd #{workspace_path} && \
    gitlab-ci-local run #{workflow} --env=#{env}
    """

    case exec_cmd(cmd) do
      {output, 0} ->
        run_id = extract_gitlab_pipeline_id(output)
        Logger.info("GitLab CI triggered: #{run_id}")
        {:ok, %{run_id: run_id, platform: :gitlab_ci}}

      {error, _} ->
        Logger.error("Failed to trigger GitLab CI: #{error}")
        {:error, {:trigger_failed, error}}
    end
  end

  defp get_gitlab_ci_status(run_id, _config) do
    cmd = "gitlab-ci-local status #{run_id}"

    case exec_cmd(cmd) do
      {output, 0} ->
        # 解析 GitLab CI 输出
        status = parse_gitlab_status(output)
        {:ok, %{status: status}}

      {error, _} ->
        {:error, {:status_fetch_failed, error}}
    end
  end

  # Jenkins 实现 (基础框架)

  defp trigger_jenkins(_workspace_path, _env, _config) do
    Logger.warning("Jenkins integration not fully implemented")
    {:error, :not_implemented}
  end

  defp get_jenkins_status(_run_id, _config) do
    {:error, :not_implemented}
  end

  # 辅助函数

  defp wait_for_completion_loop(run_id, start_time, timeout_ms, interval_ms) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > timeout_ms do
      {:error, :timeout}
    else
      case get_deployment_status(run_id) do
        {:ok, %{status: "completed", conclusion: "success"}} ->
          :ok

        {:ok, %{status: "completed", conclusion: conclusion}} when conclusion in ["failure", "cancelled"] ->
          {:error, {:deployment_failed, conclusion}}

        {:ok, %{status: status}} when status in ["queued", "in_progress", "pending"] ->
          Process.sleep(interval_ms)
          wait_for_completion_loop(run_id, start_time, timeout_ms, interval_ms)

        {:error, reason} ->
          {:error, {:status_check_failed, reason}}
      end
    end
  end

  defp get_ci_cd_config do
    SymphonyElixir.Config.settings!().ci_cd
  end

  defp exec_cmd(cmd) do
    cmd
    |> String.to_charlist()
    |> :os.cmd()
    |> to_string()
    |> then(fn output -> {output, 0} end)
  rescue
    e -> {Exception.message(e), 1}
  end

  defp extract_github_run_id(output) do
    # GitHub CLI 输出格式:
    # ✓ 1234567890 created
    # 或: Workflow run '1234567890' created

    case Regex.run(~r/(\d{10,})/, output) do
      [_, run_id] -> run_id
      _ -> "unknown"
    end
  end

  defp extract_gitlab_pipeline_id(output) do
    # GitLab CI 输出格式: 需要根据实际情况调整
    case Regex.run(~r/(\d+)/, output) do
      [_, pipeline_id] -> pipeline_id
      _ -> "unknown"
    end
  end

  defp parse_gitlab_status(output) do
    cond do
      String.contains?(output, "passed") -> "success"
      String.contains?(output, "failed") -> "failure"
      String.contains?(output, "running") -> "in_progress"
      String.contains?(output, "pending") -> "pending"
      true -> "unknown"
    end
  end
end
