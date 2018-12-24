# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :tesla, adapter: Tesla.Adapter.Hackney

config :ptolemy, Ptolemy,
  server1: %{
    vault_url: "http://localhost:8200",
    kv_path: "/secret/data",
    auth_mode: "approle",
    credentials: %{
      role_id: System.get_env("ROLE_ID"),
      secret_id: System.get_env("SECRET_ID")
    },
    opts: [
      role: "default",
      remote_server_cert: """
      -----BEGIN CERTIFICATE-----
      -----END CERTIFICATE-----
      """,
      iap_on: false,
      exp: 60
    ]
  }