# Cubex

[Cube](https://cube.dev/) client for Elixir

## Installation

Adding `cubex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cubex, "~> 0.2.1"}
  ]
end
```

## Usage

The docs can be found at <https://hexdocs.pm/cubex>.

```elixir
# create a client using a jwt directly
client = Cubex.new(url: my_cube_base_url, token: my_cube_jwt)

# create a client using a secret, which generates jwts
client = Cubex.new(url: my_cube_base_url, secret: my_cube_api_secret)

# create a client using a secret with extra claims
client = Cubex.new(
  url: my_cube_base_url, 
  secret: my_cube_api_secret, 
  claims: %{"claimname" => "claimvalue"})

query = %{"dimensions" => ...}

# load data
{:ok, result} = Cubex.load(client, query)

# pass your own request id
{:ok, result} = Cubex.load(client, query, request_id: my_api_request_id)

# manually handle `Continue wait` in your own code
{:ok, result} = Cubex.load(client, query, 
  request_id: my_api_request_id, 
  sequence_id: 1,
  continue_wait: false) # defaults to true

case result do
  %{"error" => "Continue wait"} ->
    # make the same call again and increment the sequence_id
  data ->
    # got the data back, or a real error
end


# get the sql
{:ok, result} = Cubex.sql(client, query)

# fetch metadata
{:ok, result} = Cubex.meta(client)
```

## Configuration

`Cubex.Rest` uses [Tesla](https://hex.pm/packages/tesla) under the hood, so any Tesla options can be configured in your application configuration.

```elixir
# options can also be passed to new/1

# configure cubex rest with a token
config :cubex, Cubex.Rest,
  base_url: "https://my-cube-server",
  token: "jwt",
  user_agent: "MyCubeClient"

# configure cubex with a secret for generating jwts on the fly
config :cubex, Cubex.Rest,
  base_url: "https://my-cube-server",
  secret: "signing secret"

# override the underlying implementation. also useful for testing
config :cubex, :client, MyApp.CubexGraphql
```
