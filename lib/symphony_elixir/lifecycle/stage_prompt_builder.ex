defmodule SymphonyElixir.Lifecycle.StagePromptBuilder do
  @moduledoc """
  阶段 Prompt 构建器 - 为每个阶段提供专用的 Prompt 模板

  此模块负责：
  - 从模板目录加载阶段特定的 Prompt 模板
  - 使用 Solid 模板引擎渲染变量
  - 支持自定义 Prompt 模板
  """

  require Logger

  @render_opts [strict_variables: true, strict_filters: true]
  @templates_dir "templates"

  @doc """
  构建阶段特定的 Prompt

  ## 参数
    - issue: 飞书 issue 结构体
    - stage: 阶段配置 map
    - template_name: 模板文件名

  ## 返回
    - {:ok, prompt} - 成功构建的 Prompt
    - {:error, reason} - 错误原因
  """
  @spec build_stage_prompt(map(), map(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def build_stage_prompt(issue, stage, template_name) do
    case load_stage_template(template_name) do
      {:ok, template_content} ->
        prompt = render_stage_prompt(template_content, issue, stage)
        {:ok, prompt}

      {:error, reason} ->
        Logger.warning("Failed to load stage template #{template_name}: #{inspect(reason)}")
        # 回退到默认 Prompt
        {:ok, build_default_prompt(issue)}
    end
  end

  @doc """
  获取模板目录路径
  """
  @spec templates_dir() :: String.t()
  def templates_dir do
    Application.get_env(:symphony_elixir, :templates_dir) ||
      Path.join(File.cwd!(), @templates_dir)
  end

  # Private Functions

  defp load_stage_template(template_name) do
    template_path = Path.join(templates_dir(), template_name)

    case File.read(template_path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, :template_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp render_stage_prompt(template, issue, stage) do
    # 将 issue 转换为 Solid 可用的 map
    issue_map = to_solid_map(issue)

    # 将 stage 转换为 Solid 可用的 map
    stage_map = to_solid_map(stage)

    # 使用 Solid 渲染模板
    template
    |> Solid.parse!()
    |> Solid.render!(
      %{
        "issue" => issue_map,
        "stage" => stage_map
      },
      @render_opts
    )
    |> IO.iodata_to_binary()
  end

  defp build_default_prompt(issue) do
    # 构建一个简单的默认 prompt
    """
    # 任务执行

    **需求 ID**: #{Map.get(issue, :identifier) || Map.get(issue, "identifier")}
    **标题**: #{Map.get(issue, :title) || Map.get(issue, "title")}
    **描述**: #{Map.get(issue, :description) || Map.get(issue, "description")}

    请根据上述需求信息，完成相应的任务。
    """
  end

  defp to_solid_map(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), to_solid_value(value)} end)
  end

  defp to_solid_value(value) when is_map(value), do: to_solid_map(value)
  defp to_solid_value(value) when is_list(value), do: Enum.map(value, &to_solid_value/1)
  defp to_solid_value(value), do: value
end
