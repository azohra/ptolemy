defmodule PtolemyServerTest do
  use ExUnit.Case, async: false
  import Tesla.Mock
  alias Ptolemy.Server

  ##############################################################################################
  # DO NOT FEAR!!!! ALL VALUES HERE ARE FOR TESTING PURPOSES, THEY ARE ****NOT**** REAL VALUES!
  ##############################################################################################
  @vurl "https://test-vault.com"
  @iam_auth_url "https://iam.googleapis.com"
  @google_auth_url "https://www.googleapis.com"

  # this mock is made global to allow authentication while testing the public genserver API
  setup_all do
    mock_global(fn
      %{method: :post, url: "#{@vurl}/v1/auth/approle/login"} ->
        json(
          %{
            "auth" => %{
              "renewable" => true,
              "lease_duration" => 2_764_800,
              "metadata" => %{},
              "policies" => [
                "default",
                "dev-policy",
                "test-policy"
              ],
              "accessor" => "5d7fb475-07cb-4060-c2de-1ca3fcbf0c56",
              "client_token" => "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"
            }
          },
          status: 200
        )
    end)

    :ok
  end

  setup do
    mock(fn
      %{method: :post, url: "#{@vurl}/v1/auth/approle/login"} ->
        json(
          %{
            "auth" => %{
              "renewable" => true,
              "lease_duration" => 2_764_800,
              "metadata" => %{},
              "policies" => [
                "default",
                "dev-policy",
                "test-policy"
              ],
              "accessor" => "5d7fb475-07cb-4060-c2de-1ca3fcbf0c56",
              "client_token" => "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"
            }
          },
          status: 200
        )

      %{method: :post, url: "#{@vurl}/v1/auth/gcp/login"} ->
        json(
          %{
            "auth" => %{
              "client_token" => "98a4c7ab-FAKE-361b-ba0b-e307aacfd587",
              "accessor" => "0e9e354a-520f-df04-6867-ee81cae3d42d",
              "policies" => [
                "default",
                "dev",
                "prod"
              ],
              "metadata" => %{
                "project_id" => "my-project",
                "role" => "my-role",
                "service_account_email" => "dev1@project-123456.iam.gserviceaccount.com",
                "service_account_id" => "111111111111111111111"
              },
              "lease_duration" => 2_764_800,
              "renewable" => true
            }
          },
          status: 200
        )

      # Google access Token to login into IAP protected resources
      %{method: :post, url: "#{@google_auth_url}/oauth2/v4/token"} ->
        json(
          %{
            "id_token" => "98a4c7ab98a4c7ab98a4c7ab",
            "access_token" =>
              "ya29.c.ifkjshdflkjsdhlfkjsrhgeurghoiRANDOMDATASCREWOFFBOTSosdifjsldkfasd",
            "expires_in" => 3600,
            "token_type" => "Bearer"
          },
          status: 200
        )

      %{
        method: :post,
        url:
          "#{@iam_auth_url}/v1/projects/some-id-of-a-fake-project/serviceAccounts/this-is-a-fake-svc-acc@project-id.iam.gserviceaccount.com:signJwt"
      } ->
        json(
          %{
            "keyId" => "ASKDJLAKSJDdsfsdfsdfsdfJAHLKJASHF*FEUHFOAIUEHF",
            "signedJwt" =>
              "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.TCYt5XsITJX1CxPCT8yAV-TVkIEq_PbChOMqsLfRoPsnsgw5WEuts01mq-pQy7UJiN5mgRxD-WUcX16dUEMGlv50aqzpqh4Qktb3rk-BuQy72IFLOqV0G_zS245-kronKb78cPN25DGlcTwLtjPAYuNzVBAh4vGHSrQyHUdBBPM"
          },
          status: 200
        )
    end)

    :ok
  end

  test "get and set data" do
    {:ok, server2} = Server.start_link(:vault1, :server2)

    assert {:error, "Not found!"} === Server.get_data(server2, :fake_key)
    assert {:error, "Key Not found!"} === Server.set_data(server2, :fake_key, "data")

    {:ok, url} = Server.get_data(server2, :vault_url)
    assert @vurl == url
    Server.set_data(server2, :vault_url, "new_url")
    {:ok, url} = Server.get_data(server2, :vault_url)
    assert "new_url" == url
  end

  test "dump config server2" do
    {:ok, server} = Server.start_link(:vault1, :server1)

    assert Server.dump(server) ===
             {:ok,
              %{
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
              }}
  end

  test "approle auth and fetch credentials" do
    {:ok, server} = Server.start_link(:vault1, :server2)
    # The first time is fetched from the endpoint
    assert Server.fetch_credentials(server) === [
             {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}
           ]

    # pulls token field without error from the server
    assert Server.fetch_credentials(server) === [
             {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}
           ]
  end

  test "gauth handle_call :auth" do
    # default server map in test config
    state =
      Application.get_env(:ptolemy, :vaults)
      |> Keyword.fetch!(:server1)

    # server 2 auth map with auto_renew set to false
    non_renewed_approle_auth =
      Map.fetch!(state, :auth)
      |> Map.put(:auto_renew, false)

    assert Server.handle_call(:auth, "NA", state) ===
             {:reply,
              {:ok,
               %{
                 vault: %{
                   lease_duration: 2_764_800,
                   renewable: true,
                   token: {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}
                 },
                 iap: %{token: {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}}
               }},
              Map.put(state, :tokens, [
                {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"},
                {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}
              ])}

    alt_state = Map.put(state, :auth, non_renewed_approle_auth)

    assert Server.handle_call(:auth, "NA", alt_state) ===
             {:reply,
              {:ok,
               %{
                 vault: %{
                   lease_duration: 2_764_800,
                   renewable: true,
                   token: {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}
                 },
                 iap: %{token: {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}}
               }},
              Map.put(alt_state, :tokens, [
                {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"},
                {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}
              ])}
  end

  test "approle handle_call :auth" do
    # default server2 map in test config
    state =
      Application.get_env(:ptolemy, :vaults)
      |> Keyword.fetch!(:server2)

    # server2 auth map with auto_renew set to false
    non_renewed_approle_auth =
      Map.fetch!(state, :auth)
      |> Map.put(:auto_renew, false)

    assert Server.handle_call(:auth, "from", state) ===
             {:reply,
              {:ok,
               %{
                 lease_duration: 2_764_800,
                 renewable: true,
                 token: {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}
               }},
              Map.put(state, :tokens, [{"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}])}

    alt_state = Map.put(state, :auth, non_renewed_approle_auth)

    assert Server.handle_call(:auth, "NA", alt_state) ===
             {:reply,
              {:ok,
               %{
                 lease_duration: 2_764_800,
                 renewable: true,
                 token: {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}
               }},
              Map.put(alt_state, :tokens, [
                {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}
              ])}
  end

  test "purge" do
    state =
      Application.get_env(:ptolemy, :vaults)
      |> Keyword.fetch!(:server2)

    state_vault_token =
      state
      |> Map.put(:tokens, [{"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}])

    state_iap_token =
      state
      |> Map.put(:tokens, [{"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}])

    state_both_tokens =
      state
      |> Map.put(:tokens, [
        {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"},
        {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}
      ])

    assert Server.handle_info({:purge, :all}, state_both_tokens) === {:noreply, state}
    assert Server.handle_info({:purge, :vault}, state_vault_token) === {:noreply, state}
    assert Server.handle_info({:purge, :iap}, state_both_tokens) === {:noreply, state_vault_token}
    assert Server.handle_info({:purge, :vault}, state_both_tokens) === {:noreply, state_iap_token}
  end

  test "auto renew iap" do
    state =
      Application.get_env(:ptolemy, :vaults)
      |> Keyword.fetch!(:server1)

    state_exp_iap =
      state
      |> Map.put(:tokens, [
        {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"},
        {"Authorization", "Bearer expired"}
      ])

    state_new =
      state
      |> Map.put(:tokens, [
        {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"},
        {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}
      ])

    opts = [
      iap_svc_acc: :reuse,
      client_id: "asasd229384sdhjff9efhbe234FAKE.apps.googleusercontent.com",
      exp: 900
    ]

    assert Server.handle_info({:auto_renew_iap, opts}, state_exp_iap) === {:noreply, state_new}
  end

  test "approle auto renew vault" do
    state =
      Application.get_env(:ptolemy, :vaults)
      |> Keyword.fetch!(:server2)

    %{
      vault_url: url,
      auth: %{
        method: mode,
        credentials: creds,
        opts: opts
      }
    } = state

    state_exp_token =
      state
      |> Map.put(:tokens, [{"X-Vault-Token", "expired"}])

    state_new_token =
      state
      |> Map.put(:tokens, [{"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"}])

    assert Server.handle_info({:auto_renew_vault, mode, url, creds, opts}, state_exp_token) ===
             {:noreply, state_new_token}
  end

  test "auto renew vault GCP" do
    state =
      Application.get_env(:ptolemy, :vaults)
      |> Keyword.fetch!(:server1)

    %{
      vault_url: url,
      auth: %{
        method: mode,
        credentials: creds,
        opts: opts
      }
    } = state

    %{
      gcp_svc_acc: svc
    } = creds

    parsed_creds = Map.replace!(creds, :gcp_svc_acc, svc |> Base.decode64!() |> Jason.decode!())

    state_both_exp_tokens =
      state
      |> Map.put(:tokens, [
        {"X-Vault-Token", "expired"},
        {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}
      ])

    state_both_new_tokens =
      state
      |> Map.put(:tokens, [
        {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"},
        {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}
      ])

    assert Server.handle_info(
             {:auto_renew_vault, mode, url, parsed_creds, opts},
             state_both_exp_tokens
           ) === {:noreply, state_both_new_tokens}
  end
end
