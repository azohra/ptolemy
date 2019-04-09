use Mix.Config

config :tesla, adapter: Tesla.Mock

config :ptolemy,
  :vaults,
    server1: %{
      vault_url: "https://test-vault.com",
      engines: [
        gcp_engine: %{
          engine_type: :GCP,
          engine_path: "gcp/"
        }
      ],
      auth: %{
        method: :GCP,
        credentials: %{
          gcp_svc_acc:
            "eyJ0eXBlIjogInNlcnZpY2VfYWNjb3VudCIsICJ0b2tlbl91cmkiOiAiaHR0cHM6Ly9hY2NvdW50cy5nb29nbGUuY29tL28vb2F1dGgyL3Rva2VuIiwgInByb2plY3RfaWQiOiJzb21lLWlkLW9mLWEtZmFrZS1wcm9qZWN0IiwgInByaXZhdGVfa2V5X2lkIjogIldIWS1hcmUteW91LXRyeWluZy10by1zdGVhbC10aGlzIiwgInByaXZhdGVfa2V5IjogIi0tLS0tQkVHSU4gUlNBIFBSSVZBVEUgS0VZLS0tLS1cbk1JSUJPQUlCQUFKQWZha2UvcGVtL2Zha2UvcGVtL1VVSmp0NC9HMFVzckgrbkRlRXpOdVRzSng5SlZndGw0ZjhcbmZha2UvcGVtL3R3NUNiRThQRE9BMXZMbzhjWlQxUjZZalFJREFRQUJBa0JpZXJiS1h1SnZqSVo1cmlkNlp6dFBcbmZha2UvcGVtL2ZhNVFnYmtCZXFUNE0zV3hNRW83OXpkU25lTitrWTFUMGlHbXB5ankrWmhua1E2ZXhySTlxL0JcbkFpRUF4ME1Qam5Xb3N2blBvM0pMR3Y0VWZha2UvcGVtL3c4UGRQSWxVcXpSSC9rQ0lRQ1lDVjJrMlM4UWgwNmNcbnRGbHZON0hzSmdRcDQ2YU0vZjdGTlpXb2JuMUtOUUlnVDFXZTR2eHJmMTdBMGZXV2U1ZS82YmlRRlBiYXA3WFBcbmg4d2RHZzZlY0prQ0lBL0VvT2F3ODdXbUl0d1R4RmJKa3ZWbjkvU1VQTGpRdXZTZkd4ZHQ1aWFsQWlCV0tDM2hcbkgyYVBsVEtPNVk3RmIxWVRzeklHN0ZiRkdwaVdERmxwZU9uNFZBPT1cbi0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tIiwgImNsaWVudF94NTA5X2NlcnRfdXJsIjogImh0dHBzOi8vd3d3Lmdvb2dsZWFwaXMuY29tL2RvbnQvYm90aGVyL2JvdHMvYmVjdWFzZS90aGlzLWlzLWEtZmFrZS1zdmMtYWNjQHByb2plY3QtaWQuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCAiY2xpZW50X2lkIjogIjEyMzQ1Njc4OSIsICJjbGllbnRfZW1haWwiOiAidGhpcy1pcy1hLWZha2Utc3ZjLWFjY0Bwcm9qZWN0LWlkLmlhbS5nc2VydmljZWFjY291bnQuY29tIiwgImF1dGhfdXJpIjogImh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbS9vL29hdXRoMi9hdXRoIiwgImF1dGhfcHJvdmlkZXJfeDUwOV9jZXJ0X3VybCI6ICJodHRwczovL3d3dy5nb29nbGVhcGlzLmNvbS9vYXV0aDIvdjEvY2VydHMifQ==",
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
        },
        gcp_engine1: %{
          engine_type: :GCP,
          engine_path: "gcp/"
        },
        pki_engine1: %{
          engine_type: :PKI,
          engine_path: "pki/",
          roles: %{
              test_role1: "/role1"
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
