defmodule PKITest do
    use ExUnit.Case, async: true 
    import Tesla.Mock
  
    @vurl "https://test-vault.com"
    @base_url "https://test-vault.com/v1"

    @create_path "/pki/roles/role1"
    @read_path "pki/issue/role1"
    @delete_role_path "/pki/roles/role1"
    @delete_cert_path "/pki/revoke"
  
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
        %{method: :post, url: @base_url <> @create_path} -> 
          %Tesla.Env{status: 200, body: %{}}
                 
        # read
        %{method: :post, url: @base_url <> @read_path} -> 
          %Tesla.Env{status: 200, body: %{
            "data" => %{
                "certificate" => "Certificate itself",
                "issuing_ca" => "CA certificate here",
                "ca_chain" => ["Root cert", "Intermediate cert"],
                "private_key" => "[some private key goes here]",
                "private_key_type" => "rsa",
                "serial_number" => "5b:65:31:58"
            },
            "lease_duration" => 0,
          }
        }
          
        # delete role
        %{method: :delete, url: @base_url <> @delete_role_path} -> 
          %Tesla.Env{status: 204, body: %{}}
  
        # delete certificate
        %{method: :post, url: @base_url <> @delete_cert_path} -> 
          %Tesla.Env{status: 204, body: %{}}
        end
          )
          
      :ok
    end
  
    test "create role" do
      {:ok, server} = Ptolemy.start(:production, :server2)
      assert {:ok, "PKI role created"} === Ptolemy.create(server, :pki_engine1, [:test_role1, %{allow_any_name: true}])
    end
  
    test "get cert from role" do
      {:ok, server} = Ptolemy.start(:production, :server2)
      {:ok, body} = Ptolemy.read(server, :pki_engine1, [:test_role1, "www.example.com"])
      assert body === %{
        "data" => %{
            "certificate" => "Certificate itself",
            "issuing_ca" => "CA certificate here",
            "ca_chain" => ["Root cert", "Intermediate cert"],
            "private_key" => "[some private key goes here]",
            "private_key_type" => "rsa",
            "serial_number" => "5b:65:31:58"
        },
        "lease_duration" => 0,
      }
    end
    
    test "update role" do
      {:ok, server} = Ptolemy.start(:production, :server2)
      assert {:ok, "PKI role created"} === Ptolemy.update(server, :pki_engine1, [:test_role1, %{allow_any_name: false}])
    end
    
    test "delete cert" do
      {:ok, server} = Ptolemy.start(:production, :server2)
      assert {:ok, "PKI certificate revoked"} === Ptolemy.delete(server, :pki_engine1, [:certificate, "5b:65:31:58"])
    end
    
    test "delete role" do
      {:ok, server} = Ptolemy.start(:production, :server2)
      assert {:ok, "PKI role revoked"} === Ptolemy.delete(server, :kv_engine1, [:role, :test_role1])
    end
  
    test "bang functions" do
      {:ok, server} = Ptolemy.start(:production, :server2)
      alias Ptolemy.Engines.PKI
      assert :ok === PKI.create!(server, :pki_engine1, :test_role1, %{allow_any_name: true})
      assert {:ok, %{
        "data" => %{
            "certificate" => "Certificate itself",
            "issuing_ca" => "CA certificate here",
            "ca_chain" => ["Root cert", "Intermediate cert"],
            "private_key" => "[some private key goes here]",
            "private_key_type" => "rsa",
            "serial_number" => "5b:65:31:58"
        },
        "lease_duration" => 0,
      }} === PKI.read!(server, :pki_engine1, :test_role1, "www.example.com")
      assert :ok = PKI.update!(server, :pki_engine1, :test_role1, %{allow_any_name: false})
      assert :ok = PKI.delete!(server, :pki_engine1, :certificate, "5b:65:31:58")
      assert :ok = PKI.delete!(server, :pki_engine1, :role, :test_role1)
    end
  
  end