defmodule SymphonyElixir.FeishuClient do
  @moduledoc """
  飞书 Open API 客户端

  支持 App ID + App Secret 认证方式
  """

  require Logger
  alias Req.Request

  @base_url "https://open.feishu.cn/open-apis"
  @token_cache_name :feishu_token_cache

  @doc """
  根据状态筛选多维表格记录
  """
  def fetch_records_by_states(app_token, table_id, states) do
    # 构建多个条件，使用 "or" 连接
    conditions = Enum.map(states, fn state ->
      %{
        field_name: "状态",
        operator: "is",
        value: [state]
      }
    end)

    query = %{
      filter: %{
        conjunction: "or",
        conditions: conditions
      }
    }

    request(:post, "/bitable/v1/apps/#{app_token}/tables/#{table_id}/records/search", query)
  end

  @doc """
  批量获取记录
  """
  def fetch_records_by_ids(app_token, table_id, record_ids) do
    request(:post, "/bitable/v1/apps/#{app_token}/tables/#{table_id}/records/batch_get", %{
      record_ids: record_ids
    })
  end

  @doc """
  更新记录
  """
  def update_record(app_token, table_id, record_id, fields) do
    request(
      :put,
      "/bitable/v1/apps/#{app_token}/tables/#{table_id}/records/#{record_id}",
      %{fields: fields}
    )
  end

  @doc """
  创建记录
  """
  def create_record(app_token, table_id, fields) do
    request(:post, "/bitable/v1/apps/#{app_token}/tables/#{table_id}/records", %{
      fields: fields
    })
  end

  @doc """
  获取单个记录
  """
  def get_record(app_token, table_id, record_id) do
    request(:get, "/bitable/v1/apps/#{app_token}/tables/#{table_id}/records/#{record_id}", %{})
  end

  @doc """
  获取多维表格信息
  """
  def get_table_info(app_token, table_id) do
    request(:get, "/bitable/v1/apps/#{app_token}/tables/#{table_id}", %{})
  end

  @doc """
  获取多维表格的所有字段
  """
  def get_table_fields(app_token, table_id) do
    request(:get, "/bitable/v1/apps/#{app_token}/tables/#{table_id}/fields", %{})
  end

  @doc """
  获取多维表格的所有记录（分页）
  """
  def get_all_records(app_token, table_id, page_token \\ nil, page_size \\ 100) do
    query = if page_token do
      %{"page_size" => page_size, "page_token" => page_token}
    else
      %{"page_size" => page_size}
    end

    request(:get, "/bitable/v1/apps/#{app_token}/tables/#{table_id}/records", query)
  end

  @doc """
  通用的 API 请求函数（公开版本）
  """
  def make_request(method, path, body \\ %{}) do
    request(method, path, body)
  end

  # 私有函数

  defp request(method, path, body) do
    # Ensure Finch is started
    case Application.ensure_all_started(:finch) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    with {:ok, token} <- get_access_token() do
      url = @base_url <> path

      case method do
        :get ->
          case Req.get(url,
                 headers: [
                   {"Authorization", "Bearer #{token}"}
                 ],
                 receive_timeout: 30_000
               ) do
            {:ok, %Req.Response{status: 200, body: response_body}} ->
              case response_body do
                %{"code" => 0, "data" => data} ->
                  {:ok, data}

                %{"code" => code, "msg" => msg} ->
                  Logger.error("Feishu API error: code=#{code}, msg=#{msg}")
                  {:error, {:feishu_api_error, code, msg}}
              end

            {:ok, %Req.Response{status: status, body: body}} ->
              Logger.error("Feishu HTTP error: status=#{status}, body=#{inspect(body)}")
              {:error, {:http_error, status, body}}

            {:error, reason} ->
              Logger.error("Feishu request error: #{inspect(reason)}")
              {:error, {:request_error, reason}}
          end

        :post ->
          case Req.post(url,
                 headers: [
                   {"Authorization", "Bearer #{token}"},
                   {"Content-Type", "application/json"}
                 ],
                 json: body,
                 receive_timeout: 30_000
               ) do
            {:ok, %Req.Response{status: 200, body: response_body}} ->
              case response_body do
                %{"code" => 0, "data" => data} ->
                  {:ok, data}

                %{"code" => code, "msg" => msg} ->
                  Logger.error("Feishu API error: code=#{code}, msg=#{msg}")
                  {:error, {:feishu_api_error, code, msg}}
              end

            {:ok, %Req.Response{status: status, body: body}} ->
              Logger.error("Feishu HTTP error: status=#{status}, body=#{inspect(body)}")
              {:error, {:http_error, status, body}}

            {:error, reason} ->
              Logger.error("Feishu request error: #{inspect(reason)}")
              {:error, {:request_error, reason}}
          end

        :put ->
          case Req.put(url,
                 headers: [
                   {"Authorization", "Bearer #{token}"},
                   {"Content-Type", "application/json"}
                 ],
                 json: body,
                 receive_timeout: 30_000
               ) do
            {:ok, %Req.Response{status: 200, body: response_body}} ->
              case response_body do
                %{"code" => 0, "data" => data} ->
                  {:ok, data}

                %{"code" => code, "msg" => msg} ->
                  Logger.error("Feishu API error: code=#{code}, msg=#{msg}")
                  {:error, {:feishu_api_error, code, msg}}
              end

            {:ok, %Req.Response{status: status, body: body}} ->
              Logger.error("Feishu HTTP error: status=#{status}, body=#{inspect(body)}")
              {:error, {:http_error, status, body}}

            {:error, reason} ->
              Logger.error("Feishu request error: #{inspect(reason)}")
              {:error, {:request_error, reason}}
          end
      end
    end
  end

  # 获取 tenant_access_token
  defp get_access_token do
    # 检查缓存
    case cached_token() do
      {:ok, token} ->
        {:ok, token}

      :error ->
        # 获取新 token
        fetch_new_token()
    end
  end

  defp fetch_new_token do
    app_id = get_app_id()
    app_secret = get_app_secret()

    url = @base_url <> "/auth/v3/tenant_access_token/internal"

    body = %{
      "app_id" => app_id,
      "app_secret" => app_secret
    }

    case Req.post(url, json: body, receive_timeout: 10_000) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        case response_body do
          %{"code" => 0, "tenant_access_token" => token, "expire" => expire} ->
            # 缓存 token (提前 5 分钟过期)
            cache_token(token, expire - 300)
            Logger.info("Feishu access token refreshed")
            {:ok, token}

          %{"code" => code, "msg" => msg} ->
            Logger.error("Failed to get Feishu token: #{code} - #{msg}")
            {:error, {:token_fetch_failed, code, msg}}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("HTTP error when fetching token: #{status}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("Request error when fetching token: #{inspect(reason)}")
        {:error, {:request_error, reason}}
    end
  end

  defp get_app_id do
    case System.get_env("FEISHU_APP_ID") do
      nil -> raise "FEISHU_APP_ID not set"
      app_id -> app_id
    end
  end

  defp get_app_secret do
    case System.get_env("FEISHU_APP_SECRET") do
      nil -> raise "FEISHU_APP_SECRET not set"
      app_secret -> app_secret
    end
  end

  # Token 缓存
  defp cached_token do
    try do
      case :ets.lookup(@token_cache_name, :access_token) do
        [{:access_token, token, expire_at}] ->
          if System.system_time(:second) < expire_at do
            {:ok, token}
          else
            :error
          end

        [] ->
          :error
      end
    rescue
      ArgumentError -> :error
    end
  end

  defp cache_token(token, expire_in_seconds) do
    try do
      :ets.new(@token_cache_name, [:named_table, :public])
    rescue
      ArgumentError ->
        # 表已存在
        :ok
    end

    expire_at = System.system_time(:second) + expire_in_seconds
    :ets.insert(@token_cache_name, {:access_token, token, expire_at})
    :ok
  end
end
