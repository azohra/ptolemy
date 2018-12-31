defmodule Ptolemy do
  @moduledoc """
  Ptolemy is an elixir client for Hashicorp's Vault. 

  These are the configuration option available:
  Required:
    - `vault_url` :: String
      - a
    - `credentials` :: Map
    - `kv_path` :: String
    - `auth_mode` :: String
      - Authentication mode. 
  
  Optional:
    - `iap_on` :: Bool
    - `exp` :: Integer
    - `remote_server_cert` :: String
      - x509 cert in PEM format. Should be used if your remote vault server is using a self signed certificate.
    - `role` :: String 
      - The vault role that will be used when authenticating to the remote vault server. This is required if
      the `auth_mode` is set to "GCP".
  """
  use Tesla

  alias Ptolemy.Server
  alias Ptolemy.Engines.KV

  @doc """
  Starts a genserver that holds all necessary config data for a remote vault server.
  """
  def start(name, config) do
    Server.start(name, config)
  end

  def kv_read(pid, secret, key, version \\ 0)

  @doc """
  Reads a key from a secret in a remote vault server. This will fetch the specified secret from 
  the Ptolemy configuration.
  """
  def kv_read(pid, secret, key, version) when is_atom(secret) do
    path = get_kv_path(pid, secret)
    kv_read(pid, path, key, version)
  end

  @doc """
  Reads a key from a secret in a remote vault server.
  """
  def kv_read(pid, secret_path, key, version) do
    with map <- kv_fetch(pid, secret_path, true, version),
      {:ok, values} <- Map.fetch(map, key)
    do
      {:ok, values}
    else
      :error ->{:error, "Could not find: #{key} in the remote vault server"}
    end
  end

  def kv_fetch(pid, secret, silent \\ false, version \\ 0) 

  @doc """
  Fetches a secret from a remote vault server. This will fetch the specified secret from 
  the Ptolemy configuration.
  """
  def kv_fetch(pid, secret, silent, version) when is_atom(secret) do
    path = get_kv_path(pid, secret)

    kv_fetch(pid, path, silent, version)
  end

  @doc """
  Fetches all values of a secret from a remote vault server. Enabling the silent option 
  will mute the response to only contain the secret's key values.
  """
  def kv_fetch(pid, secret, silent, version) do
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
  Updates a secrets in a remote vault server
  """
  def kv_update(pid, secret, payload, cas \\ nil) do
    kv_create(pid, secret, payload, cas)
  end

  @doc """
  Creates a new secret in a remote vault server
  """
  def kv_create(pid, secret, payload, cas \\ nil)

  def kv_create(pid, secret, payload, cas) when is_atom(secret) do
    path = get_kv_path(pid, secret)
    kv_create(pid, secret, payload, cas)
  end

  def kv_create(pid, secret, payload, cas) do
    client = create_client(pid)
    KV.create_secret!(client, secret, payload, cas)
  end



  def kv_delete(pid, secret, opt \\ []) do
    
  end

  def destroy(pid, secret, vers) do
    
  end

  def create_client(pid) do
    creds = Server.fetch_credentials(pid)
    {:ok, url} = Server.get_data(pid, :vault_url)

    Tesla.client([
      {Tesla.Middleware.BaseUrl, "#{url}/v1"},
      {Tesla.Middleware.Headers, creds},
      {Tesla.Middleware.JSON, []}
    ])
  end

  defp get_kv_path(pid, name) do
    {:ok, pmap} = Server.get_data(pid, :kv_paths)
    path = 
      pmap
      |> Map.fetch!(name)
  end

end