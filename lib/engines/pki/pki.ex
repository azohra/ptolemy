defmodule Ptolemy.Engines.PKI do
  @moduledoc """
  `Ptolemy.Engines.PKI` provides a public facing API for CRUD operations for the Vault PKI engine.

  Some function in this modules have additional options that can be provided to vault, you can get the option
  values from: https://www.vaultproject.io/api/secret/pki/index.html
  """

  alias Ptolemy.Engines.PKI.Engine
  alias Ptolemy.Server

  @doc """
  Create a role with a role from the specification provided.

  Optional payload is provided if there is a need to overide other options.
  See https://www.vaultproject.io/api/secret/pki/index.html#create-update-role for options.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.PKI.create(:production, :pki_engine1, :test_role1, %{allow_any_name: true})
  {:ok, "PKI role created"}
  ```
  """
  @spec create(atom(), atom(), atom(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def create(server_name, engine_name, role, params \\ %{}) do
    path = get_pki_path!(server_name, engine_name, role, "roles")
    path_create(server_name, path, params)
  end

  @doc """
  Create a role from the specification provided, errors out if an errors occurs.

  Optional payload is provided if there is a need to overide other options.
  See https://www.vaultproject.io/api/secret/pki/index.html#create-update-role for options.
  """
  @spec create!(atom(), atom(), atom(), map()) :: :ok | no_return()
  def create!(server_name, engine_name, role, params \\ %{}) do
    case create(server_name, engine_name, role, params) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Create a role from the specification provided via a specific path.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.PKI.path_create(:production, "/pki/data/", %{allow_any_name: true})
  {:ok, "PKI role created"}
  ```
  """
  @spec path_create(atom(), String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def path_create(server_name, path, params \\ %{}) do
    client = create_client(server_name)
    Engine.create_role(client, path, params)
  end

  @doc """
  Reads a brand new generated certificate from a role.

  Optional payload is provided if there is a need to overide other options.
  See https://www.vaultproject.io/api/secret/pki/index.html#generate-certificate for options.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.PKI.read(:production, :pki_engine1, :test_role1, "www.example.com")
  {:ok,
    %{
      "auth" => nil,
      "data" => %{
        "certificate" => "-----BEGIN CERTIFICATE-----generated-cert-----END CERTIFICATE-----",
        "expiration" => 1555610944,
        "issuing_ca" => "-----BEGIN CERTIFICATE-----ca-cert-goes-here-----END CERTIFICATE-----",
        "private_key" => "-----BEGIN RSA PRIVATE KEY-----some-rsa-key-here-----END RSA PRIVATE KEY-----",
        "private_key_type" => "rsa",
        "serial_number" => "1c:42:ac:e6:80:4c:7c:fc:70:af:c9:64:55:11:95:84:44:22:6f:e5"
      },
      "lease_duration" => 0,
      "lease_id" => "",
      "renewable" => false,
      "request_id" => "f53c85d0-46ef-df35-349f-dfe4e43ac6d8",
      "warnings" => nil,
      "wrap_info" => nil
    }
  }
  ```
  """
  @spec read(atom(), atom(), atom(), String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def read(server_name, engine_name, role, common_name, payload \\ %{}) do
    path = get_pki_path!(server_name, engine_name, role, "issue")
    path_read(server_name, path, common_name, payload)
  end

  @doc """
  Reads a brand new generated certificate from a role, errors out if an error occurs.
  """
  @spec read!(atom(), atom(), atom(), String.t(), map()) :: map() | no_return()
  def read!(server_name, engine_name, role, common_name, payload \\ %{}) do
    case read(server_name, engine_name, role, common_name, payload) do
      {:error, msg} -> raise RuntimeError, message: msg
      {:ok, resp} -> resp
    end
  end

  @doc """
  Reads a brand new generated certificate from a role via given a specific path.

  Optional payload is provided if there is a need to overide other options.
  See https://www.vaultproject.io/api/secret/pki/index.html#generate-certificate for options.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.PKI.path_read(:production, "/pki/test", "www.example.com")
  {:ok,
    %{
      "auth" => nil,
      "data" => %{
        "certificate" => "-----BEGIN CERTIFICATE-----generated-cert-----END CERTIFICATE-----",
        "expiration" => 1555610944,
        "issuing_ca" => "-----BEGIN CERTIFICATE-----ca-cert-goes-here-----END CERTIFICATE-----",
        "private_key" => "-----BEGIN RSA PRIVATE KEY-----some-rsa-key-here-----END RSA PRIVATE KEY-----",
        "private_key_type" => "rsa",
        "serial_number" => "1c:42:ac:e6:80:4c:7c:fc:70:af:c9:64:55:11:95:84:44:22:6f:e5"
      },
      "lease_duration" => 0,
      "lease_id" => "",
      "renewable" => false,
      "request_id" => "f53c85d0-46ef-df35-349f-dfe4e43ac6d8",
      "warnings" => nil,
      "wrap_info" => nil
    }
  }
  """
  @spec path_read(atom(), String.t(), String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def path_read(server_name, path, common_name, payload \\ %{}) do
    client = create_client(server_name)
    Engine.generate_secret(client, path, common_name, payload)
  end

  @doc """
  Update a pki role in vault.

  Optional payload is provided if there is a need to overide other options.
  See https://www.vaultproject.io/api/secret/pki/index.html#create-update-role for options.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.PKI.update(:production, :pki_engine1, :test_role1, %{allow_any_name: false})
  {:ok, "PKI role updated"}
  ```
  """
  @spec update(atom(), atom(), atom(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def update(server_name, engine_name, role, payload \\ %{}) do
    path = get_pki_path!(server_name, engine_name, role, "roles")
    path_update(server_name, path, payload)
  end

  @doc """
  Update a pki role in vault, errors out if an errors occurs.

  Optional payload is provided if there is a need to overide other options.
  See https://www.vaultproject.io/api/secret/pki/index.html#create-update-role for options.
  """
  @spec update!(atom(), atom(), atom(), map()) :: :ok | no_return()
  def update!(server_name, engine_name, secret, payload \\ %{}) do
    case update(server_name, engine_name, secret, payload) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Update a pki role in vault via a specified path.

  Optional payload is provided if there is a need to overide other options.
  See https://www.vaultproject.io/api/secret/pki/index.html#create-update-role for options.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.PKI.path_update(:production, "pki/test", %{allow_any_name: false})
  {:ok, "PKI role updated"}
  ```
  """
  @spec path_update(atom(), String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def path_update(server_name, path, payload \\ %{}) do
    client = create_client(server_name)

    case Engine.create_role(client, path, payload) do
      {:ok, _} -> {:ok, "PKI role updated"}
      err -> err
    end
  end

  @doc """
  Revoke either a certificate or a role from the pki engine in vault.

  Optional payload is provided if there is a need to overide other options.
  See:
    - For role deletion options: https://www.vaultproject.io/api/secret/pki/index.html#delete-role
    - For cert deletion options:

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.PKI.delete(:production, :pki_engine1, :certificate, "17:84:7f:5b:bd:90:da:21:16")
   {:ok, "PKI certificate revoked"}
  iex(3)> Ptolemy.Engines.PKI.delete(:production, :pki_engine1, :role, :test_role1)
  {:ok, "PKI role revoked"}
  ```
  """
  @spec delete(atom(), atom(), atom(), any()) :: {:ok, String.t()} | {:error, String.t()}
  def delete(server_name, engine_name, deleteType, arg1) do
    case deleteType do
      :certificate -> delete_cert(server_name, engine_name, arg1)
      :role -> delete_role(server_name, engine_name, arg1)
    end
  end

  @doc """
  Revoke either a certificate or a role from the pki engine in vault, errors out if an errors occurs.

  Optional payload is provided if there is a need to overide other options.
  See https://www.vaultproject.io/api/secret/pki/index.html#delete-role for options.
  """
  @spec delete!(atom(), atom(), atom(), any()) :: :ok | no_return()
  def delete!(server_name, engine_name, deleteType, arg1) do
    case delete(server_name, engine_name, deleteType, arg1) do
      {:ok, _} -> :ok
      _ -> raise "Failed to delete from PKI engine"
    end
  end

  @doc """
  Revoke a certificate in vault.

  Optional payload is provided if there is a need to overide other options.
  See https://www.vaultproject.io/api/secret/pki/index.html#delete-role for options.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.PKI.delete_cert(:production, :pki_engine1, serial_number)
  {:ok, "PKI certificate revoked"}
  ```
  """
  @spec delete_cert(atom(), atom(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def delete_cert(server_name, engine_name, serial_number) do
    path = get_pki_path!(server_name, engine_name, "revoke")
    path_delete_cert(server_name, path, serial_number)
  end

  @doc """
  Revoke a certificate in vault.
  """
  @spec path_delete_cert(atom(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def path_delete_cert(server_name, path, serial_number) do
    client = create_client(server_name)
    Engine.revoke_cert(client, path, serial_number)
  end

  @doc """
  Revoke a role in vault.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.PKI.delete_role(:production, :pki_engine1, :test_role1)
  {:ok, "PKI role revoked"}
  ```
  """
  @spec delete_role(atom(), atom(), atom()) :: {:ok, String.t()} | {:error, String.t()}
  def delete_role(server_name, engine_name, role) do
    path = get_pki_path!(server_name, engine_name, role, "roles")
    path_delete_role(server_name, path)
  end

  @doc """
  Revoke a role in vault.
  """
  @spec path_delete_role(atom(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def path_delete_role(server_name, path) do
    client = create_client(server_name)
    Engine.revoke_role(client, path)
  end

  # Tesla client function
  defp create_client(server_name) do
    creds = Server.fetch_credentials(server_name)
    {:ok, http_opts} = Server.get_data(server_name, :http_opts)
    {:ok, url} = Server.get_data(server_name, :vault_url)

    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, "#{url}/v1"},
        {Tesla.Middleware.Headers, creds},
        {Tesla.Middleware.Opts, http_opts},
        {Tesla.Middleware.JSON, []}
      ],
      {Tesla.Adapter.Hackney, [ssl_options: [{:versions, [:"tlsv1.2"]}], recv_timeout: 10_000]}
    )
  end

  # Helper functions to make paths
  defp get_pki_path!(server_name, engine_name, role, operation) when is_atom(role) do
    with {:ok, conf} <- Server.get_data(server_name, :engines),
         {:ok, pki_conf} <- Keyword.fetch(conf, engine_name),
         %{engine_path: path, roles: roles} <- pki_conf do
      {:ok, role} = Map.fetch(roles, role)
      make_pki_path!(path, role, operation)
    else
      {:error, _msg} -> throw("#{server_name} does not have a pki_engine config")
      :error -> throw("Could not find engine_name in specified config")
    end
  end

  defp get_pki_path!(server_name, engine_name, role, operation) when is_bitstring(role) do
    with {:ok, conf} <- Server.get_data(server_name, :engines),
         {:ok, pki_conf} <- Keyword.fetch(conf, engine_name),
         %{engine_path: path, roles: roles} <- pki_conf do
      {:ok, role} = Map.fetch(roles, role)
      make_pki_path!(path, role, operation)
    else
      {:error, _msg} -> raise "#{server_name} does not have a pki_engine config"
      :error -> raise "Could not find engine_name in specified config"
    end
  end

  defp get_pki_path!(server_name, engine_name, operation) do
    with {:ok, conf} <- Server.get_data(server_name, :engines),
         {:ok, pki_conf} <- Keyword.fetch(conf, engine_name),
         %{engine_path: path} <- pki_conf do
      "/#{path}#{operation}"
    else
      {:error, _msg} -> raise "#{server_name} does not have a pki_engine config"
      :error -> raise "Could not find engine_name in specified config"
    end
  end

  defp make_pki_path!(engine_path, role_path, operation) do
    "/#{engine_path}#{operation}#{role_path}"
  end
end
