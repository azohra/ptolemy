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
    iex(2)> Ptolemy.Engines.PKI.create(server, :pki_engine1, :test_role1, %{allow_any_name: true})
    ```
    """
    def create(pid, engine_name, role, payload \\ %{}) do
      path = get_pki_path!(pid, engine_name, role, "roles")
      path_create(pid, path, payload)
    end

    def create!(pid, engine_name, role, payload \\ %{}) do
      case create(pid, engine_name, role, payload) do
        {:error, msg} -> raise RuntimeError, message: msg
        :error -> raise RuntimeError, message: "Failed to create certificate from #{role}"
        _resp -> :ok
      end
    end
    
    def path_create(pid, path, payload \\ %{}) do
      client = create_client(pid)
      Engine.create_role(client, path, payload)
    end
    
    @doc """
    Generate a certificate from the role
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.read(server, :pki_engine1, :test_role1, "www.example.com")
    ```
    """
    def read(pid, engine_name, role, common_name, payload \\ %{}) do
      path = get_pki_path!(pid, engine_name, role, "issue")
      path_read(pid, path, common_name, payload)
    end
    
    @doc """
    The same as read(), except it raises an exception when error occurs like all bang functions
    """
    def read!(pid, engine_name, role, common_name, payload \\ %{}) do
      case read(pid, engine_name, role, common_name, payload) do
        {:error, msg} -> raise RuntimeError, message: msg
        resp -> resp
      end
    end

    def path_read(pid, path, common_name, payload) do
      client = create_client(pid)
      Engine.generate_secret(client, path, common_name, payload)
    end
  
    @doc """
    Update a role in vault
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.update(server, :pki_engine1, :test_role1, %{allow_any_name: false})
    ```
    """
    def update(pid, engine_name, role, payload \\ %{}) do
      path = get_pki_path!(pid, engine_name, role, "roles")
      path_update(pid, path, payload)
    end

    def update!(pid, engine_name, secret, payload \\ %{}) do
      case update(pid, engine_name, secret, payload) do
        {:error, msg} -> raise RuntimeError, message: msg
        _resp -> :ok
      end
    end
  
    def path_update(pid, path, payload \\ %{}) do
      client = create_client(pid)
      Engine.create_role(client, path, payload)
    end
    
    @doc """
    Either revoke a certificate or revoke a role from vault      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.delete(server, :pki_engine1, :certificate, "17:84:7f:5b:bd:90:da:21:16")
    iex(3)> Ptolemy.Engines.PKI.delete(server, :pki_engine1, :role, :test_role1)
    ```
    """
    def delete(pid, engine_name, deleteType, arg1) do
      case deleteType do
        :certificate -> delete_cert(pid, engine_name, arg1)
        :role -> delete_role(pid, engine_name, arg1)
      end
    end

    def delete!(pid, engine_name, deleteType, arg1) do
      case delete(pid, engine_name, deleteType, arg1) do
        {:ok, body} -> :ok
        _ -> raise "Failed to delete from PKI engine"
      end
    end
    @doc """
    Revoke a certificate in vault
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.cdeleteCert!(server, :pki_engine1, serial_number)
    ```
    """
    def delete_cert(pid, engine_name, serial_number) do
      path = get_pki_path!(pid, engine_name, "revoke")
      path_delete_cert(pid, path, serial_number)
    end
  
    def path_delete_cert(pid, path, serial_number) do
      client = create_client(pid)
      Engine.revoke_cert(client, path, serial_number)
    end
    
    @doc """
    Revoke a role in vault
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.delete_role(server, :pki_engine1, :role1)
    ```
    """
    def delete_role(pid, engine_name, role) do
      path = get_pki_path!(pid, engine_name, role, "roles")
      path_delete_role(pid, path) 
    end

    def path_delete_role(pid, path) do
      client = create_client(pid)
      Engine.revoke_role(client, path)
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