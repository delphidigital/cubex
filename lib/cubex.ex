defmodule Cubex do
  @behaviour Cubex.Base

  @moduledoc """
  Implementation independent cube client library. 
  """

  @doc """
  Create a new cube client. Takes an optional keyword list of parameters.
  See the implementation libraries for details (ie `Cube.Rest`)
  """
  @impl Cubex.Base
  def new(opts \\ []) do
    impl().new(opts)
  end

  @doc """
  Load data from cube.
  """
  @impl Cubex.Base
  def load(client, query, opts \\ []) do
    impl().load(client, query, opts)
  end

  @doc """
  Fetch cube metadata.
  """
  @impl Cubex.Base
  def meta(client, opts \\ []) do
    impl().meta(client, opts)
  end

  @doc """
  Fetch SQL from cube.
  """
  @impl Cubex.Base
  def sql(client, query, opts \\ []) do
    impl().sql(client, query, opts)
  end

  #############
  # Private
  #############

  defp impl() do
    Application.get_env(:cubex, :client, Cubex.Rest)
  end
end
