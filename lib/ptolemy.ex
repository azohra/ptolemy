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

  def start(name, config) do
    Server.start(name, config)
  end

end