<p align="center"> 
  <img src="./assets/logo.svg" height="100%" width="100%"/>
  <a href= "https://travis-ci.org/azohra/ptolemy"><img src="https://travis-ci.org/azohra/ptolemy.svg?branch=master"></a>
  <a href= "https://hex.pm/packages/ptolemy"><img src="https://img.shields.io/hexpm/v/ptolemy.svg"/></a>
  <img src="https://img.shields.io/hexpm/l/ptolemy.svg"/>
</p>

---
Ptolemy is an application environment manager for your Elixir projects. It provides a simple interface to authenticate and interact (via CRUD operations) with a remote backend that stores secrets and sensitive information. As well as providing these functionality Ptolemy also features a dynamic application environment variable loader that loads secrets from a remote backend such as Hashicorp's Vault and handle its lifecycle by refreshing the secret when they are about to expire.

## Features
- [Application environment management](https://hexdocs.pm/ptolemy/0.2.0/Ptolemy.Loader.html#content). 
- Authentication through Google's [Cloud IAP](https://cloud.google.com/iap/)
- [Hashicorp Vault](https://github.com/hashicorp/vault) integration (tested against Vault v0.11.5 but will support v0.10.4 and later):
  - Supported authentication methods:
    - GCP
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

## Example Usage
### Intergrating Ptolemy With Your Project
Within `examples/` we provide an example repository called Simple app. The configuration file in the project shall be served as an example for key values and PKI engine. More configuration specifications can be found in the *Configuration* section below.

Follow the `README.md` found in `examples/` instructions to get started.

### Example CLI usage
You will need to configure the application to point to remote backend. Edit the `config.exs` to point to remote backend.

Start iex with Ptolemy's modules loaded by entering:
```bash
bash-3.2$ cd ptolemy/ && iex -S mix
Erlang/OTP 21 [erts-10.1.2] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:1] [hipe] [dtrace]

Interactive Elixir (1.7.4) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> {:ok, server} = Ptolemy.start(:server1, :production)
iex(2)> Ptolemy.read(server, :kv_engine1, [:ptolemy, true])
{:ok, %{"test" => "foo"}}
```

## Configuration
There are two configuration blocks that exist in ptolemy as of version `0.2`. Both are independent of one another and do not have to be used at the same time.

1. `:vaults` configuration is responsible for holding the Vault server configurations
2. `:loader` configuration manages the dynamic loading of secrets from providers, e.g. Vault, System Environment

In order to get the most of the library, we recommend to configrure both blocks. Example configuration files can be found in `config/test.exs`, `examples/config/config.exs`.

### Configuring `:vaults`
The `:vaults` key configures ptolemy various backend providers (Hashicorp vault is the only backend currently supported). Each key within the `:vaults` block represents a specific server in which ptolemy can query to retrieve values such as application secrets currently stored in vault.

```elixir
config :ptolemy, vaults: [
  server2: %{
    vault_url: "https://test-vault.com",
    engines: [
      kv_engine1: %{
        engine_type: :KV,
        engine_path: "secret/",
        secrets: %{
          test_secret: "/test_secret"
        }
      },
      gcp_engine1: %{
        engine_type: :GCP,
        engine_path: "gcp/"
      },
      pki_engine1: %{
        engine_type: :PKI,
        engine_path: "pki/",
        roles: %{
            test_role1: "/role1"
          }
      }
    ],
    auth: %{
      method: :Approle,
      credentials: %{
        role_id: "test",
        secret_id: "test"
      },
      auto_renew: true,
      opts: []
    }
  }
]
```
Additional details about usage within the `:vaults` configuration block can be found in `Ptolemy`'s module docs.

### Configuring `:loader`
If `Ptolemy.Loader` is being used to dynamically manage application environment variables, then an extra configuration block should also be added:

Specifying this block will allow `Ptolemy.Loader` to populate the application specific env vars at runtime.

```elixir
  config :ptolemy, loader: [
    env: [
      {{:app_name, :secret_key}, {Ptolemy.Providers.SystemEnv, "PATH"}},
      {{:app_name, :another_secret_key}, {Ptolemy.Providers.Vault, [:engine_name, [opt1, opt2], [key1, key2]]}},
      # ...
    ]
  ]
```
Additional details about usage the keys within the `:loader` configuration block can be found in `Ptolemy.Loader`'s module doc.

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

## Troubleshooting

What do I do if I get `Authentication Failed` with error `role requires that JWTs must expire within X seconds` for GCP authentication?

> There is something wrong with your system time, please make sure that you are using a reputable Network Time Protocol (NTP) server as your time provider or force an update for you system type.