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
      "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA4Dpkz4g20+ZzUHTTevFvn1WRhT644ZUMKORDrLnP5KHx24QW\nSP5f67WOK5N7gFKo1QiRyrf27H8aHqNxlgNBikX4Dte4kUNA5Mn3cPeKfNW4xFKl\nEh+M7+q8a38bEpjXL82gwXjAosI2dj3wQByNcJdBXonlbVaOY4FcEqcy1vILZgJk\noXuQfX/n5lMtcjshewkxub2nODDd6WUJBrW/o5gRD71HC46BVFV10n5/j5zjX/Li\nrbDtADCB7EOO3zJfT+fipf7GchdhORygl2n2xFQRrH383RHn5AB5niisgDIezfyC\nsy0rLAFD8t7VcUxC9Tuw183RdpRVy1RhRYxfpwIDAQABAoIBAALrH6bH2hbV+AhD\nDQGbpN1JCtTWJSfifb8GgY78+CS8qt41kOiwTuVNfqU4jTH1YXcsXmFqFY+sc9WU\nQQU306GOGZVv31ocqvqPWmYhAq9vRLFhdf6PZJE21+76P4r1bE+V+JKsFK3Jo1XU\npozfEkQ148bsOo06xC2tYFppzLKZe6ixoJiy06DHzucZmb60iRIKUfexHsK4m1YJ\nnqBtvQKgPaQ40a6MvinaLHUDGxE3R28Tj++UrK+RQN5u5M/fQIgaZ7EvvW2wE9c/\nbqxUZIxagnBNyzY/cWjEePE2KyVlR20hwFykkdjX7+3eCKE8phU9YMWsG0LPYn6V\nn5uCMjECgYEA+PQeGsmJUCP8WMhfmYxTBx8V5L1CEpvnFl2vD7Ve/kVIgFU/14HI\ndHSALcHHLdi8C0rX+T5On4zkdBm4AY3AlKdukHw4MfQQVzPZ8Um+hwV/OjBS2PGg\nPqvBmelY+qqQmDeU0ZiGPQk+4ZXRuIlQQOWPFSK0v5gEQ0imbKcuUi8CgYEA5pMe\nbI8w4Lrry3fV6aPL9ZJ0WUmWJ7cwQJmHjnYkzd0vX17Q5ax1tHYXNuchiXCMBBfO\nras5aBaUQFYRVKqPYc+CFfZTc1nckGAdMaAun9cfoh7DJRuQ+eNZEjiHjybVzLEP\n6M6+MTzvK4AtE4V2XCE+KVj/lHIG08uSlleZRAkCgYBtoyS261a7on15pBTmDHRs\nSHZd3DOC+oHUycFVC60gEecSDXkmMZPUJZJllFdhi3eVCYr/yz7Y6TWbI9BzbrgH\nP41juDEPXsrrfHxY1P9Be1xChhGWVSMbNoz2eVukWQWA48l4XNGRg8bblh1cRazA\nR9ixmC09y3blItOYOjAeJQKBgQCfGSKkG8XJO5FaSy0CUzB4GX9I4NrIOsIDwSxl\nI6ZPmnCGqSERaYeqZtWr354nfM5QQLEu6nfpF7NiFUFOH4ZiIlILn3WDoZzszjU2\nueWSC1lbf0h+AWBu3O3oAbOgFlbuL7rflFBuHzKU3JO95Zh/B70hwLRSFMAbQlu6\ne2VZKQKBgQC2Vo1BORaW8SXHAbLm/vs4xARiPaHSHYYGelUHRXFTyoIU/LBQcdvT\nionDVCyZxBRIZffOq7j+pIkJFtiv3VfoD0VFgMWK0xeuqEYnI4vnC0TbxItjb4nF\nKmuAG7/waeLBZY8oRwtqin4y4JJZSC4a9+JrnAydhDLjFGHlr7Tn4g==\n-----END RSA PRIVATE KEY-----\n",
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
