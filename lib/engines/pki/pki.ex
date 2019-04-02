defmodule Ptolemy.Engines.PKI do
    @moduledoc """
    `Ptolemy.Engine.PKI` provides a public facing API for CRUD operations using the config file
  
    All functions start with an additional c implies the function uses the secret configuration
  
    The other functions act as a mask to the appropriate functions in the engine
    """
  
      
    alias Ptolemy.Engines.PKI.Engine
    alias Ptolemy.Server
    @doc """
    Create a role from the specification provided
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.ccreate!(server, :pki_engine1, :role1, %{allow_any_name: true})
    ```
    """
    def ccreate!(pid, engine_name, role, payload \\ %{}) do
      path = get_pki_path!(pid, engine_name, role, "roles")
      create!(pid, path, payload)
    end
    
    def create!(pid, path, payload \\ %{}) do
      client = create_client(pid)
      resp = Engine.create_role!(client, path, payload)
      case resp do
        status when status in 200..299 -> :ok
        _ -> :error
      end
    end
    
    @doc """
    Generate a certificate from the role
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.cread!(server, :pki_engine1, :role1, "www.example.com")
    ```
    """
    def cread!(pid, engine_name, role, common_name, payload \\ %{}) do
      path = get_pki_path!(pid, engine_name, role, "issue")
      read!(pid, path, common_name, payload)
    end
  
    def read!(pid, path, common_name, payload) do
      client = create_client(pid)
      resp = Engine.generate_secret!(client, path, common_name, payload)
      case resp do
        %{} -> {:ok, resp}
        _ -> {:error, "Certificate generation failed"}
      end
    end
  
    @doc """
    Update a role in vault
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.cupdate!(server, :pki_engine1, :role1, %{allow_any_name: false}
    ```
    """
    def cupdate!(pid, engine_name, role, payload \\ %{}) do
      path = get_pki_path!(pid, engine_name, role, "roles")
      update!(pid, path, payload)
    end
  
    def update!(pid, path, payload \\ %{}) do
      client = create_client(pid)
      resp = Engine.create_role!(client, path, payload)
      case resp do
        status when status in 200..299 -> :ok
        _ -> :error
      end
    end
  
    @doc """
    Revoke a certificate in vault
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.cdeleteCert!(server, :pki_engine1, serial_number)
    ```
    """
    def cdeleteCert!(pid, engine_name, serial_number) do
      path = get_pki_path!(pid, engine_name, "revoke")
      deleteCert!(pid, path, serial_number)
    end
  
    def deleteCert!(pid, path, serial_number) do
      client = create_client(pid)
      resp = Engine.revoke_cert!(client, path, serial_number)
      case resp do
        status when status in 200..299 -> :ok
        _ -> :error
      end
    end
    
    @doc """
    Revoke a role in vault
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.cdeleteRole!(server, :pki_engine1, :role1)
    ```
    """
    def cdeleteRole!(pid, engine_name, role) do
      path = get_pki_path!(pid, engine_name, role, "roles")
      deleteRole!(pid, path) 
    end

    def deleteRole!(pid, path) do
      client = create_client(pid)
      resp = Engine.revoke_role!(client, path)
      case resp do
        status when status in 200..299 -> :ok
        _ -> :error
      end
    end
  
    #Tesla client function
    defp create_client(pid) do
      creds = Server.fetch_credentials(pid)
      {:ok, url} = Server.get_data(pid, :vault_url)
  
      Tesla.client([
        {Tesla.Middleware.BaseUrl, "#{url}/v1"},
        {Tesla.Middleware.Headers, creds},
        {Tesla.Middleware.JSON, []}
      ])
    end
  
    #Helper functions to make paths
    defp get_pki_path!(pid, engine_name, role, operation) when is_atom(role) do
      with {:ok, conf} <- Server.get_data(pid, :engines),
        {:ok, pki_conf} <- Keyword.fetch(conf, engine_name),
        %{engine_path: path, roles: roles} <- pki_conf
      do
        {:ok, role} = Map.fetch(roles, role)
        make_pki_path!(path, role, operation)
      else
        {:error, "Not found!"} -> throw "#{pid} does not have a pki_engine config"
        :error -> throw "Could not find engine_name in specified config"
      end
    end
  
  
    defp get_pki_path!(pid, engine_name, role, operation) when is_bitstring(role) do
      with {:ok, conf} <- Server.get_data(pid, :engines),
        {:ok, pki_conf} <- Keyword.fetch(conf, engine_name),
        %{engine_path: path, roles: roles} <- pki_conf
      do
        {:ok, role} = Map.fetch(roles, role)
        make_pki_path!(path, role, operation)
      else
        {:error, "Not found!"} -> throw "#{pid} does not have a pki_engine config"
        :error -> throw "Could not find engine_name in specified config"
      end
    end

    defp get_pki_path!(pid, engine_name, operation) do
        with {:ok, conf} <- Server.get_data(pid, :engines),
        {:ok, pki_conf} <- Keyword.fetch(conf, engine_name),
        %{engine_path: path} <- pki_conf
      do
        "/#{path}#{operation}"
      else
        {:error, "Not found!"} -> throw "#{pid} does not have a pki_engine config"
        :error -> throw "Could not find engine_name in specified config"
      end
    end
  
    defp make_pki_path!(engine_path, role_path, operation) do
      "/#{engine_path}#{operation}#{role_path}"
    end
  end