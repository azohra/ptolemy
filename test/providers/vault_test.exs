defmodule Ptolemy.Providers.VaultTest do
  use ExUnit.Case, async: false

  import Tesla.Mock

  alias Ptolemy.Loader


  @vurl "https://test-vault.com"
  @base_url "https://test-vault.com/v1"
  @secret_path "/secret/data/test_secret"

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

        %{method: :get, url: @base_url <> @secret_path} ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "data" => %{"test" => "haha"}
                },
                "lease_duration" => 10
              }
            }
    end)

    :ok
  end

  test "can load a vault value", %{test: test_name} do
    {:ok, _loader} = 
      Loader.start_link(
          env: [
              {{test_name, :loaded_value},
                {Ptolemy.Providers.Vault, [:server2, :kv_engine1, [:test_secret], []]}}
          ]
      )
      assert Application.get_env(test_name, :loaded_value) === %{
                  "data" => %{"test" => "haha"}
                }
  end

  test "can load value and grab key", %{test: test_name} do
    {:ok, _loader} = 
      Loader.start_link(
          env: [
              {{test_name, :loaded_value},
                {Ptolemy.Providers.Vault, [:server2, :kv_engine1, [:test_secret], ["data", "test"]]}}
          ]
      )
      assert Application.get_env(test_name, :loaded_value) === "haha"
  end
end