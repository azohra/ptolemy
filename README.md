<p align="center"> 
  <img src="./assets/logo.svg" height="100%" width="100%"/>
  <a href= "https://travis-ci.org/azohra/ptolemy"><img src="https://travis-ci.org/azohra/ptolemy.svg?branch=master"></a>
  <a href= "https://hex.pm/packages/ptolemy"><img src="https://img.shields.io/hexpm/v/ptolemy.svg"/></a>
  <img src="https://img.shields.io/hexpm/l/ptolemy.svg"/>
</p>

---
Ptolemy is an application environment manager. It can dynamically load specified application envs from a remote backend such as Hashicorp's Vault and handle its lifecycle. 

## Features
- [Application environment management](https://hexdocs.pm/ptolemy/0.2.0/Ptolemy.Loader.html#content). 
- Authentication through Google's [Cloud IAP](https://cloud.google.com/iap/)
- [Hashicorp Vault](https://github.com/hashicorp/vault) integration:
  - Supported authentication methods:
    - GCP
    - Approle
  - Supported secret engines:
    - KV V2 
    - PKI (WIP)
    - GCP (WIP)

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

There are two configuration blocks that exist in ptolemy as of version `0.2`. Both are independent of one another and do not have to be used at the same time, however to get the most out of this library you would want to configure both. 

### Configuring `:vaults`
The `:vaults` key configure's ptolemy various backend providers(Hashicorp vault is the only backend currently supported). Each key within the `:vaults` block represents a specific server in which ptolemy can query to retrieve values such as application secrets currently stored in vault.

```elixir
config :ptolemy, vaults: [
  server_name: %{
    vault_url: "",
    auth: %{
      method: :Approle,
      credentials: %{},
      opts: []
    },
    engines: [
      engine_name: %{
        type: :KV,
        pathName: "/path",
        #....
      }
    ]
  }
  # server_name2: %{...}
]
```
Additional details about usage the keys within the `:vaults` configuration block can be found it the [documentations](https://hexdocs.pm/ptolemy/0.2.0/Ptolemy.html#content). 

### Configuring `:loader`
If `Ptolemy.Loader` is being used to dynamically manage appplication environment variables, then an extra configuration block should also be added:

Sepcifying this block will allow `Ptolemy.Loader` to populate the application specific env vars at runtime.

```elixir
  config :ptolemy, loader: [
    env: [
      {{:app_name, :secret_key}, {SystemEnv, "PATH"}},
      # ...
    ]
  ]
```
Additional details about usage the keys within the `:loader` configuration block can be found it the [documentations](https://hexdocs.pm/ptolemy/0.2.0/Ptolemy.Loader.html#content). 

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