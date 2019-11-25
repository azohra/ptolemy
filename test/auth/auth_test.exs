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
      "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAkqxESs7Ny7paZv6EgGpfLsiqd1wdcuC5EzVW6YvMYBczJHgu\nVed0Ez5eMjSYQraHdzfbCzHsRZw2+TjiEhLSdjCAzW2RY5G50W961X6B7pFWeRFH\nx05l9d9dFoFpNTL8tId1On6aPUyH+vypnt300uAgMB25gqgTlLw73O99E7/zp5cw\n4S4RmLS4KPlwJlPOjNwwN8ki1weaw3adNupEkQ/y8ZyyhxBO5kPmCztS7CCNIh+K\nhaUmZ3Lwwgk6ESFMKmKB49phgQlm3cYfi8uR0Y+qFYi5iHbSmViqIhfKWlYU+JnH\nB/cSaemh9Eq6L9bG8SxvV50aWw1PifAZPKL+uQIDAQABAoIBAG6La4U+TJkJwOzz\nUwY+JbLrBp+jS4aznIm/n9uxw72Afskzu8sxAKkoTnJkdYWCcKMH9A2B+OOWE1DO\n8IRSr1DoyYsK05NJ19Tjwp56FI+r9pKU1ZZ/nhUr3csCijrQTOn7Vf1aQgGFVs9x\n8p2MB+OPjHL3VEQHTYrCPBQOZCSnWKkfddGbRh51uJYqRcaMNeJuMFDrVeBH22ci\nbkh8ze+44cFy5AXnMRjk87PcG8uvkYvC1tN5caJ10r4d4T1Fn6QQPyGoFDgfw8sd\nkxGpbJ0ZcjQessPUaYZFDYS0egBLTncINKaxo0lylpgGGpaIReHo0iDo7fkRjFqD\nH9Bk8gECgYEA0I2Q+hN1mubbHmRo74t7nQHSvQIS1wkOc4Ll1cmwmkK5GB7Fmjar\n4RmhLLD/RkaZ2mQ0EL52+q/9qzcC+O4MPyUCdFSddU8WlLooM7tVmXDhjJ4QNHr0\nxVbda7CgsUvKGblyoXEUYQepEVvGCMTNaze3b88COdaKrV7vfOEXEGECgYEAtAq2\nrx9QKoTifStttIr0PZ2h6gvI8JQiaQGy59sgXE1JwV0n5dbz36pV5BCmYb/eV/aQ\n5dPob3eGk3Y6TbmuFZWqVlZNvIB1OI6vz6+ZZgXImlf8VbsdqfwImePcQJ5SWt4t\n0EaM5YxjnwWFCtQpCzv/hjc1ZJYNKarNju/FbVkCgYAWqRs0oQKpVyY98ikYxi4j\nTDxqvxvu85P3ZyS0Cxs+V7um7EkKTaB1cAR8R6slJqy29yZVH2zsJk1I2kxfYfZA\nsjPHEh6dzX8ln+iYXmWZq5NGZTJbkXShMKQUfHepbBPEocrb0d6mAGAVe8RT1ZaA\nbOhopLSYNkCRP/yDtC1+YQKBgQCWy55lIPn5EuHMatJw9C1LajrSF9rOPZRwlN6u\nuWbqSEWtMgQXyqjqPfXAln10w8pLrJWCGbHForvRyKVeslVveLJ5q8FiT8lefIwe\njHoT7GYvd+A+QgG/fPwLQMEaUkCyIQMIPf8GyEYsS+g5wKc75J3JYXZT8CXIL2oJ\n/SNDyQKBgQC1qyCjpVR5TtMlz+HgKj8CRsfY9b3CTzfHzEHOutbUG830Zq5FPMLV\nwwOoHH5XAeSAKiL6WvyCk7svTMCnMqzVnWrwZfvXcWIT38drQSPwmgTytGWgaUx9\nu0YOMmcL+cdNZA7zJHF0AcZUSI5oEiOHaYk26vujegfExEnmgX5TwQ==\n-----END RSA PRIVATE KEY-----\n",
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

      %{method: :post, url: "#{@vurl}/v1/auth/prod-bluenose/login"} ->
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

  test "Vault authentication success via Kubernetes using http_opts" do
    assert @result_NOIAP ==
             Ptolemy.Auth.authenticate(
               :Kubernetes,
               @vurl,
               %{
                 kube_client_token: "test_token",
                 vault_role: "test",
                 cluster_name: "prod-bluenose"
               },
               http_opts: [adapter: [ssl_options: [cacertfile: "/opt/app/abc/test.pem"]]]
             )
  end

  test "Vault authentication success via Kubernetes using headers" do
    assert @result_NOIAP ==
             Ptolemy.Auth.authenticate(
               :Kubernetes,
               @vurl,
               %{
                 kube_client_token: "test_token",
                 vault_role: "test",
                 cluster_name: "prod-bluenose"
               },
               headers: [adapter: [ssl_options: [cacertfile: "/opt/app/abc/test.pem"]]]
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
