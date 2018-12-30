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

  @doc """
  Reads a key from a secret in a remote vault server. This will fetch the specified secret from 
  the Ptolemy configuration.
  """
  def read(pid, Ptolemy.KV, secret, key, version \\ 0) when is_atom(secret) do
    {:ok, pmap} = Server.get_data(pid, :kv_paths)
    path = 
      pmap
      |> Map.fetch!(secret)

    read(pid, Ptolemy.KV, path, key, version)
  end

  @doc """
  Reads a key from a secret in a remote vault server.
  """
  def read(pid, Ptolemy.KV, secret_path, key, version) do
    with map <- fetch(pid, Ptolemy.KV, secret_path, true, version),
      {:ok, values} <- Map.fetch(map, key)
    do
      {:ok, values}
    else
      :error ->{:error, "Could not find: #{key} in the remote vault server"}
    end
  end

  @doc """
  Fetches a secret from a remote vault server. This will fetch the specified secret from 
  the Ptolemy configuration.
  """
  def fetch(pid, Ptolemy.KV, secret, silent \\ false, version \\ 0) when is_atom(secret) do
    {:ok, pmap} = Server.get_data(pid, :kv_paths)
    path = 
      pmap
      |> Map.fetch!(secret)

    fetch(pid, Ptolemy.KV, path, silent, version)
  end

  @doc """
  Fetches all values of a secret from a remote vault server. Enabling the silent option 
  will mute the response to only contain the secret's key values.
  """
  def fetch(pid, Ptolemy.KV, secret, silent, version) do
    client = create_client(pid)
    path = Server.get_data(pid, KV)
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

  def update(pid, Ptolemy.KV, secret_path, payload, cas \\ nil) do
    
  end

  def create(pid, Ptolemy.KV, secret_path, payload, cas \\ nil) do
    
  end

  def delete(pid, Ptolemy.KV, secret_path, opt \\ []) do
    
  end

  def destroy(pid, Ptolemy.KV, secret_path, opt \\ []) do
    
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

end