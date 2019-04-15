defmodule Ptolemy do
  @moduledoc """
  `Ptolemy` provides client side functions calls to fetch, sets and update secrets and environment variables within a remote backend.

  # Configurating the remote backend
  Before using the `Ptolemy` module, ensure you have the `:vaults` configuration block configured.

  Each key within the `:vaults` block configures **one** remote vault server backend.
  You can chose to name this key what ever you wish. The key's value is of type map.

  Within the actual server configuration block, the top level keys follows a specific schema:
    - `:vault_url` **(Required)** - A string representing the url of the remote vault server.
    - `:engines` - The engines list configuration, all your engines
          configuration needs be store in here. (See ** Configuring the `:engines` block ** for more detail)
    - `:auth` **(Required)**  - A Map containing the necessary information to authenticate against
          a remote vault server. (See ** Configuring the `:auth` block ** for more detail)

  # Configuring the `:engines` block
  The `:engines` block is  a keyword list containing engine specific configuration data, which allows for a more friendlier
    interface with Ptolemy's APIs.
    - The keys in the list can be arbitrarily named.
    - Values associated with the keys must be of type map with the following keys:
      - `:engine_type` (*Required*) the engine type must be one of `:GCP`, `:KV` or `:PKI` (as of v0.2)
      - `:engine_path` (*Required*) the engine path string, the value will need to  always needs to end with a `/`.
      - `:secrets` (*Required only for `:KV`*) a map of the secrets contained in the engine, this should *only* be specified if a `:KV` engine is specified.
      - `:roles` (*Required only for `:PKI`*) a map of the roles contained in the enigne, this should *only* be specified if a `:PKI` engine is specified.

  # Configuring the `:auth` block
  The `:auth` key found within the server configuration block instructs and provide the necessary information
  for a successful authentication against a remote vault server.

  ### The `:method` key
  **(Required)** - Specifies the type of auth method ptolemy will try to auth with. One of either (as of version 0.2 and above):
    - `:GCP`
    - `:Approle`

  ### The `:credentials` key
  **(Required)** - A map containing all necessary information concerning auth. Depending on the
    authentication method the `:credentials` map will have a different keys.
    - If `:Approle` auth method is specified the `:crendentials` map's schema **will need** to contain the following keys:
      - `:role_id` - String representation of the role id.
      - `:secret_id` - String representation of the secret id.
    - If `:GCP` auth method is specified the `:crendentials` map's schema **will need** to contain the following keys:
      - `:gcp_acc_svc` - The **base64** string represention of ther GCP service account.
      - `:vault_role` - String representation of the vault role associated with the login.
      - `:exp` - The integer representation of the validity period for the JWT that will be summited to the
          remote vault server. Google's maximum validity perriod is 3600 seconds.

  ### The `:auto_renew` key
  **(Required)** A boolean indicating if you want the `X-Vault-Token` to be auto-renewed when expiry
    is near. The Vault token will always be renewed 5 seconds prior to expiry.

  ### The `:opts` key
  **(Required)**  A keyword list with additional options. As of version 0.2 the only options currently available
    are for the configuration to authenticate against Google's Cloud Identity Aware Proxy. The following keys are required
    if you desire to use such options:
    - `:iap_svc_acc` has 2 valid associated values: specifying the `:reuse` atom will tell ptolemy to reuse the `:gcp_svc_acc`
        specified in the credentials block (that service account will need the correct IAM permissions for IAP).
        If `:reuse` is not specified a base64 string representation of the service account that has the valid IAM permissions will
        need to be provided.
    - `:client_id` The string representation of the client_id of the OAuth client protecting the resource.
        Can be found in Security -> Identity-Aware-Proxy -> Select the IAP resource -> Edit OAuth client.
    - `:exp`  The integer representation of the validity period for the JWT that will be summited to  Google.
        Google's maximum validity perriod is 3600 seconds.

  # Configuration Examples:
  Example configuration can be seen in `config/test.exs` or even in `examples/simple/config/config.exs`.
  """
  require Logger

  alias Ptolemy.Server

  @doc """
  Start a process and store all necessary state for a connection to a remote vault server.

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
  Create a secret in Vault.

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
  @spec create(atom(), atom(), [any]) :: :ok | {:ok, any()} | {:error, any()}
  def create(pid, engine_name, opts \\ []) do
    Kernel.apply(Module.concat(Ptolemy.Engines, get_engine_type!(pid, engine_name)), :create, [
      pid,
      engine_name | opts
    ])
  end

  @doc """
  Read a secret's key and value from a defined location.

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
  @spec read(atom(), atom(), [any]) :: :ok | {:ok, any()} | {:error, any()}
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
  ```

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
  @spec update(atom(), atom(), [any]) :: :ok | {:ok, String.t()} | {:error, String.t()}
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
  ```

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
  @spec delete(atom(), atom(), [any]) :: :ok | {:ok, String.t()} | {:error, String.t()}
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
      {:error, _msg} ->
        raise "#{pid} does not have a engine config for #{engine_name}"

      :error ->
        raise "Could not find :engine_type in engine_conf"
    end
  end
end
