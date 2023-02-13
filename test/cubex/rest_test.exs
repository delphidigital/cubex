defmodule Cubex.RestTest do
  use ExUnit.Case, async: true

  alias Cubex.Rest

  import Tesla.Mock

  @base_url "https://dne"
  @default_config [base_url: @base_url, token: "token"]

  @v1_path "#{@base_url}/cubejs-api/v1"
  @load_url "#{@v1_path}/load"
  @meta_url "#{@v1_path}/meta"
  @sql_url "#{@v1_path}/sql"

  setup(tags) do
    cond do
      tags[:extra_config] ->
        @default_config
        |> Keyword.merge(tags[:extra_config])
        |> put_config()

      tags[:secret] ->
        @default_config
        |> Keyword.put(:secret, "secret")
        |> put_config()

      tags[:default] ->
        put_config(@default_config)

      true ->
        remove_config()
    end

    :ok
  end

  describe "global config" do
    @describetag :default

    test "new/0 creates a new client" do
      assert_client(Rest.new(), "https://dne", "token")
    end

    @tag :secret
    test "new/0 prefers to generate token" do
      client = Rest.new()
      assert get_token(client) != Keyword.get(@default_config, :token)
    end

    @tag :secret
    test "new/0 defaults exp to 2 hours" do
      two_hours_from_now = Joken.current_time() + 2 * 60 * 60
      assert %{"exp" => ^two_hours_from_now} = token_claims(Rest.new())
    end

    @tag extra_config: [secret: "secret", claims: %{foo: "bar"}]
    test "new/0 adds claims to generated token" do
      assert %{"foo" => "bar"} = token_claims(Rest.new())
    end

    test "new/1 overrides global config" do
      assert_client(
        Rest.new(url: "https://other", token: "my-token", user_agent: "my-ua"),
        "https://other",
        "my-token",
        "my-ua"
      )
    end

    @tag :secret
    test "new/1 can override exp claim" do
      assert %{"exp" => 1234} = token_claims(Rest.new(claims: %{exp: 1234}))
    end
  end

  describe "no global config" do
    test "new/0 raises when no base_url specified" do
      assert catch_error(Rest.new()) == err(":base_url not configured for Cubex.Rest")
    end

    test "new/1 raises when no token specified" do
      assert catch_error(Rest.new(url: "https://foo")) ==
               err(":token not configured for Cubex.Rest")
    end

    test "new/1 returns client when token and url provided" do
      assert_client(
        Rest.new(url: "https://foo", token: "t"),
        "https://foo",
        "t"
      )
    end

    test "new/1 allows user agent to be provided" do
      assert_client(
        Rest.new(url: "https://foo", token: "t", user_agent: "foo"),
        "https://foo",
        "t",
        "foo"
      )
    end

    test "new/1 returns client with default exp when secret and url provided" do
      client = Rest.new(url: "https://foo", secret: "secret")
      two_hours_from_now = Joken.current_time() + 2 * 60 * 60
      assert %{"exp" => ^two_hours_from_now} = token_claims(client)
    end
  end

  describe "rest functions" do
    @describetag :default

    setup do
      {:ok, client: Rest.new()}
    end

    test "load/3 returns body on success", %{client: client} do
      mock_load(%{"1" => "2"})
      assert {:ok, %{"1" => "2"}} == Rest.load(client, %{})
    end

    test "load/2 returns body on success", %{client: client} do
      mock_load(%{"data" => "data"})
      assert {:ok, %{"data" => "data"}} == Rest.load(client, %{})
    end

    test "load/2 sets request id header", %{client: client} do
      mock_load(
        %{"data" => "data"},
        200,
        header_validator("x-request-id", "-span-1", &String.ends_with?/2)
      )

      Rest.load(client, %{})
    end

    test "load/3 returns body on failure", %{client: client} do
      mock_load(%{"error" => "blah"}, 500)
      assert {:error, %{"error" => "blah"}} == Rest.load(client, %{})
    end

    test "load/3 returns error on failure non-http failure", %{client: client} do
      mock(fn _ -> {:error, :timeout} end)
      assert {:error, :timeout} == Rest.load(client, %{})
    end

    test "load/3 will wait until slow query returns", %{client: client} do
      mock(fn
        %{method: :post, url: @load_url, headers: [{"x-request-id", "test-span-3"} | _]} ->
          # respond with data on 3rd sequence
          {200, [], %{"data" => "data"}}

        %{method: :post, url: @load_url} ->
          {200, [], %{"error" => "Continue wait"}}
      end)

      assert {:ok, %{"data" => "data"}} = Rest.load(client, %{}, request_id: "test")
    end

    test "load/3 returns continue wait when disabled", %{client: client} do
      mock_load(%{"error" => "Continue wait"})
      assert {:ok, %{"error" => "Continue wait"}} == Rest.load(client, %{}, continue_wait: false)
    end

    test "meta/2 returns body on success", %{client: client} do
      mock_meta(%{"data" => "data"})
      assert {:ok, %{"data" => "data"}} == Rest.meta(client)
    end

    test "meta/2 sets request id header", %{client: client} do
      mock_meta(
        %{"data" => "data"},
        200,
        header_validator("x-request-id", "-span-1", &String.ends_with?/2)
      )

      Rest.meta(client)
    end

    test "meta/2 allows overriding request and sequence id", %{client: client} do
      mock_meta(%{"data" => "data"}, 200, header_validator("x-request-id", "test-span-24"))
      Rest.meta(client, request_id: "test", sequence_id: 24)
    end

    test "meta/2 returns body on failure", %{client: client} do
      mock_meta(%{"error" => "error"}, 500)
      assert {:error, %{"error" => "error"}} == Rest.meta(client)
    end

    test "meta/2 accepts the :extended option", %{client: client} do
      mock_meta(%{"data" => "data"}, 200, fn %{query: q} ->
        assert Map.get(q, :extended)
      end)

      Rest.meta(client, extended: true)
    end

    test "meta/2 omits :extended by default", %{client: client} do
      mock_meta(%{"data" => "data"}, 200, fn %{query: q} ->
        refute Map.has_key?(q, :extended)
      end)

      Rest.meta(client)
    end

    test "meta/2 omits :extended if false", %{client: client} do
      mock_meta(%{"data" => "data"}, 200, fn %{query: q} ->
        refute Map.has_key?(q, :extended)
      end)

      Rest.meta(client, extended: false)
    end

    test "sql/3 returns body on success", %{client: client} do
      mock_sql(%{"data" => "data"})
      assert {:ok, %{"data" => "data"}} == Rest.sql(client, %{})
    end

    test "sql/3 returns body on failure", %{client: client} do
      mock_sql(%{"error" => "error"}, 500)
      assert {:error, %{"error" => "error"}} == Rest.sql(client, %{})
    end

    test "sql/3 sets request id header", %{client: client} do
      mock_sql(
        %{"data" => "data"},
        200,
        header_validator("x-request-id", "-span-1", &String.ends_with?/2)
      )

      Rest.sql(client, %{})
    end

    test "sql/3 allows overriding request and sequence id", %{client: client} do
      mock_sql(%{"data" => "data"}, 200, header_validator("x-request-id", "test-span-24"))
      Rest.sql(client, %{}, request_id: "test", sequence_id: 24)
    end
  end

  defp mock_sql(body, status \\ 200, validator \\ &default_validator/1) do
    mock_endpoint(:post, @sql_url, body, status, validator)
  end

  defp mock_meta(body, status \\ 200, validator \\ &default_validator/1) do
    mock_endpoint(:get, @meta_url, body, status, validator)
  end

  defp mock_load(body, status \\ 200, validator \\ &default_validator/1) do
    mock_endpoint(:post, @load_url, body, status, validator)
  end

  defp mock_endpoint(req_method, req_url, resp_body, resp_status, validator) do
    mock(fn env = %{method: ^req_method, url: ^req_url} ->
      validator.(env)
      {resp_status, [], resp_body}
    end)
  end

  defp header_validator(key, value, value_comparator \\ &Kernel.==/2) do
    fn %{headers: headers} ->
      assert Enum.any?(headers, fn {k, v} -> k == key and value_comparator.(v, value) end)
    end
  end

  defp default_validator(_), do: :ok

  defp err(message) do
    %RuntimeError{message: message}
  end

  defp token_claims(client) do
    %JOSE.JWT{fields: fields} =
      client
      |> get_token()
      |> JOSE.JWT.peek_payload()

    fields
  end

  defp get_token(client) do
    Enum.at(client.pre, 1)
    |> elem(2)
    |> List.first()
    |> List.first()
    |> elem(1)
  end

  defp assert_client(client, url, token, user_agent \\ "cubex") do
    assert %Tesla.Client{
             pre: [
               {Tesla.Middleware.BaseUrl, :call, [^url]},
               {Tesla.Middleware.Headers, :call,
                [[{"authorization", ^token}, {"user-agent", ^user_agent}]]},
               {Tesla.Middleware.Retry, :call, [[should_retry: _]]},
               {Tesla.Middleware.JSON, :call, [[]]}
             ]
           } = client
  end

  defp put_config(opts) do
    Application.put_env(:cubex, Cubex.Rest, opts)
  end

  defp remove_config() do
    Application.delete_env(:cubex, Cubex.Rest)
  end
end
