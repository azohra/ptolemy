use Mix.Config

config :tesla, adapter: Tesla.Mock
config :tesla, Ptolemy, adapter: Tesla.Mock

config :ptolemy, Ptolemy,
  server1: %{
    vault_url: "http://localhost:8200",
    auth_mode: "approle",
    kv_engine1: %{
        engine_type: :kv_engine,
        engine_path: "secret/",
        secrets: %{
          test_secret: "/test1"
        }
    },
    credentials: %{
      role_id: "test_role_id",
      secret_id: "test_secret_id"
    },
    opts: [
      iap_on: false,
      exp: 6000
    ]

}