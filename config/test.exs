use Mix.Config

config :tesla, adapter: Tesla.Mock

config :ptolemy,
  vaults: [
    server1: %{
      vault_url: "https://test-vault.com",
      engines: [
        gcp_engine: %{
          engine_path: "gcp/"
        }
      ],
      auth: %{
        method: :GCP,
        credentials: %{
          gcp_svc_acc:
            "{\"type\":\"service_account\",\"token_uri\":\"https://accounts.google.com/o/oauth2/token\",\"project_id\":\"some-id-of-a-fake-project\",\"private_key_id\":\"WHY-are-you-trying-to-steal-this\",\"private_key\":\"-----BEGIN RSA PRIVATE KEY-----\\nMIIBOAIBAAJAfake/pem/fake/pem/UUJjt4/G0UsrH+nDeEzNuTsJx9JVgtl4f8\\nfake/pem/tw5CbE8PDOA1vLo8cZT1R6YjQIDAQABAkBierbKXuJvjIZ5rid6ZztP\\nfake/pem/fa5QgbkBeqT4M3WxMEo79zdSneN+kY1T0iGmpyjy+ZhnkQ6exrI9q/B\\nAiEAx0MPjnWosvnPo3JLGv4Ufake/pem/w8PdPIlUqzRH/kCIQCYCV2k2S8Qh06c\\ntFlvN7HsJgQp46aM/f7FNZWobn1KNQIgT1We4vxrf17A0fWWe5e/6biQFPbap7XP\\nh8wdGg6ecJkCIA/EoOaw87WmItwTxFbJkvVn9/SUPLjQuvSfGxdt5ialAiBWKC3h\\nH2aPlTKO5Y7Fb1YTszIG7FbFGpiWDFlpeOn4VA==\\n-----END RSA PRIVATE KEY-----\",\"client_x509_cert_url\":\"https://www.googleapis.com/dont/bother/bots/becuase/this-is-a-fake-svc-acc@project-id.iam.gserviceaccount.com\",\"client_id\":\"123456789\",\"client_email\":\"this-is-a-fake-svc-acc@project-id.iam.gserviceaccount.com\",\"auth_uri\":\"https://accounts.google.com/o/oauth2/auth\",\"auth_provider_x509_cert_url\":\"https://www.googleapis.com/oauth2/v1/certs\"}",
          vault_role: "write-role",
          exp: 900
        },
        auto_renew: true,
        opts: [
          iap_svc_acc: :reuse,
          client_id: "asasd229384sdhjff9efhbe234FAKE.apps.googleusercontent.com",
          exp: 900
        ]
      }
    },
    server2: %{
      vault_url: "https://test-vault.com",
      engines: [
        kv_engine1: %{
          engine_type: :KV,
          engine_path: "secret/",
          secrets: %{
            test_secret: "/test_secret"
        }
      }
      ],
      auth: %{
        method: :Approle,
        credentials: %{
          role_id: "test",
          secret_id: "test"
        },
        auto_renew: true,
        opts: []
      }
    }
  ]
