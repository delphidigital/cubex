defmodule Cubex.Rest do
  @behaviour Cubex.Base
  use Tesla

  @moduledoc """
  Cube REST client implementation. Common options applicable to many functions:

    `:request_id` - A request identifier ideally corresponding to a user interaction. Defaults to a generated uuid.

    `:sequence_id` - A sequence number corresponding to the sequence of requests for this user interation. Defaults to `1`.
  """

  require Logger

  @doc """
  Creates a new client. Parameters:

    `:url` - Optional base url. Required if not configured globally

    `:user_agent` - Optional user agent string. Overrides global config if specified.

    `:token` - Optional jwt parameter. Required if `:secret` is not configured.

    `:secret` - Optional secret for generating JWTs. When generating JWTs from a secret, keep in mind that they are only generated during client initialization. Long lived clients could out live the `:exp` claim.

    `:claims` - Optional map of claims to include in generated JWTs. Can also be configured globally.
  """
  @impl Cubex.Base
  def new(opts \\ []) do
    Tesla.client(common_middleware(opts))
  end

  @doc """
  Load data from cube. Options:

    `:continue_wait` - Boolean value which indicates if the request should continue waiting until data is returned or an error occurs. defaults to `true`.
  """
  @impl Cubex.Base
  def load(client, query, opts \\ []) do
    request_id = req_id(opts)
    sequence_id = seq_id(opts)
    headers = req_headers(request_id: request_id, sequence_id: sequence_id)

    result =
      Tesla.post(client, "/cubejs-api/v1/load", %{query: query}, headers: headers)
      |> handle_response("load")

    if Keyword.get(opts, :continue_wait, true) do
      case result do
        {:ok, %{"error" => "Continue wait"}} ->
          load(client, query, Keyword.put(opts, :sequence_id, sequence_id + 1))

        result ->
          result
      end
    else
      result
    end
  end

  @doc """
  Fetch metadata from cube.
  """
  @impl Cubex.Base
  def meta(client, opts \\ []) do
    Tesla.get(client, "/cubejs-api/v1/meta", headers: req_headers(opts))
    |> handle_response("meta")
  end

  @doc """
  Fetch sql from cube.
  """
  @impl Cubex.Base
  def sql(client, query, opts \\ []) do
    Tesla.post(client, "/cubejs-api/v1/sql", %{query: query}, headers: req_headers(opts))
    |> handle_response("sql")
  end

  ##################################################
  # Private
  ##################################################

  defp common_middleware(opts) do
    url = Keyword.get_lazy(opts, :url, &base_url!/0)
    agent = Keyword.get_lazy(opts, :user_agent, &user_agent/0)
    secret = Keyword.get_lazy(opts, :secret, &secret/0)
    claims = Keyword.get_lazy(opts, :claims, &claims/0)

    token =
      if secret != nil do
        generate_token(claims, secret)
      else
        Keyword.get_lazy(opts, :token, &token!/0)
      end

    [
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Headers,
       [
         {"authorization", token},
         {"user-agent", agent}
       ]},
      {
        Tesla.Middleware.Retry,
        should_retry: fn
          {:ok, %{status: status}} when status >= 500 -> true
          {:ok, _} -> false
          {:error, _} -> true
        end
      },
      Tesla.Middleware.JSON
    ]
  end

  defp generate_token(extra_claims, secret) when is_map(extra_claims) do
    token_config = %{
      "exp" => %Joken.Claim{generate: fn -> Joken.current_time() + 2 * 60 * 60 end}
    }

    signer = Joken.Signer.create("HS256", secret)
    {:ok, claims} = Joken.generate_claims(token_config, extra_claims)
    {:ok, jwt, _claims} = Joken.encode_and_sign(claims, signer)
    jwt
  end

  defp req_headers(opts) do
    [{"x-request-id", "#{req_id(opts)}-span-#{seq_id(opts)}"}]
  end

  defp req_id(opts), do: Keyword.get(opts, :request_id, UUID.uuid4())
  defp seq_id(opts), do: Keyword.get(opts, :sequence_id, 1)

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}, _action_str)
       when status >= 200 and status < 300 do
    case body do
      "" -> {:ok, nil}
      body -> {:ok, body}
    end
  end

  defp handle_response({_, %Tesla.Env{status: status, body: body}}, action_str) do
    Logger.warn(
      "failed to execute '#{action_str}'. status was #{status} and response body was #{inspect(body)}"
    )

    {:error, body}
  end

  defp handle_response({:error, error}, action_str) do
    Logger.warn("failed to execute '#{action_str}'. error was #{inspect(error)}")
    {:error, error}
  end

  defp base_url!(), do: config!(:base_url)
  defp token!(), do: config!(:token)
  defp secret(), do: config(:secret)
  defp claims(), do: config(:claims, %{})

  defp user_agent() do
    Keyword.get(config(), :user_agent, "cubex")
  end

  defp config(key, default \\ nil) when is_atom(key) do
    Keyword.get(config(), key, default)
  end

  defp config!(key) when is_atom(key) do
    if value = config(key) do
      value
    else
      raise "#{inspect(key)} not configured for #{inspect(__MODULE__)}"
    end
  end

  defp config() do
    Application.get_env(:cubex, __MODULE__, [])
  end
end
