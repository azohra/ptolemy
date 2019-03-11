defmodule Ptolemy do
  @moduledoc """
  `Ptolemy` provides client side functions calls to fetch, sets and update secrets within a remote vault server.

  ## Configuration
    In order to properly use ptolemy, you must properly set a ptolemy configuration block. The configuration block must start with a key of type 
    atom. It is recommended that the key be named after the remote vault server it is describing.

    The available configuration option are as follows:
    - `:vault_url` ::string **(Required)** - The url of the remote vault server.

    - `:auth_mode` ::string **(Required)** - The authentication method that ptolemy will try to do. As of `0.1.0`, `"GCP"` and `"approle"` are the only supported authentication methods.
    
    - `:kv_engine` ::map - The kv engine block configuration, all your kv configuration should be store in here.
      - A key with an atom set to a KV engine name with its value being a map containing:
        - `:engine_path` ::string - The engine's path, always need to start with the name and end with a `/`.
        - `:secrets` ::map - The path of each secrets you wish to use. Note each 
    
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
    config :ptolemy, Ptolemy,
      production: %{
        vault_url: "http://localhost:8200",
        auth_mode: "approle",
        kv_engine1: %{
          engine_type: :kv_engine,
          engine_path: "secret/",
          secrets: %{
            ptolemy: "/ptolemy"
          },
          app_map: [
            var1: "test"
        ]
        },
        credentials: %{
          role_id: System.get_env("ROLE_ID"),
          secret_id: System.get_env("SECRET_ID")
        },
        opts: [
          iap_on: false,
          exp: 6000
        ]
      }
    ```
    - For a GCP configuration
    ```elixir
    config :ptolemy, Ptolemy,
      production: %{
        vault_url: "http://localhost:8200",
        auth_mode: "GCP",
        kv_engine1: %{
          engine_type: :kv_engine,
          engine_path: "secret/",
          secrets: %{
            ptolemy: "/ptolemy"
          },
          app_map: [
          var1: "test"
          ]
        }
        credentials: %{
          svc_acc: System.get_env("GOOGLE_SVC_ACC"),
          target_audience: System.get_env("TARGET_AUD") #Not required if :iap_on is false
        },
        opts: [
          iap_on: false,
          exp: 3600
        ]
      }
    ```
  """
  require Logger

  alias Ptolemy.Server
  alias Ptolemy.Engines.KV
  @doc """
  Entrypoint of ptolemy, this will start the process and store all necessary state for a connection to a remote vault server.
  Please make sure the configuration for `server` exists in your confi file

  ## Example
  ```elixir
  iex(2)> {:ok, server} = Ptolemy.start(:production, :server1)
  {:ok, #PID<0.228.0>} 
  ```
  """
  @spec start(atom, atom) :: {:ok, pid} | {:error, String.t()}
  def start(name, config) do
    Server.start_link(name, config)
  end

  @doc """
  create secrets in Vault, but it is not responsible for adding these secrets into the application configuration.
  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow
  
  :kv_engine
    1. secret (Required, path of the secret)
    2. payload (Required, content of the secret)
    3. cas (Optional, default: nil)

  ## Example
  ```elixir
  iex(1)> Ptolemy.create(server, :kv_engine1, ["secret/data/new",%{Hello: "World"}])
  :ok 
  ```

  :gcp_engine
  """
  @spec create(pid, atom, [any]) :: :ok | :error  | {:error, any}
  def create(pid, engine_name, opts \\ []) do
    case get_engine_type(pid, engine_name) do
      :kv_engine -> 
        Kernel.apply(KV, :kv_create!, [pid | opts])
      :gcp_engine -> 
        Logger.info("Not implemented yet")
        {:error, "GCP is not implemented yet"}
    end
  end

  @doc """
  read all secrets from vault path
  
  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  :kv_engine
    1. secret (Required)
    2. silent (Optional, default: false), use silent option if you want the data ONLY
    3. version (Optional, default: 0)
  
  ## Example
  ```elixir
  iex(2)> Ptolemy.read(server, :kv_engine1, [:ptolemy, true])
  {:ok, %{"test" => "foo"}}
  ```
  """
  @spec read(pid, atom, [any]) :: {:ok, any} | :error | {:error, any}
  def read(pid, engine_name, opts \\ []) do
    case get_engine_type(pid, engine_name) do
      :kv_engine -> 
        Kernel.apply(KV, :kv_cfetch!, [pid, engine_name] ++ opts)
      :gcp_engine -> 
        Logger.info("Not implemented yet")
        {:error, "Not implemented"}
    end
  end

  @doc """
  Updates a secret
  
  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  :kv_engine
    1. secret (Required)
    2. payload (Required)
    3. cas (Optional, default: nil)

  ## Example
  ```elixir
  iex(3)> Ptolemy.update(server, :kv_engine1, [:ptolemy, %{test: "bar"}])
  :ok
  ```
  """
  @spec update(pid, atom, [any]) :: :ok | :error  | {:error, any}
  def update(pid, engine_name, opts \\ []) do
    case get_engine_type(pid, engine_name) do
      :kv_engine -> 
        Kernel.apply(KV, :kv_cupdate!, [pid, engine_name] ++ opts)
      :gcp_engine -> 
        Logger.info("Not implemented yet")
        {:error, "Not implemented"}
      end
  end

  @doc """
  Delete a secret
  
  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  :kv_engine
    1. secret (Required)
    2. vers (Required)
    3. destroy (Optional, default: false)
    
    destroy will leave no trace of the secret

  ## Example
  ```elixir
  iex(4)> Ptolemy.delete(server, :kv_engine1, [:ptolemy, [1]])
  :ok
  ```
  """
  @spec delete(pid, atom, [any]) :: :ok | :error  | {:error, any}
  def delete(pid, engine_name, opts \\ []) do
    case get_engine_type(pid, engine_name) do
      :kv_engine -> 
          Kernel.apply(KV, :kv_cdelete!, [pid, engine_name] ++ opts)

      :gcp_engine -> 
        Logger.info("Not implemented yet")
        {:error, "Not implemented"}
    end
  end

  @doc """
  Helper function used to determine what type does the engine correspond to
  """
  defp get_engine_type(pid, engine_name) do
    with {:ok, engine_conf} <- Server.get_data(pid, engine_name),
      {:ok, engine_type} <- Map.fetch(engine_conf, :engine_type)
    do
      engine_type
    else
      {:error, "Not found!"} -> throw "#{pid} does not have a engine config for #{engine_name}"
      {:error} -> throw "Could not find :engine_type in engine_conf"
    end
  end
end