<p align="center"> 
  <img src="https://raw.githubusercontent.com/azohra/ptolemy/master/assets/logo.svg" height="100%" width="100%"/>
</p>

---
Ptolemy is an application that allows your elixir app to use [hashicorp's vault](https://github.com/hashicorp/vault) to store and manage application secrets. Designed with simplicity in mind, ptolemy simplifies the vault api and features advance features such as authentication through cloud iap.

## Currently Supported Features
- Authenticates to vault via:
  - **Google Cloud** auth method
  - **Approle** auth method
- KV V2 secret engine support (more to come!)
- Authentication through Google's [Cloud IAP](https://cloud.google.com/iap/)

## Concepts
Ptolemy requires you to reorganize your vault KV secrets in a matter that treats secrets as being part of your application.

## Installation
Ptolemy is available on hex you can install it by following these steps:

1. Add ptolemy to your `deps`
```elixir
def deps do
  [
    {:ptolemy, "~> 0.1.0-alpha"}
  ]
end
```
2. Run `mix deps.get && mix deps.compile`

## Usage
You will first need to edit your `config/config.exs` to include a configuration block such as:
```elixir
config :ptolemy, Ptolemy,
  server1: %{
    vault_url: "http://localhost:8200",
    auth_mode: "approle",
    kv_engine: %{
      kv_engine1: %{
        engine_path: "secret/",
        secrets: %{
          ptolemy: "/ptolemy"
        }
      }
    },
    credentials: %{
      role_id: System.get_env("ROLE_ID"),
      secret_id: System.get_env("SECRET_ID")
    },
    opts: [
      role: "default",
      iap_on: false,
      exp: 6000
    ]
  }.
  server2: %{...}
  ```

  It is recommended that you start a ptolemy process via a suppervied process such as:
  ```elixir
  def application do
    worker(Ptolemy, [:server1]),
  end
  ```
 Once you configure and start the application, you have access to simple getters and setters, like: 
  ```elixir
  iex(1)> {:ok, server} = Ptolemy.start(:production, :server1)
  {:ok, <#PID<0.213.0>}}
  iex(2)> server |> Ptolemy.kv_read(:kv_engine1, :ptolemy, "foo")
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
