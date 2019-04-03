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

    parsed_creds = Map.replace!(creds, :gcp_svc_acc, svc |> Jason.decode!())

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
