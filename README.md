<p align="center"> 
  <img src="./assets/logo.svg" height="100%" width="100%"/>
</p>

---
Ptolemy is an application that allows your elixir app to use [hashicorp's vault](https://github.com/hashicorp/vault) to store and manage application secrets. Designed with simplicity in mind, ptolemy simplifies the vault api and features advanced features such as authentication through cloud iap.

## Currently Supported Features
- Authenticates to vault via:
  - **Google Cloud** auth method
  - **Approle** auth method

- Authentication through Google's [Cloud IAP](https://cloud.google.com/iap/)

- Supported secret engines
  - KV V2 secret engine
  - More to come!

## Installation
Ptolemy is available on hex you can install it by following these steps:

1. Add ptolemy to your `deps`
```elixir
def deps do
  [
    {:ptolemy, "~> 0.1.0"}
  ]
end
```
2. Run `mix deps.get && mix deps.compile`

## Usage
You will first need to edit your `config/config.exs` to include a configuration (visit `Ptolemy` module to find more configuration options) block such as:
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
      iap_on: false,
      exp: 6000
    ]
  }.
  server2: %{...}
  ```

  It is recommended that you start a ptolemy process via a supervised process such as:
  ```elixir
  def application do
    worker(Ptolemy.Server, [:pid, :server1]),
  end
  ```
  Additionally you could provide runtime configuration by specifying an extra keyword list when you start Ptolemy.
  ```elixir
  def application do
    worker(Ptolemy.Server, [:pid, :server1, [credentials: %{role_id: "test", secret_id: "test"}, opts: []]]),
  end
  ```

 Once you configure and start the application, you have access to simple getters and setters, like: 
  ```elixir
  iex(1)> {:ok, server} = Ptolemy.start(:production, :server1)
  {:ok, <#PID<0.213.0>}}
  iex(2)> server |> Ptolemy.kv_cread(:kv_engine1, :ptolemy, "foo")
  {:ok, "test"} # not a real secret, or is it???? 乁( ͡° ͜ʖ ͡°)ㄏ
  iex(3)> server |> Ptolemy.kv_read("secret/data/ptolemy", "foo")
  {:ok, "test"} 
  ```

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


## Road Map

1. Restructure Ptolemy to support genric engines
2. Load secrets into application according to config file
3. Improve performance of Vault fetch operations 
4. Add engine support for
  - Key/Value V2 (Done)
    - The kv secret engine is used to store versioned key value pair secrets. Of course, you may use it as non-versioned if you wish. Our implementation contains a full set of operations to manipulate secrets. This engine is mostly done, thanks to @brsmsn
  - GCP (WIP)
    - This is a dynamic secret engine that generates short term Google Cloud service account keys and OAuth tokens based on IAM. It provides security advantages including short-term access and service key cleaning. Our support will provide account keys and tokens retrieval and updating functionalities.
  - Cubbyhole (Planned)
    - The cubbyhole secrets engine is used to store arbitrary secrets within the configured physical storage for Vault namespaced to a token. In cubbyhole, paths are scoped per token.
  - PKI (Planned)
    - The PKI secrets engine generates dynamic X.509 certificates.
  - TOTP (Panned)
    - The TOTP secrets engine generates time-based credentials according to the TOTP standard
  - Databases (Planned)
    - The database secrets engine generates database credentials dynamically based on configured roles.
  - AWS (Bonus)
    - TBD due to lack of internal demand, but AWS engine implementation will be similar to GCP engine's.
5. Feel free to tell us what features do you want with Ptolemy by opening an issue

Please find more details regarding our redesign in `docs/README.md`