defmodule Ptolemy do
  @moduledoc """
  `Ptolemy` provides client side functions calls to fetch, sets and update secrets within a remote vault server.

  ## Configuration
    In order to properly use ptolemy, you must properly set a ptolemy configuration block. The configuration block must start with a key of type
    atom. It is recommended that the key be named after the remote vault server it is describing.

    The available configuration option are as follows:
    - `:vault_url` ::string **(Required)** - The url of the remote vault server.

    - `:auth_mode` ::string **(Required)** - The authentication method that ptolemy will try to do. As of `0.1.0`, `"GCP"` and `"approle"` are the only supported authentication methods.
    - `:engines` ::list - The engines list configuration, all your engines configuration should be store in here.
      - A key with an engine name will correspond to a map containing:
        - `:engine_type` ::atom - the engine type value should always be the same as the module that implements the engine, e.g. KV, GCP.
        - `:engine_path` ::string - The engine's path, always need to start with the name and end with a `/`.
        - `:secrets` ::map - The path of each secrets you wish to use. Note each secret will be a map in Vault

    - `:credentials` ::map **(Required)** - The sets of credentials that will be used to authenticate to vault
      - If you are using the Approle auth method:
        - `:role_id` ::string - The role ID to use to authenticate.
        - `:secred_id` ::string - The secret ID to use to authenticate.

      - If you are using the GCP auth method:
        - `:svc_acc` ::Based64 encoded string - The Google service account used to authenticate through IAP and/or vault.

       - In either case where you are using IAP you must provide `:target_audience` ::string - This is the client_id of the OAuth client
      protecting the resource. Can be found in Security -> Identity-Aware-Proxy -> Select the IAP resource -> Edit OAuth client.

    - `:opts` ::List - Optional list.
      - `:iap_on` ::boolean - Sets whether the remote vautl server has IAP protection or not. If you are using GCP auth method you must provide
        a service account credential with both `Service Account Token Creator` and `Secured IAP User`. If you are using the Approle auth method
        you must provide `:svc_acc` and a `:target_audience` (client_id of the IAP protected resource) within the `:credential` block.

      - `:exp` ::integer - The expiry of each access token (IAP - if enabled - and the vault token). The value has a default of 900 seconds(15 min), keep in mind
      the maximum time allowed for any google tokens is 3600 (1 hour), for vault that is entirely depended on what the administrator sets (default is 15min).

  ## Configuration Examples:
    - For an approle configuration
    ```elixir
    config :ptolemy, :vaults,
      server1: %{
        vault_url: "https://test-vault.com",
        engines: [
          kv_engine1: %{
            engine_type: :KV,
            engine_path: "secret/",
            secrets: %{
              test_secret: "/test_secret"
            }
          },
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
   ```
  """
  require Logger

  alias Ptolemy.Server
  @doc """
  Entrypoint of ptolemy, this will start the process and store all necessary state for a connection to a remote vault server.
  Please make sure the configuration for `server` exists in your confi file

  ## Example
  ```elixir
  iex(2)> {:ok, server} = Ptolemy.start(:production, :server1)
  {:ok, #PID<0.228.0>}
  ```
  """
  @spec start(atom | String.t(), atom) :: {:ok, pid} | {:error, String.t()}
  def start(name, config) do
    Server.start_link(name, config)
  end

  @doc """
  create secrets in Vault, but it is not responsible for adding these secrets into the application configuration.
  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  KV Engine
    1. secret (Required)
    2. payload (Required)
    3. cas (Optional, default: nil)

  ## Example
  ```elixir
  iex(1)> Ptolemy.create(server, :kv_engine1, [:test_secret, %{test: "foo"}])
  {:ok, "KV secret created"}
  ```

  GCP Engine
    1. roleset name (Required)
    2. roleset configuration payload(Required)

  ## Example
  ```elixir
  iex(1)> Ptolemy.create(server, :gcp_engine1, ["roleset_name", %{
    bindings: "bindings",
    project: "project-name",
    secret_type: "service_account_key"
  }])
  {:ok, "Roleset implemented"}
  ```

  PKI Engine
    1. role name (Required)
    2. role specifications (Optional)

  ## Example
  ```elixir
  iex(1)> Ptolemy.create(server, :pki_engine1, [:test_role1, %{allow_any_name: true}])
  {:ok, "PKI role created"}
  """
  @spec create(pid, atom, [any]) :: :ok | {:ok, any()} | {:error, any()}
  def create(pid, engine_name, opts \\ []) do
    Kernel.apply(Module.concat(Ptolemy.Engines, get_engine_type!(pid, engine_name)), :create, [
      pid,
      engine_name | opts
    ])
  end

  @doc """
  read all secrets from vault path

  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  KV Engine
    1. secret (Required)
    2. silent (Optional, default: false), use silent option if you want the data ONLY
    3. version (Optional, default: 0)

  ## Example
  ```elixir
  iex(2)> Ptolemy.read(server, :kv_engine1, [:ptolemy, true])
  {:ok, %{"test" => "foo"}}
  ```

  GCP Engine
    1. gcp secret type (Required)
    2. roleset name (Required)

  ## Example
  ```elixir
  iex(2)> Ptolemy.read(server, :gcp_engine1, [:service_account_key, "roleset_name"])
  {:ok, %{
    token: "shhh...",
    expires_at_seconds: 1537400046,
    token_ttl: 3599
    }}
  ```

  PKI Engine
    1. role name (Required)
    2. common name (Required) See vault docs for more details
    3. certificate specs (optional)
  
    ## Example
  ```elixir
  iex(2)> Ptolemy.read(server, :pki_engine1, [:test_role1, "www.example.com"])
  {:ok, %{
        "data" => %{
            "certificate" => "Certificate itself",
            "serial_number" => "5b:65:31:58"
        },
        "lease_duration" => 0}
  ```
  """
  @spec read(pid, atom, [any]) :: :ok | {:ok, any()} | {:error, any()}
  def read(pid, engine_name, opts \\ []) do
    Module.concat(Ptolemy.Engines, get_engine_type!(pid, engine_name))
    |> apply(:read, [pid, engine_name | opts])
  end

  @doc """
  Updates a secret

  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  KV Engine
    1. secret (Required)
    2. payload (Required)
    3. cas (Optional, default: nil)

  ## Example
  ```elixir
  iex(3)> Ptolemy.update(server, :kv_engine1, [:ptolemy, %{test: "bar"}])
  :ok

  GCP Engine
    1. roleset name (Required)
    2. roleset configuration payload (Required)

  See Ptolemy.Engines.GCP documentation for restrictions on updating rolesets

  ## Example
  ```elixir
  iex(3)> Ptolemy.update(server, :gcp_engine1, ["roleset_name", %{
    bindings: "bindings",
    project: "project-name",
    secret_type: "service_account_key"
  }])
  {:ok, "Roleset implemented"}
  ```

  PKI Engine
    1. role name (Required)
    2. new specifications (Optional) overwrite previous entirely

  See Ptolemy.Engines.GCP documentation for restrictions on updating rolesets

  ## Example
  ```elixir
  iex(3)> Ptolemy.update(server, :pki_engine1, [:test_role1, %{allow_any_name: true}])
  {:ok, "PKI role updated"}
  ```
  """
  @spec update(pid, atom, [any]) :: :ok | {:ok, any()} | {:error, any()}
  def update(pid, engine_name, opts \\ []) do
    Kernel.apply(Module.concat(Ptolemy.Engines, get_engine_type!(pid, engine_name)), :update, [
      pid,
      engine_name | opts
    ])
  end

  @doc """
  Delete a secret

  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  KV Engine
    1. secret (Required)
    2. vers (Required)
    3. destroy (Optional, default: false), destroy will leave no trace of the secret

  ## Example
  ```elixir
  iex(4)> Ptolemy.delete(server, :kv_engine1, [:ptolemy, [1]])
  :ok
  ```

  GCP Engine
    1. gcp secret type (Required)
    2. roleset name (Required)

  See Ptolemy.Engines.GCP documentation for more information regarding deleting GCP secrets

  ## Example
  ```elixir
  iex(4)> Ptolemy.delete(server, :gcp_engine1, [:access_token, "roleset_name"])
  {:ok, "Rotated"}

  PKI Engine
    1. delete type (Required) :role/:certificate
    2. arg1 (Required)
      a. :role -> role name
      b. :certificate -> serial number

  ## Example
  ```elixir
  iex(4)> Ptolemy.delete(server, :pki_engine1, [:certificate, "17:84:7f:5b:bd:90:da:21:16"])
  {:ok, "PKI certificate revoked"}
  iex(5)> Ptolemy.delete(server, :pki_engine1, [:role, :test_tole1])
  {:ok, "PKI role revoked"}
  ```
  """
  @spec delete(pid, atom, [any]) :: :ok | {:ok, any()} | {:error, any()}
  def delete(pid, engine_name, opts \\ []) do
    Kernel.apply(Module.concat(Ptolemy.Engines, get_engine_type!(pid, engine_name)), :delete, [
      pid,
      engine_name | opts
    ])
  end

  ################################################################################
  ##  Helper function used to determine what type does the engine correspond to ##
  ################################################################################
  defp get_engine_type!(pid, engine_name) do
    with {:ok, conf} <- Server.get_data(pid, :engines),
         {:ok, engine_conf} <- Keyword.fetch(conf, engine_name),
         {:ok, engine_type} <- Map.fetch(engine_conf, :engine_type) do
      engine_type
    else
      {:error, "Not found!"} -> raise "#{pid} does not have a engine config for #{engine_name}"
      {:error} -> raise "Could not find :engine_type in engine_conf"
    end
  end
end
