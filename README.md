<p align="center"> 
  <img src="./assets/logo.svg" height="100%" width="100%"/>
  <a href= "https://travis-ci.org/azohra/ptolemy"><img src="https://travis-ci.org/azohra/ptolemy.svg?branch=master"></a>
  <a href= "https://hex.pm/packages/ptolemy"><img src="https://img.shields.io/hexpm/v/ptolemy.svg"/></a>
  <img src="https://img.shields.io/hexpm/l/ptolemy.svg"/>
</p>

---
Ptolemy is an application environment manager for your Elixir projects. It mainly has two use cases:

1. A simple to use configuration based Vault client that supports authentication and CRUD operations.
2. Dynamic application environment variable loader that loads secrets from a remote backend such as Hashicorp's Vault and handle its lifecycle by refreshing the secret when they are about to expire.

Tested against Vault V0.11.5 but Ptolemy should support Vault V0.10.4 or later.

## Features
- [Application environment management](https://hexdocs.pm/ptolemy/0.2.0/Ptolemy.Loader.html#content). 
- Authentication through Google's [Cloud IAP](https://cloud.google.com/iap/)
- [Hashicorp Vault](https://github.com/hashicorp/vault) integration:
  - Supported authentication methods:
    - GCP
    - GCP with IAP
    - Approle
  - Supported secret engines:
    - Key-Value Version 2 (KV2) 
    - Public Key Infrastructure (PKI)
    - Google Cloud Platform (GCP)

## Installation
Ptolemy is available on hex you can install it by following these steps:

1. Add ptolemy to your `deps`
```elixir
def deps do
  [
    {:ptolemy, "~> 0.2.0"}
  ]
end
```
2. Run `mix deps.get && mix deps.compile`

## Configuration

There are two configuration blocks that exist in ptolemy as of version `0.2`. Both are independent of one another and do not have to be used at the same time.

1. `:vaults` configuration is responsible for holding the Vault server configurations
2. `:loader` configuration manages the dynamic loading of secrets from providers, e.g. Vault, System Environment

In order to get the most of the library, we recommend to configrure both blocks. An example configuration file can be found in `config/test.exs`

### Configuring `:vaults`
The `:vaults` key configure's ptolemy various backend providers(Hashicorp vault is the only backend currently supported). Each key within the `:vaults` block represents a specific server in which ptolemy can query to retrieve values such as application secrets currently stored in vault.

```elixir
config :ptolemy, vaults: [
  server_name: %{
    vault_url: "",
    auth: %{
      method: :Approle,
      credentials: %{
        role_id: "",
        secret_id: ""
      },
      opts: []
    },
    engines: [
      engine_name: %{
        type: :KV,
        engine_path: "path/",
        secrets: %{
          secret_name: "/secret-path"
        }
      }
    ]
  }
]
```
Additional details about usage within the `:vaults` configuration block can be found in the [documentations](https://hexdocs.pm/ptolemy/0.2.0/Ptolemy.html#content).

### Configuring `:loader`
If `Ptolemy.Loader` is being used to dynamically manage appplication environment variables, then an extra configuration block should also be added:

Sepcifying this block will allow `Ptolemy.Loader` to populate the application specific env vars at runtime.

```elixir
  config :ptolemy, loader: [
    env: [
      {{:app_name, :secret_key}, {Ptolemy.Providers.SystemEnv, "PATH"}},
      {{:app_name, :another_secret_key}, {Ptolemy.Providers.Vault, [:engine_name, [opt1, opt2], [key1, key2]]}},
      # ...
    ]
  ]
```
Additional details about usage the keys within the `:loader` configuration block can be found in the [documentations](https://hexdocs.pm/ptolemy/0.2.0/Ptolemy.Loader.html#content). 

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

## FAQ

1. What do I do if I get `Authentication Failed` with error `role requires that JWTs must expire within 900 seconds` for GCP authentication?

There is something wrong with your system time, please make sure that you are using a reputable Network Time Protocol (NTP) server as your time provider.