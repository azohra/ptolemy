# ptolemy

### ptolemy is still under development!

ptolemy is an application that allows your elixir app to natively integrate to [hashicorp's vault](https://github.com/hashicorp/vault).

## Features
- Authenticates to vault via:
  - **Google Cloud** auth method
  - **App Role** auth method
- Full KV secret engine support (more to come!)
- Authentication through Google's [Cloud IAP](https://cloud.google.com/iap/)

## Concepts
A remote vault server is represented by a Ptolemy process. Each process contains all necessary configuration to establish a connection with the intented remote vault server. This allows your application to connect to many different vault servers.

Ptolemy requires you to reorganize your vault KV secrets in a matter that treats secrets as being part of your application. Therefore your Key and Value should be in a folder named after your application.

## Installation
Ptolemy is available on hex you can install it by following these steps:

1. Add ptolemy to your `deps`
```elixir
def deps do
  [
    {:ptolemy, "~> 0.1.0-rc"}
  ]
end
```
2. Run `mix deps.get && mix deps.compile`
3. Start ptolemys by adding it to your supervision tree,
```elixir
def application do
  worker(Ptolemy, [:server1]),
end
```

## Usage
Edit your `config/config.exs` to include:
```elixir
config :ptolemy, Ptolemy,
  server1: %{
    vault_url: "http://localhost:8200",
    kv_path: "/secret/data",
    auth_mode: "approle",
    credentials: %{
      role_id: System.get_env("ROLE_ID"),
      secret_id: System.get_env("SECRET_ID")
    },
    opts: [
      role: "default",
      remote_server_cert: """
      -----BEGIN CERTIFICATE-----
      -----END CERTIFICATE-----
      """,
      iap_on: false,
      exp: 60
    ]
  }.
  server2: %{...}
  """
  ```
  Ptolemy allows your application to connect to multiple vault servers, just provide a map with the necessairy configuration.

  Once you configure the application, you have access to simple getters and setters, like: 
  ```elixir
  iex(1)> {:ok, server} = Ptolemy.start(:server1)
  {:ok, server}
  iex(2)> server |> Ptolemy.KV.get(:NAME_OF_SECRET_TOKEN) # Ptolemy.get(Ptolemy.KV, :NAME_OF_SECRET_TOKEN) also supported
  {:ok, "NsSgY+HlbriOyWucdHJk+7jn0k3wZ9lf/8JOtXpr9cc="} 
  # not a real secret, or is it???? 乁( ͡° ͜ʖ ͡°)ㄏ
  ```
  More configuration options and general architecture can be found in the hex docs.

  ## Development

  Running a local dev environment of ptolemy requires:
  - JQ
  - Docker and docker-compose

  Before developing you must issue these commands:
  1. Start up the dockerized version of vault via docker-compose
  ```bash
  $ docker-compose up
  ```
  2. In a different terminal issue:
  ```bash
  $ . ./vault_init.sh
  ```

  This will setup a local vault server accessible at `http://localhost:8200` along with setting up a the docker-composed vault server with a testing approle, the credentials for the role will be exported to your environment variable of the current shell used `SECRET_ID` and `ROLE_ID`.