defmodule Ptolemy.AuthTest do
  use ExUnit.Case, async: true
  import Tesla.Mock
  ##############################################################################################
  # DO NOT FEAR!!!! ALL VALUES HERE ARE FOR TESTING PURPOSES, THEY ARE ****NOT**** REAL VALUES!
  ##############################################################################################
  @vurl "https://test-vault.com"
  @iam_auth_url "https://iam.googleapis.com"
  @google_auth_url "https://www.googleapis.com"
  @fake_id "asasd229384sdhjff9efhbe234FAKE.apps.googleusercontent.com"

  @gcp_svc1_with_vault_perm %{
    "type" => "service_account",
    "project_id" => "some-id-of-a-fake-project",
    "private_key_id" => "WHY-are-you-trying-to-steal-this",
    "private_key" =>
      "-----BEGIN RSA PRIVATE KEY-----\nMIIBOAIBAAJAfake/pem/fake/pem/UUJjt4/G0UsrH+nDeEzNuTsJx9JVgtl4f8\nfake/pem/tw5CbE8PDOA1vLo8cZT1R6YjQIDAQABAkBierbKXuJvjIZ5rid6ZztP\nfake/pem/fa5QgbkBeqT4M3WxMEo79zdSneN+kY1T0iGmpyjy+ZhnkQ6exrI9q/B\nAiEAx0MPjnWosvnPo3JLGv4Ufake/pem/w8PdPIlUqzRH/kCIQCYCV2k2S8Qh06c\ntFlvN7HsJgQp46aM/f7FNZWobn1KNQIgT1We4vxrf17A0fWWe5e/6biQFPbap7XP\nh8wdGg6ecJkCIA/EoOaw87WmItwTxFbJkvVn9/SUPLjQuvSfGxdt5ialAiBWKC3h\nH2aPlTKO5Y7Fb1YTszIG7FbFGpiWDFlpeOn4VA==\n-----END RSA PRIVATE KEY-----",
    "client_email" => "this-is-a-fake-svc-acc@project-id.iam.gserviceaccount.com",
    "client_id" => "123456789",
    "auth_uri" => "https://accounts.google.com/o/oauth2/auth",
    "token_uri" => "https://accounts.google.com/o/oauth2/token",
    "auth_provider_x509_cert_url" => "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url" =>
      "https://www.googleapis.com/dont/bother/bots/becuase/this-is-a-fake-svc-acc@project-id.iam.gserviceaccount.com"
  }

  @iap_opt [iap_svc_acc: @gcp_svc1_with_vault_perm, client_id: @fake_id, exp: 2000]
  @iap_opt_reuse [iap_svc_acc: :reuse, client_id: @fake_id, exp: 2000]

  @result_IAP %{
    vault: %{
      token: {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"},
      renewable: true,
      lease_duration: 2_764_800
    },
    iap: %{
      token: {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}
    }
  }

  @result_NOIAP %{
    token: {"X-Vault-Token", "98a4c7ab-FAKE-361b-ba0b-e307aacfd587"},
    renewable: true,
    lease_duration: 2_764_800
  }

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

  test "Vault authentication success via approle, with IAP disabled/not enabled" do
    assert @result_NOIAP ==
             Ptolemy.Auth.authenticate(:Approle, @vurl, %{secret_id: "test", role_id: "test"}, [])
  end

  test "Vault authentication success via approle, with IAP enabled and Bearer token re-used" do
    assert @result_NOIAP ==
             Ptolemy.Auth.authenticate(
               :Approle,
               @vurl,
               %{secret_id: "test", role_id: "test"},
               {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}
             )
  end

  test "Vault authentication success via approle, with IAP enabled and Bearer token generated" do
    assert @result_IAP ==
             Ptolemy.Auth.authenticate(
               :Approle,
               @vurl,
               %{secret_id: "test", role_id: "test"},
               @iap_opt
             )
  end

  test "Vault authentication success via GCP, with IAP disabled/not enabled" do
    assert @result_NOIAP ==
             Ptolemy.Auth.authenticate(
               :GCP,
               @vurl,
               %{gcp_svc_acc: @gcp_svc1_with_vault_perm, vault_role: "test", exp: 3000},
               []
             )
  end

  test "Vault authentication success via GCP, with IAP enabled and Bearer token re-used" do
    assert @result_NOIAP ==
             Ptolemy.Auth.authenticate(
               :GCP,
               @vurl,
               %{gcp_svc_acc: @gcp_svc1_with_vault_perm, vault_role: "test", exp: 3000},
               {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"}
             )
  end

  test "Vault authentication success via GCP, with IAP enabled and Bearer token generated with the same GCP service account being used for Vault" do
    assert @result_IAP ==
             Ptolemy.Auth.authenticate(
               :GCP,
               @vurl,
               %{gcp_svc_acc: @gcp_svc1_with_vault_perm, vault_role: "test", exp: 3000},
               @iap_opt_reuse
             )
  end

  test "Vault authentication success via GCP, with IAP enabled and Bearer token generated with two seperate GCP service accounts" do
    assert @result_IAP ==
             Ptolemy.Auth.authenticate(
               :GCP,
               @vurl,
               %{gcp_svc_acc: @gcp_svc1_with_vault_perm, vault_role: "test", exp: 3000},
               @iap_opt
             )
  end
end
