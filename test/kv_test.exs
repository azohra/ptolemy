defmodule KVTest do
  use ExUnit.Case, async: false 
  import Tesla.Mock

  @base_url "http://localhost:8200/v1"
  @secret_path "/secret/data/test1"
  
  @delete_path "/secret/delete/test1"
  @destroy_path "/secret/destroy/test1"

  setup do
    mock(fn
      # create
      %{method: :post, url: @base_url <> @secret_path} -> 
        %Tesla.Env{status: 200, body: %{}}
               
      # read
      %{method: :get, url: @base_url <> @secret_path} -> 
        %Tesla.Env{status: 200, body: %{
          "data" => %{
            "data" => %{"test" => "haha"}
          },
          "lease_duration" => 0,
        }
      }
        
      # delete
      %{method: :post, url: @base_url <> @delete_path} -> 
        %Tesla.Env{status: 204, body: %{}}

      # destroy
      %{method: :post, url: @base_url <> @destroy_path} -> 
        %Tesla.Env{status: 204, body: %{}}
      end
        )
    :ok
  end

  test "create secret" do
    {:ok, server} = Ptolemy.start(:production, :server1)
    assert :ok === Ptolemy.create(server, :kv_engine1, ["secret/data/test1",%{Hello: "World"}])
  end

  test "read secret" do
    {:ok, server} = Ptolemy.start(:production, :server1)
    {:ok, body} = Ptolemy.read(server, :kv_engine1, [:test_secret])
    assert body === %{
        "data" => %{
          "data" => %{"test" => "haha"}
        },
        "lease_duration" => 0,
    }
    {:ok, body} = Ptolemy.read(server, :kv_engine1, [:test_secret, true])
    assert body === %{"test" => "haha"}
  end
  
  test "update secret" do
    {:ok, server} = Ptolemy.start(:production, :server1)
    assert :ok === Ptolemy.update(server, :kv_engine1, [:test_secret, %{test: "haha"}])
  end
  
  test "delete secret" do
    {:ok, server} = Ptolemy.start(:production, :server1)
    assert :ok === Ptolemy.delete(server, :kv_engine1, [:test_secret, [1]])
  end
  
  test "destroy secret" do
    {:ok, server} = Ptolemy.start(:production, :server1)
    assert :ok === Ptolemy.delete(server, :kv_engine1, [:test_secret, [1], true])
  end

end