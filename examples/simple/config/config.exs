use Mix.Config

# The vault server configuration block, details in Ptolemy `ptolemy.ex` module documentations
config :ptolemy,
  :vaults,
    simple_server: %{
      vault_url: "http://localhost:8200",
      engines: [
        simple_pki_engine: %{
          engine_type: :PKI,
          engine_path: "pki/",
          roles: %{
            simple_role: "/simple-role"
          }
        },
        simple_kv_engine: %{
          engine_type: :KV,
          engine_path: "secret/",
          secrets: %{
            simple_secret: "/simple-secret"
          }
        }
      ],
      auth: %{
        method: :Approle,
        credentials: %{
          role_id: System.get_env("ROLE_ID"),
          secret_id: System.get_env("SECRET_ID")
        },
        auto_renew: true,
        opts: []
      }
    }

alias Ptolemy.Providers.Vault
# The vault loader configuration block, details in Ptolemy `loader.ex` module documentations
config :ptolemy,
    :loader,
      env: [
        {{:simple, :pki_cert}, {Vault, [:simple_server, :simple_pki_engine, [:simple_role, "www.google.com", %{ttl: "15s"}], []]}},
        {{:simple, :kv_integer}, {Vault, [:simple_server, :simple_kv_engine, [:simple_secret], ["data", "bar"]]}},
        {{:simple, :kv_string}, {Vault, [:simple_server, :simple_kv_engine, [:simple_secret], ["data", "foo"]]}},
      ]