# Ptolemy <small>- Elixir Application Secret Management</small>

> This document is designed to facilitate and grow with design discussions and is not yet complete

Ptolemy is now at a current stage where our thinking goes beyond the simple accessing and updating of secrets stored in a Vault server. For the idea of Application Managed secrets to fully be an accepted practice in the Elixir community, an effective and elegant solution will need to be built. We hope Ptolemy can fill this void. We envisioned Ptolemy to also provide capability of loading the secrets into your application environment and updating the secrets according to their ttl.

User has the choice of communicating directly with the CRUD interface of Ptolemy, which fetches secret from vault and allows manipulations on the secrets, these functions provide users with a great degree of flexibility. However, if you are looking for a convenient and performant way of accessing secrets, you are in luck. We offer a robust secret loading functionality. You can provide secrets that you would like to fetch from the Vault in config files, and Ptolemy would handle the task of loading secrets into your application environment like magic! It even takes care of refreshing the secret when they expire.

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
Currently, `ptolemy_server.ex` contains CRUD operations for kv engine specifically, and `lib/engine/kv.ex` contains the communication interface for kv engine. The structure is not flexible enough to add additional engine support. With modularized design in mind, we propose the following the structure.


#### Proposal
```
Ptolemy/
├── config
│   ├── (secrets.exs)
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
│   │   ├── behaviour.ex
│   │   ├── genserver
│   │   |   └── genserver.ex
│   │   └── ...
│   ├── loader
│   │   ├── loader.ex
│   │   └── refresher.ex
│   ├── ptolemy.ex
│   ├── ptolemy_server.ex
│   └── ...
└── ...
```

##### stores/cache.ex
`stores/cache.ex` will contain the functions that are responsible for loading secrets from Vault into a designated cache server.

#### stores/generver
`stores/generver` is a naive implementation of a cache server. User may choose to write their own cache server to substitute our default genserver as long as it follows the same behaviour.

#### loader/loader.ex
`loader/loader.ex` will provide functions that loads secrets from cache server to the application environment variables

#### loader/refresher.ex
`loader/refresher.ex` will be responsible for refetching the secret when their ttl expire


##### ptolemy.ex
`ptolemy.ex` will only contain a generic CRUD functions for users to interact, each function should take in the engine name as a parameter in order to pattern match with the correct support engine to call.  The underneath implementation of CRUD operations should lie within `lib/engines` folder. For example, `kv.ex` would still contain the communication functions, and `kv_server.ex` would be responsible for making the `ptolemy.ex` functions happen.

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

##### config/secrets.exs
We are currently considering two formats of letting users specify secrets

1. `config/secrets.exs`
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

2. `config/config.exs` the typical config file
```elixir
config :ptolemy,
	env: [
		{:secret_one, {Ptolemy.Providers.Vault.KeyVal, "VAULT_SECRET_NAME"}},
		{:secret_two, {Ptolemy.Providers.SystemEnv, "SOME_SYSTEM_ENV"}},
		# ...
	]
```