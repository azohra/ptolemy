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
  """
  def start(name, config) do
    Server.start_link(name, config)
  end

  @doc """
  create secrets
  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow
  
  :kv_engine
    1. secret (Required, path of the secret)
    2. payload (Required, content of the secret)
    3. cas (Optional, default: nil)
  
  :gcp_engine
  """
  def create(pid, engine_name, opts \\ []) do
    case get_engine_type(pid, engine_name) do
      :kv_engine -> 
        Kernel.apply(KV, :kv_create!, [pid | opts])
      :gcp_engine -> 
        Logger.info("Not implemented yet")
    end
  end

  @doc """
  fetches all secrets from vault path
  
  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  :kv_engine
    1. secret (Required)
    2. silent (Optional, default: false)
    3. version (Optional, default: 0)
  """
  def fetch(pid, engine_name, opts \\ []) do
    case get_engine_type(pid, engine_name) do
      :kv_engine -> 
        Kernel.apply(KV, :kv_cfetch!, [pid, engine_name] ++ opts)
      :gcp_engine -> 
        Logger.info("Not implemented yet")
        {:error, "Not implemented"}
    end
  end

  @doc """
  read a specified secret from 
  
  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  :kv_engine
    1. secret (Required)
    2. key (Required)
    3. version (Optional, default: 0)
  """
  def read(pid, engine_name, opts \\ []) do
    case get_engine_type(pid, engine_name) do
      :kv_engine -> 
        Kernel.apply(KV, :kv_cread, [pid, engine_name] ++ opts)
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
  """
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
  """
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
  Destroy a secret, differ from delete for some engines, such as KV
  
  opts requirements, ARGUMENTS MUST BE AN ORDERED LIST as follow

  :kv_engine
    1. secret (Required)
    2. vers (Required)
  """
  def destroy(pid, engine_name, opts \\ []) do
    case get_engine_type(pid, engine_name) do
      :kv_engine -> 
        Kernel.apply(KV, :kv_cdestroy!, [pid, engine_name] ++ opts)
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