defmodule Ptolemy.Engines.PKI do
    @moduledoc """
    `Ptolemy.Engine.PKI` provides a public facing API for CRUD operations using the config file
  
    Functions with `path_` prefix takes in the path to the certificate/role as an input instead
    of constructing path using the configurations. These functions allow users to use the vault
    interface without configuring path of the role.
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
    @spec create(pid(), atom(), atom(), map()) :: {:ok | :error, String.t()}
    def create(pid, engine_name, role, payload \\ %{}) do
      path = get_pki_path!(pid, engine_name, role, "roles")
      path_create(pid, path, payload)
    end

    @spec create!(pid(), atom(), atom(), map()) :: :ok
    def create!(pid, engine_name, role, payload \\ %{}) do
      case create(pid, engine_name, role, payload) do
        {:error, msg} -> raise RuntimeError, message: msg
        _resp -> :ok
      end
    end
    
    @spec path_create(pid(), String.t(), map()) :: {:ok | :error, String.t()}
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
    @spec read(pid(), atom(), atom(), String.t(), map()) :: {:ok | :error, String.t()}
    def read(pid, engine_name, role, common_name, payload \\ %{}) do
      path = get_pki_path!(pid, engine_name, role, "issue")
      path_read(pid, path, common_name, payload)
    end
    
    @doc """
    The same as read(), except it raises an exception when error occurs like all bang functions
    """
    @spec read!(pid(), atom(), atom(), String.t(), map()) :: :ok
    def read!(pid, engine_name, role, common_name, payload \\ %{}) do
      case read(pid, engine_name, role, common_name, payload) do
        {:error, msg} -> raise RuntimeError, message: msg
        {:ok, resp} -> resp
      end
    end

    @spec path_read(pid(), String.t(), String.t(), map()) :: {:ok | :error, String.t()}
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
    @spec update(pid(), atom(), atom(), map()) :: {:ok | :error, String.t()}
    def update(pid, engine_name, role, payload \\ %{}) do
      path = get_pki_path!(pid, engine_name, role, "roles")
      path_update(pid, path, payload)
    end

    @spec update!(pid(), atom(), atom(), map()) :: :ok
    def update!(pid, engine_name, secret, payload \\ %{}) do
      case update(pid, engine_name, secret, payload) do
        {:error, msg} -> raise RuntimeError, message: msg
        _resp -> :ok
      end
    end
  
    @spec path_update(pid(), String.t(), map()) :: {:ok | :error, String.t()}
    def path_update(pid, path, payload \\ %{}) do
      client = create_client(pid)
      case Engine.create_role(client, path, payload) do
        {:ok, _} ->  {:ok, "PKI role updated"}
        err -> err
      end
    end
    
    @doc """
    Either revoke a certificate or revoke a role from vault      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.delete(server, :pki_engine1, :certificate, "17:84:7f:5b:bd:90:da:21:16")
    iex(3)> Ptolemy.Engines.PKI.delete(server, :pki_engine1, :role, :test_role1)
    ```
    """
    @spec delete(pid(), atom(), String.t(), any()) :: {:ok | :error, String.t()}
    def delete(pid, engine_name, deleteType, arg1) do
      case deleteType do
        :certificate -> delete_cert(pid, engine_name, arg1)
        :role -> delete_role(pid, engine_name, arg1)
      end
    end

    @spec delete!(pid(), atom(), String.t(), any()) :: :ok
    def delete!(pid, engine_name, deleteType, arg1) do
      case delete(pid, engine_name, deleteType, arg1) do
        {:ok, _} -> :ok
        _ -> raise "Failed to delete from PKI engine"
      end
    end
    @doc """
    Revoke a certificate in vault
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.delete_cert(server, :pki_engine1, serial_number)
    ```
    """
    @spec delete_cert(pid(), atom(), String.t()) :: {:ok | :error, String.t()}
    def delete_cert(pid, engine_name, serial_number) do
      path = get_pki_path!(pid, engine_name, "revoke")
      path_delete_cert(pid, path, serial_number)
    end
  
    @spec path_delete_cert(pid(), String.t(), String.t()) :: {:ok | :error, String.t()}
    def path_delete_cert(pid, path, serial_number) do
      client = create_client(pid)
      Engine.revoke_cert(client, path, serial_number)
    end
    
    @doc """
    Revoke a role in vault
      
    ## Example
    ```elixir
    iex(2)> Ptolemy.Engines.PKI.delete_role(server, :pki_engine1, :test_role1)
    ```
    """
    @spec delete_role(pid(), atom(), atom()) :: {:ok | :error, String.t()}
    def delete_role(pid, engine_name, role) do
      path = get_pki_path!(pid, engine_name, role, "roles")
      path_delete_role(pid, path) 
    end

    @spec path_delete_role(pid(), String.t()) :: {:ok | :error, String.t()}
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
        {:error, "Not found!"} -> raise "#{pid} does not have a pki_engine config"
        :error -> raise "Could not find engine_name in specified config"
      end
    end

    defp get_pki_path!(pid, engine_name, operation) do
        with {:ok, conf} <- Server.get_data(pid, :engines),
        {:ok, pki_conf} <- Keyword.fetch(conf, engine_name),
        %{engine_path: path} <- pki_conf
      do
        "/#{path}#{operation}"
      else
        {:error, "Not found!"} -> raise "#{pid} does not have a pki_engine config"
        :error -> raise "Could not find engine_name in specified config"
      end
    end
  
    defp make_pki_path!(engine_path, role_path, operation) do
      "/#{engine_path}#{operation}#{role_path}"
    end
  end