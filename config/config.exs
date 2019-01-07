# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :tesla, adapter: Tesla.Adapter.Hackney

config :ptolemy, Ptolemy,
  server1: %{
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
      role: "default",
      iap_on: false,
      exp: 6000
    ]
  }