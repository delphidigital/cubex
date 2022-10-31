defmodule CubexTest do
  use ExUnit.Case
  doctest Cubex

  import Tesla.Mock

  setup do
    mock(fn _ -> json(%{"data" => "data"}) end)
    Application.put_env(:cubex, Cubex.Rest, base_url: "https://dne", token: "token")
    {:ok, client: Cubex.new()}
  end

  test "load/3", %{client: client} do
    assert {:ok, %{"data" => "data"}} = Cubex.load(client, %{})
  end

  test "meta/2", %{client: client} do
    assert {:ok, %{"data" => "data"}} = Cubex.meta(client)
  end

  test "sql/3", %{client: client} do
    assert {:ok, %{"data" => "data"}} = Cubex.sql(client, %{})
  end
end
