defmodule Cubex.Base do
  @type cube_client_config :: [token: String.t(), url: String.t()]
  @opaque client :: Tesla.Client.t()

  @type error_response :: {:error, any()}
  @type success_response :: {:ok, map()}
  @type api_response :: success_response() | error_response()

  @callback new() :: client()
  @callback new(config :: cube_client_config()) :: client()

  @callback load(client :: client(), query :: map()) :: api_response()
  @callback load(client :: client(), query :: map(), opts :: Keyword.t()) :: api_response()

  @callback meta(client :: client()) :: api_response()
  @callback meta(client :: client(), opts :: Keyword.t()) :: api_response()

  @callback sql(client :: client(), query :: map()) :: api_response()
  @callback sql(client :: client(), query :: map(), opts :: Keyword.t()) :: api_response()
end
