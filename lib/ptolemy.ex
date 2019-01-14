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
      }
    ```
    - For a GCP configuration
    ```elixir
    config :ptolemy, Ptolemy,
      production: %{
        vault_url: "http://localhost:8200",
        auth_mode: "GCP",
        kv_engine: %{
          kv_engine1: %{
            engine_path: "secret/",
            secrets: %{
              ptolemy: "/ptolemy"
            }
          }
        },
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
  alias Ptolemy.Server
  alias Ptolemy.Engines.KV

  @doc """
  Entrypoint of ptolemy, this will start the process and store all necessary state for a connection to a remote vault server.
  """
  def start(name, config) do
    Server.start(name, config)
  end

  @doc """
  Read a specific key from given secret via the `:kv_engine` configuration.

  Specifying a version will read that specific version.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_cread(:production, :kv_engine1, :ptolemy, "foo")
  {:ok, test"} 
  ```
  """
  def kv_cread(pid, engine_name, secret, key, version \\ 0) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    kv_read(pid, path, key, version)
  end

  @doc """
  Read a specific key from given secret via a KV engine.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_cread(:production, "secret/data/ptolemy", "foo")
  {:ok, test"} 
  ```
  """
  def kv_read(pid, secret_path, key, version \\ 0) do
    with map <- kv_fetch(pid, secret_path, true, version),
      {:ok, values} <- Map.fetch(map, key)
    do
      {:ok, values}
    else
      :error -> {:error, "Could not find: #{key} in the remote vault server"}
    end
  end

  @doc """
  Fetches all of a secret's keys and value via the `:kv_engine` configuration.
  
  See `kv_fetch/2` for the description of the silent and version options.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_cfetch(:production, :kv_engine1, :ptolemy)
  %{ 
      "Foo" => test"
    } 
  ```
  """
  def kv_cfetch(pid, engine_name, secret, silent \\ false, version \\ 0) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    kv_fetch(pid, path, silent, version)
  end

  @doc """
  Fetches all of a  given secret's key and values from a KV engine

  This function returns the full reponse of the remote vault server, enabling the silent option will only return a map with the key and value
  of the secret. The version option will allow you to fetch specific version of the target secret.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_fetch(:production, "secret/data/ptolemy")
  %{ 
      "Foo" => test"
    } 
  ```
  """
  def kv_fetch(pid, secret, silent \\ false, version \\ 0) when is_bitstring(secret) do
    client = create_client(pid)
    opts = [version: version]

    resp = KV.read_secret!(client, secret, opts)

    case silent do
      true -> 
        resp
        |> Map.get("data")
        |> Map.get("data")
      false ->
        resp
    end
  end

  @doc """
  Updates an already existing secret via the `:kv_engine` configuration.
  """
  def kv_cupdate(pid, engine_name, secret, payload, cas \\ nil) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    kv_create(pid, path, payload, cas)
  end

  @doc """
  Updates an already existing secre
  """
  def kv_update(pid, secret, payload, cas \\ nil) when is_bitstring(secret) do
    kv_create(pid, secret, payload, cas)
  end

  @doc """
  Creates a new secret via a KV engine
  """
  def kv_create(pid, secret, payload, cas \\ nil) when is_bitstring(secret) do
    client = create_client(pid)
    KV.create_secret!(client, secret, payload, cas)
  end

  @doc """
  Deletes a secific version of a secret
  """
  def kv_delete(pid, engine_path, secret, vers \\ []) do
    client = create_client(pid)
    KV.delete!(client, secret, vers)
  end

  @doc """
  Destroys a specific version of secret
  """
  def kv_destroy(pid, secret, vers\\ []) do
    client = create_client(pid)
    KV.destroy!(client, secret, vers)
  end

  #Tesla client function
  defp create_client(pid) do
    creds = Server.fetch_credentials(pid)
    {:ok, url} = Server.get_data(pid, :vault_url)

    Tesla.client([
      {Tesla.Middleware.BaseUrl, "#{url}/v1"},
      {Tesla.Middleware.Headers, creds},
      {Tesla.Middleware.JSON, []}
    ])
  end

  #Helper functions to make paths
  defp get_kv_path!(pid, engine_name, secret, operation) when is_atom(secret) do
    with {:ok, kv_conf} <- Server.get_data(pid, :kv_engine),
      {:ok, kvname} <- Map.fetch(kv_conf, engine_name),
      %{engine_path: path, secrets: secrets} <- kvname
    do
      {:ok, secret_path} = Map.fetch(secrets, secret)
      make_kv_path!(path, secret_path, operation)
    else
      {:error, "Not found!"} -> throw "#{pid} does not have a kv_engine config"
      :error -> throw "Could not find engine_name in specified config"
    end
  end

  defp get_kv_path!(pid, engine_name, secret, operation) when is_bitstring(secret) do
    with {:ok, kv_conf} <- Server.get_data(pid, :kv_engine),
      {:ok, kvname} <- Map.fetch(kv_conf, engine_name),
      %{engine_path: path, secrets: _ } <- kvname
    do
      make_kv_path!(path, secret, operation)
    else
      {:error, "Not found!"} -> throw "#{pid} does not have a kv_engine config"
      :error -> throw "Could not find engine_name in specified config"
    end
  end

  defp make_kv_path!(engine_path, secret_path, operation) do
    "/#{engine_path}#{operation}#{secret_path}"
  end

end