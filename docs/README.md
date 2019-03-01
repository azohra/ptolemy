# Ptolemy <small>- Elixir Application Secret Management</small>

> This document is designed to facilitate and grow with design discussions and is not yet complete

Ptolemy is now at a current stage where our thinking goes beyond the simple accessing and updating of secrets stored in a Vault server. For the idea of Application Managed secrets to fully be an accepted practice in the Elixir community, an effective and elegant solution will need to be built. We hope Ptolemy can fill this void.

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
│   │   ├── genserver
│   │   |   └── genserver.ex
│   │   └── ...
│   ├── ptolemy.ex
│   ├── ptolemy_server.ex
│   ├── ptolemy_store.ex
│   └── ...
└── ...
```

##### stores/cache.ex
`stores/cache.ex` will be responsible for loading secrets from Vault into Cache. We are still figuring out whether we should also load the secret into Application environment and takes care of the ttls here or in a separate module. I'm leaning towards a another `load` module that manages it.

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


Notes:
We were considering developing a Ptolemy.Supervisor that restarts process in order to reload the application environment

But, we've reached the consensus that it's unnecessary to implement the Ptolemy supervisor which crashes the process in order to update the application's environment variables.

Reasons are as follow:

1. Forcing our users to use Ptolemy.Supervisor is an over opinionated way of managing application variables. It would require users to give up control to the restart process.
2. If the user follow the OTP restart practices, they would save the states, including the environment variables, when the process gets terminated. Thus, even letting it crash and reloading the application would not be able refresh their tokens. The application would just keep using the old secrets and keep crashing.

Considering factors above, we will be scrapping the Ptolemy.Supervisor module and Ptolemy will not be responsible for managing lifecycle of applications that stores secrets in their states. Ptolemy will only update secrets in the Applications environment variables as they expire. In order to utilize full capability of Ptolemy, we strongly recommend users to use Application.get_env() and NOT store secrets in states.
