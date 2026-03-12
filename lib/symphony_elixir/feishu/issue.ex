defmodule SymphonyElixir.Feishu.Issue do
  @moduledoc """
  飞书多维表格记录的标准化表示
  """

  defstruct [
    :id,
    :identifier,
    :title,
    :description,
    :priority,
    :state,
    :branch_name,
    :url,
    :assignee_id,
    :blocked_by,
    :labels,
    :assigned_to_worker,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          identifier: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          priority: integer() | nil,
          state: String.t() | nil,
          branch_name: String.t() | nil,
          url: String.t() | nil,
          assignee_id: String.t() | nil,
          blocked_by: [map()],
          labels: [String.t()],
          assigned_to_worker: boolean(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  将飞书记录转换为标准化 Issue
  """
  def normalize(record) when is_map(record) do
    fields = Map.get(record, "fields", %{})

    %__MODULE__{
      id: Map.get(record, "record_id"),
      identifier: get_field_value(fields, "标题", "UNKNOWN"),
      title: get_field_value(fields, "标题", ""),
      description: get_field_value(fields, "描述", nil),
      priority: parse_priority(get_field_value(fields, "优先级")),
      state: get_field_text(fields, "状态"),
      branch_name: get_field_value(fields, "branch", nil),
      url: build_url(record),
      assignee_id: get_field_value(fields, "assignee", nil),
      blocked_by: parse_blockers(get_field_value(fields, "blockers", nil)),
      labels: parse_labels(get_field_value(fields, "标签", [])),
      assigned_to_worker: true,
      created_at: parse_timestamp(Map.get(record, "created_time")),
      updated_at: parse_timestamp(Map.get(record, "last_modified_time"))
    }
  end

  @spec label_names(t()) :: [String.t()]
  def label_names(%__MODULE__{labels: labels}) do
    labels
  end

  # 私有辅助函数

  defp get_field_value(fields, field_name, default \\ nil) do
    case Map.get(fields, field_name) do
      nil -> default
      value -> extract_value(value)
    end
  end

  defp get_field_text(fields, field_name) do
    case Map.get(fields, field_name) do
      nil -> ""
      %{"text" => text} -> text
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  defp extract_value([%{"text" => text} | _]), do: text
  defp extract_value(%{"text" => text}), do: text
  defp extract_value(value) when is_binary(value), do: value
  defp extract_value(value) when is_list(value), do: value
  defp extract_value(_), do: nil

  defp parse_priority(%{"text" => "P1"}), do: 1
  defp parse_priority(%{"text" => "P2"}), do: 2
  defp parse_priority(%{"text" => "P3"}), do: 3
  defp parse_priority(%{"text" => "P4"}), do: 4
  defp parse_priority(_), do: nil

  defp parse_labels(labels) when is_list(labels) do
    Enum.map(labels, fn
      %{"text" => text} -> String.downcase(text)
      text when is_binary(text) -> String.downcase(text)
      _ -> ""
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_labels(_), do: []

  defp parse_blockers(nil), do: []
  defp parse_blockers(""), do: []
  defp parse_blockers(blockers) when is_binary(blockers) do
    blockers
    |> String.split(",")
    |> Enum.map(fn blocker ->
      %{
        id: nil,
        identifier: String.trim(blocker),
        state: nil
      }
    end)
    |> Enum.reject(fn %{identifier: id} -> id == "" end)
  end

  defp parse_timestamp(nil), do: nil
  defp parse_timestamp(timestamp) when is_integer(timestamp) do
    case DateTime.from_unix(timestamp, :millisecond) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp build_url(%{"record_id" => record_id} = record) do
    app_token = Map.get(record, "app_token")
    table_id = Map.get(record, "table_id")
    "https://feishu.cn/base/#{app_token}?table=#{table_id}&view=vew_by_record&record=#{record_id}"
  end
end
