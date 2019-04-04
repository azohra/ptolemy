defmodule KVTest do
  use ExUnit.Case, async: false
  import Tesla.Mock

  @vurl "https://test-vault.com"
  @base_url "https://test-vault.com/v1"
  @secret_path "/secret/data/test_secret"
  @delete_path "/secret/delete/test_secret"
  @destroy_path "/secret/destroy/test_secret"

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
      # create
      %{method: :post, url: @base_url <> @secret_path} ->
        %Tesla.Env{status: 200, body: %{}}

      # read
      %{method: :get, url: @base_url <> @secret_path} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "data" => %{"test" => "haha"}
            },
            "lease_duration" => 0
          }
        }

      # delete
      %{method: :post, url: @base_url <> @delete_path} ->
        %Tesla.Env{status: 204, body: %{}}

      # destroy
      %{method: :post, url: @base_url <> @destroy_path} ->
        %Tesla.Env{status: 204, body: %{}}
    end)

    :ok
  end

  test "create secret" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert {:ok, "KV secret created"} ===
             Ptolemy.create(server, :kv_engine1, [:test_secret, %{Hello: "World"}])
  end

  # test "read secret" do
  #   {:ok, server} = Ptolemy.start(:production, :server2)
  #   {:ok, body} = Ptolemy.read(server, :kv_engine1, [:test_secret])
  #   assert body === %{
  #       "data" => %{
  #         "data" => %{"test" => "haha"}
  #       },
  #       "lease_duration" => 0,
  #   }
  #   {:ok, body} = Ptolemy.read(server, :kv_engine1, [:test_secret, true])
  #   assert body === %{"test" => "haha"}
  # end

  test "update secret" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert {:ok, "KV secret updated"} ===
             Ptolemy.update(server, :kv_engine1, [:test_secret, %{test: "haha"}])
  end

  test "delete secret" do
    {:ok, server} = Ptolemy.start(:production, :server2)
    assert {:ok, "KV secret deleted"} === Ptolemy.delete(server, :kv_engine1, [:test_secret, [1]])
  end

  test "destroy secret" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert {:ok, "KV secret destroyed"} ===
             Ptolemy.delete(server, :kv_engine1, [:test_secret, [1], true])
  end

  test "engine config not found" do
    {:ok, server} = Ptolemy.start(:production, :server2)

    assert {:ok, "KV secret destroyed"} ===
             Ptolemy.delete(server, :kv_engine1, [:test_secret, [1], true])
  end

  test "bang functions" do
    {:ok, server} = Ptolemy.start(:production, :server2)
    alias Ptolemy.Engines.KV
    assert :ok === KV.create!(server, :kv_engine1, :test_secret, %{Hello: "World"})
    assert {:ok, %{"test" => "haha"}} = KV.fetch!(server, :kv_engine1, :test_secret, true)
    assert :ok = KV.update!(server, :kv_engine1, :test_secret, %{Hello: "Elixir"})
    assert :ok = KV.delete!(server, :kv_engine1, :test_secret, [1])
    assert :ok = KV.destroy!(server, :kv_engine1, :test_secret, [1])
  end
end
