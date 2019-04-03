defmodule Ptolemy.Engines.GCPTest do
  use ExUnit.Case
  import Tesla.Mock

  alias Ptolemy.Engines.GCP

  @vurl "https://test-vault.com"
  @gcp_engine_path "gcp/"

  @roleset_name "roleset_name"
  @roleset_name_broken "roleset_doesnt_exist"
  @roleset_config "{\"bindings\":\"resource \\\"//cloudresourcemanager.googleapis.com/projects/project-name\\\" {roles = [\\\"roles/viewer\\\"]}\",\"project\":\"project-name\",\"secret_type\":\"access_token\",\"token_scopes\":[\"https://www.googleapis.com/auth/cloud-platform\",\"https://www.googleapis.com/auth/bigquery\"]}"
  @roleset_config_broken "{\"project\":\"project-name\",\"secret_type\":\"access_token\",\"token_scopes\":[\"https://www.googleapis.com/auth/cloud-platform\"]}"

  @read_roleset_response %{
    "data" => %{
      "secret_type" => "access_token",
      "service_account_email" => "vault-myroleset-XXXXXXXXXX@myproject.gserviceaccounts.com",
      "service_account_project" => "service-account-project",
      "bindings" => "bindings",
      "token_scopes" => [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }

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
      # create (and update)
      %{
        method: :post,
        url: "#{@vurl}/v1/#{@gcp_engine_path}roleset/#{@roleset_name}",
        body: @roleset_config
      } ->
        %Tesla.Env{status: 204, body: ""}

      %{
        method: :post,
        url: "#{@vurl}/v1/#{@gcp_engine_path}roleset/#{@roleset_name}",
        body: @roleset_config_broken
      } ->
        %Tesla.Env{status: 400, body: %{"errors" => ["error_msg"]}}

      # delete (aka rotate) secrets
      %{
        method: :post,
        url: "#{@vurl}/v1/#{@gcp_engine_path}roleset/#{@roleset_name}/rotate"
      } ->
        %Tesla.Env{status: 204, body: ""}

      %{
        method: :post,
        url: "#{@vurl}/v1/#{@gcp_engine_path}roleset/#{@roleset_name_broken}/rotate"
      } ->
        %Tesla.Env{status: 400, body: %{"errors" => ["error_msg"]}}

      # delete (aka rotate) access tokens only
      %{
        method: :post,
        url: "#{@vurl}/v1/#{@gcp_engine_path}roleset/#{@roleset_name}/rotate-key"
      } ->
        %Tesla.Env{status: 204, body: ""}

      %{
        method: :post,
        url: "#{@vurl}/v1/#{@gcp_engine_path}roleset/#{@roleset_name_broken}/rotate-key"
      } ->
        %Tesla.Env{status: 400, body: %{"errors" => ["error_msg"]}}

      # read roleset config
      %{
        method: :get,
        url: "#{@vurl}/v1/#{@gcp_engine_path}roleset/#{@roleset_name}"
      } ->
        %Tesla.Env{status: 200, body: @read_roleset_response}

      %{
        method: :get,
        url: "#{@vurl}/v1/#{@gcp_engine_path}roleset/#{@roleset_name_broken}"
      } ->
        %Tesla.Env{status: 400, body: %{"errors" => ["error_msg"]}}

      # read secret from roleset
      %{
        method: :get,
        url: "#{@vurl}/v1/#{@gcp_engine_path}token/#{@roleset_name}"
      } ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{token: "shhh...", expires_at_seconds: 1_537_400_046, token_ttl: 3599}
          }
        }

      %{
        method: :get,
        url: "#{@vurl}/v1/#{@gcp_engine_path}token/#{@roleset_name_broken}"
      } ->
        %Tesla.Env{status: 400, body: %{"errors" => ["error_msg"]}}

      %{
        method: :get,
        url: "#{@vurl}/v1/#{@gcp_engine_path}key/#{@roleset_name}"
      } ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              private_key_data: "shhh....",
              key_algorithm: "TYPE_GOOGLE_CREDENTIALS_FILE",
              key_type: "KEY_ALG_RSA_2048"
            }
          }
        }

      %{
        method: :get,
        url: "#{@vurl}/v1/#{@gcp_engine_path}key/#{@roleset_name_broken}"
      } ->
        %Tesla.Env{status: 400, body: %{"errors" => ["error_msg"]}}
    end)

    :ok
  end

  test "generate roleset" do
    assert GCP.generate_roleset(:access_token, "project", "bindings", ["scope1", "scope2"]) === %{
             secret_type: "access_token",
             project: "project",
             bindings: "bindings",
             token_scopes: ["scope1", "scope2"]
           }

    assert GCP.generate_roleset(:service_account_key, "project", "bindings") === %{
             secret_type: "service_account_key",
             project: "project",
             bindings: "bindings"
           }
  end

  test "Ptolemy.create roleset" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert {:ok, "Roleset implemented"} ===
             Ptolemy.create(server, :gcp_engine1, [@roleset_name, @roleset_config])

    assert {:error, "Roleset creation failed, Status: 400 with error: error_msg"} ===
             Ptolemy.create(server, :gcp_engine1, [@roleset_name, @roleset_config_broken])
  end

  test "Ptolemy.read secret" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert {:ok, %{token: "shhh...", expires_at_seconds: 1_537_400_046, token_ttl: 3599}} ===
             Ptolemy.read(server, :gcp_engine1, [:access_token, @roleset_name])

    assert {:error, "Generating Oauth2 token failed, Status: 400 with error: error_msg"} ===
             Ptolemy.read(server, :gcp_engine1, [:access_token, @roleset_name_broken])

    assert {:ok,
            %{
              private_key_data: "shhh....",
              key_algorithm: "TYPE_GOOGLE_CREDENTIALS_FILE",
              key_type: "KEY_ALG_RSA_2048"
            }} === Ptolemy.read(server, :gcp_engine1, [:service_account_key, @roleset_name])

    assert {:error, "Generating svc acc key failed, Status: 400 with error: error_msg"} ===
             Ptolemy.read(server, :gcp_engine1, [:service_account_key, @roleset_name_broken])
  end

  test "Ptolemy.update roleset" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert {:ok, "Roleset implemented"} ===
             Ptolemy.update(server, :gcp_engine1, [@roleset_name, @roleset_config])

    assert {:error, "Roleset creation failed, Status: 400 with error: error_msg"} ===
             Ptolemy.update(server, :gcp_engine1, [@roleset_name, @roleset_config_broken])
  end

  test "Ptolemy.delete (rotate) roleset" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert {:ok, "Rotated"} ===
             Ptolemy.delete(server, :gcp_engine1, [:service_account_key, @roleset_name])

    assert {:error, "Rotate roleset failed, Status: 400 with error: error_msg"} ===
             Ptolemy.delete(server, :gcp_engine1, [:service_account_key, @roleset_name_broken])

    assert {:ok, "Rotated"} ===
             Ptolemy.delete(server, :gcp_engine1, [:access_token, @roleset_name])

    assert {:error, "Rotate-key roleset failed, Status: 400 with error: error_msg"} ===
             Ptolemy.delete(server, :gcp_engine1, [:access_token, @roleset_name_broken])
  end

  test "read roleset configuration" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert @read_roleset_response["data"] ===
             GCP.read_roleset!(server, :gcp_engine1, @roleset_name)

    resp =
      try do
        GCP.read_roleset!(server, :gcp_engine1, @roleset_name_broken)
      catch
        err -> err
      end

    assert resp === "Reading roleset failed, Status: 400 with error: error_msg"
  end

  test "CRUD bang! functions" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert :ok === GCP.create!(server, :gcp_engine1, @roleset_name, @roleset_config)
    assert :ok === GCP.update!(server, :gcp_engine1, @roleset_name, @roleset_config)
    assert :ok === GCP.delete!(server, :gcp_engine1, :access_token, @roleset_name)

    assert %{token: "shhh...", expires_at_seconds: 1_537_400_046, token_ttl: 3599} ===
             GCP.read!(server, :gcp_engine1, :access_token, @roleset_name)
  end
end
