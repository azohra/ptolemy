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
<<<<<<< HEAD
2. Add engine support for
=======
2. Load secrets into application according to config file
3. Improve performance of Vault fetch operations 
4. Add engine support for
>>>>>>> origin/refactor/kv-binding
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
<<<<<<< HEAD

3. Feel free to tell us what features do you want with Ptolemy by opening an issue


### Restructure Proposal

When we were designing Ptolemy, we envisioned it to be not just a wrapper application that simplifies the communication with Vault in a programmatic way. It also provides capability to load the secrets into your application environment and updating the secrets according to their ttl if available.

User has the choice of communicating directly with the CRUD interface of Ptolemy, which fetches secret from vault and allows manipulations on the secrets, these functions provide users with a great degree of flexibility. However, if you are looking for a convenient and performant way of accessing secrets, you are in luck. We offer a robust secret loading functionalities. You can provide secrets that you would like to fetch from the Vault in config files, and Ptolemy would handle the repetitive task of loading secrets into your application environment like magic! It even takes care of refreshing the secret when they expire.

We are trying to restructure Ptolemy in order to make it generic enough to support various secret engines, thus the folder structure would need a overhaul. Here is a proposal on how the repository should look like.

#### Current
```
Ptolemy/
├── config
│   └── config.exs
├── lib
│   ├── engines
│   │   └── kv.ex
│   ├── ptolemy.ex
│   ├── ptolemy_server.ex
│   └── ...
└── ...
```

Currently, `ptolemy_server.ex` contains CRUD operations for kv engine specifically, and `lib/engine/kv.ex` contains the communication interface for kv engine.

#### Proposal
```
Ptolemy/
├── config
│   ├── secrets.exs
│   └── config.exs
├── lib
│   ├── engines
│   │   ├── kv
│   │   |   ├── kv_server.ex
│   │   |   └── kv.ex
│   │   ├── gcp
│   │   |   ├── gcp_server.ex
│   │   |   └── gcp.ex
│   │   └── ...
│   ├── stores
│   │   ├── cache.ex
│   │   ├── genserver
│   │   |   └── genserver.ex
│   │   └── ...
│   ├── ptolemy.ex
│   ├── ptolemy_server.ex
│   ├── ptolemy_store.ex
│   └── ...
└── ...
```

`secrets.exs` will be the place for you to configure the secrets you want to have Ptolemy loaded into the application
```elixir
config :ptolemy, Secrets,
  server1: %{
    kv_engine1: [
      %{
        app: :ptolemy,
        key: :token,
        vault_key: "token"
      },
      %{
        app: :ptolemy,
        key: :another_token,
        vault_key: "another_token"
      }
    ]
  }
```

`ptolemy_server.ex` will only contain a generic CRUD functions for users to interact, each function should take in the engine name as a parameter in order to pattern match with the correct support engine to call.  The underneath implementation of CRUD operations should lie within `lib/engines` folder. For example, `kv.ex` would still contain the communication functions, and `kv_server.ex` would be responsible for making the `ptolemy.ex` functions happen.

#### ptolemy.ex

```elixir
defmodule Ptolemy do
  @doc start Ptolemy process
  def start(name, config) do
    Server.start_link(name, config)
  end

  @doc create secrets
  def create(pid, engine_name, secret, payload, opts // []) do
    # ...
  end

  @doc fetches all secrets from a specified path
  def fetch(pid, engine_name,  secret, opts // []) do
    # ...
  end

  @doc read one specific secret from the path
  def read(pid, engine_name, secret, secret_name, opts // []) do
    # ...
  end

  @doc update a secret
  def update(pid, engine_name, secret, payload, opts // []) do
    # ...
  end

  @doc move a secret into recycle bin
  def delete(pid, engine_name, secret, opts // []) do
    # ...
  end

  @doc destroy a secret completely
  def destroy(pid, engine_name, secret, opts // []) do
    # ...
  end
end
```
=======
5. Feel free to tell us what features do you want with Ptolemy by opening an issue

Please find more details regarding our redesign in `docs/README.md`
>>>>>>> origin/refactor/kv-binding
