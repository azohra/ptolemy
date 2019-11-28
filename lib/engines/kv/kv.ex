defmodule Ptolemy.Engines.KV do
  @moduledoc """
  `Ptolemy.Engines.KV` provides a public facing API for CRUD operations for the Vault KV2 engine.
  """

  alias Ptolemy.Engines.KV.Engine
  alias Ptolemy.Server

  @doc """
  Fetches all of a secret's keys and value via the `:kv_engine` configuration.

  See `fetch/2` for the description of the silent and version options.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.read(:production, :engine1, :ptolemy)
  {:ok, %{
      "test" => i am some value"
      ...
    }
  }
  ```
  """
  @spec read(atom(), atom(), atom(), boolean(), integer()) ::
          {:ok, String.t()} | {:error, String.t()}
  def read(server_name, engine_name, secret, silent \\ false, version \\ 0) do
    path = get_kv_path!(server_name, engine_name, secret, "data")
    path_read(server_name, path, silent, version)
  end

  @doc """
  Fetches all of a secret's keys and value via the `:kv_engine` configuration, errors out if an error occurs.
  """
  @spec read!(atom(), atom(), atom(), boolean(), integer()) :: any() | no_return()
  def read!(server_name, engine_name, secret, silent \\ false, version \\ 0) do
    case read(server_name, engine_name, secret, silent, version) do
      {:error, msg} -> raise RuntimeError, message: msg
      {:ok, resp} -> resp
    end
  end

  @doc """
  Fetches all of a given secret's key and values from a KV engine via the specified path.

  This function returns the full reponse of the remote vault server, enabling the silent option will only return a map with the key and value of the secret.
  The version option will allow you to fetch specific version of the target secret.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_read(:production, "secret/data/ptolemy")
  {:ok, %{
      "Foo" => test"
      ...
    }
  }
  ```
  """
  @spec path_read(atom(), String.t(), boolean(), integer()) ::
          {:ok, String.t()} | {:error, String.t()}
  def path_read(server_name, secret, silent \\ false, version \\ 0) when is_bitstring(secret) do
    client = create_client(server_name)
    opts = [version: version]

    {_err, resp} = Engine.read_secret(client, secret, opts)

    case resp do
      %{} ->
        case silent do
          true ->
            {:ok,
             resp
             |> Map.get("data")
             |> Map.get("data")}

          false ->
            {:ok, resp}
        end

      _ ->
        {:error, "Read from kv engine failed"}
    end
  end

  @doc """
  Updates an already existing secret via the `:kv_engine` configuration.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.update(:production, :engine1, :ptolemy, %{test: "i am  a new value from config"})
  {:ok, "KV secret updated"}
  ```
  """
  @spec update(atom(), atom(), atom(), map(), integer() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def update(server_name, engine_name, secret, payload, cas \\ nil) do
    path = get_kv_path!(server_name, engine_name, secret, "data")
    path_update(server_name, path, payload, cas)
  end

  @doc """
  Updates an already existing secret via the `:kv_engine` configuration, errors out if an error occurs.
  """
  @spec update!(atom(), atom(), atom(), map(), integer() | nil) :: :ok | no_return()
  def update!(server_name, engine_name, secret, payload, cas \\ nil) do
    case update(server_name, engine_name, secret, payload, cas) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Updates an already existing secret via the specified path.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_update(:production, "secret/data/ptolemy", %{test: "i am up-to-date from path"}, 1)
  {:ok, "KV secret updated"}
  ```
  """
  @spec path_update(atom(), String.t(), map()) ::
          {:ok, String.t()} | {:error, String.t()}
  def path_update(server_name, secret, payload, cas \\ nil) when is_bitstring(secret) do
    case path_create(server_name, secret, payload, cas) do
      {:ok, _} -> {:ok, "KV secret updated"}
      err -> err
    end
  end

  @doc """
  Creates a secret according to the path specified in the `:kv_engine` specification.

  ## Example
  ```
  iex(2)> Ptolemy.Engines.KV.create(:production, :engine1, :ptolemy, %{test: "i was created from config"})
  {:ok, "KV secret created"}
  ```
  """
  @spec create(atom(), atom(), atom(), map(), integer() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def create(server_name, engine_name, secret, payload, cas \\ nil) do
    path = get_kv_path!(server_name, engine_name, secret, "data")
    path_create(server_name, path, payload, cas)
  end

  @doc """
  Creates a secret according to the path specified in the ":kv_engine" specification, errors out if an error occurs.
  """
  @spec create!(atom(), atom(), atom(), map(), integer() | nil) :: :ok | no_return()
  def create!(server_name, engine_name, secret, payload, cas \\ nil) do
    case create(server_name, engine_name, secret, payload, cas) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Creates a new secret via a KV engine at the specified path.

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_create(:production, "secret/data/new", %{test: "i am created from path"})
  {:ok, "KV secret created"}
  """
  @spec path_create(atom(), String.t(), map(), integer() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def path_create(server_name, secret, payload, cas \\ nil) when is_bitstring(secret) do
    client = create_client(server_name)
    Engine.create_secret(client, secret, payload, cas)
  end

  @doc """
  Deletes a secific version of a secret via the `:kv_engine` configuration.

  Specifying false under the destroy paramter will "delete" the secret (secret will be sent to recyling bin),
  sepcifying true will permanently destroy the secret.

  ```elixir
  iex(2)> Ptolemy.Engines.KV.delete(:production, :engine1, :ptolemy, [1,2], false)
  {:ok, "KV secret deleted"}
  ```
  """
  @spec delete(atom(), atom(), atom(), nonempty_list(integer()), boolean()) ::
          {:ok, String.t()} | {:error, String.t()}
  def delete(server_name, engine_name, secret, vers, destroy \\ false) do
    case destroy do
      true ->
        path = get_kv_path!(server_name, engine_name, secret, "destroy")
        path_destroy(server_name, path, vers)

      false ->
        path = get_kv_path!(server_name, engine_name, secret, "delete")
        path_delete(server_name, path, vers)
    end
  end

  @doc """
  Deletes a secific version of a secret via the `:kv_engine` configuration, errors out if an errors occurs.
  """
  @spec delete!(atom(), atom(), atom(), nonempty_list(integer()), boolean()) :: :ok | no_return()
  def delete!(server_name, engine_name, secret, vers, destroy \\ false) do
    case delete(server_name, engine_name, secret, vers, destroy) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Deletes a secific version of a secret at a specified path.

  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_delete(:production, "secret/delete/ptolemy", [1,2])
  {:ok, "KV secret deleted"}
  ```
  """
  @spec path_delete(atom(), String.t(), nonempty_list(integer())) ::
          {:ok, String.t()} | {:error, String.t()}
  def path_delete(server_name, secret, vers) do
    client = create_client(server_name)
    Engine.delete(client, secret, vers)
  end

  @doc """
  Destroys a secific version of a secret via the `:kv_engine` configuration.

  ```elixir
  iex(2)> Ptolemy.Engines.KV.destroy(:production, :engine1, :ptolemy, [1,2])
  {:ok, "KV secret destroyed"}
  ```
  """
  @spec destroy(atom(), atom(), String.t(), nonempty_list(integer())) ::
          {:ok, String.t()} | {:error, String.t()}
  def destroy(server_name, engine_name, secret, vers) do
    path = get_kv_path!(server_name, engine_name, secret, "destroy")
    path_destroy(server_name, path, vers)
  end

  @doc """
  Destroys a secific version of a secret via the `:kv_engine` configuration, errors out if an error occurs.
  """
  @spec destroy!(atom(), atom(), String.t(), nonempty_list(integer())) :: :ok | no_return()
  def destroy!(server_name, engine_name, secret, vers) do
    case destroy(server_name, engine_name, secret, vers) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Destroys a specific version of secret at a specified path.

  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_destroy(:production, "secret/destroy/ptolemy", [1,2])
  {:ok, "KV secret destroyed"}
  ```
  """
  @spec path_destroy(atom(), String.t(), nonempty_list(integer())) ::
          {:ok, String.t()} | {:error, String.t()}
  def path_destroy(server_name, secret, vers) do
    client = create_client(server_name)
    Engine.destroy(client, secret, vers)
  end

  # Tesla client function
  defp create_client(server_name) do
    creds = Server.fetch_credentials(server_name)
    http_opts = Server.get_data(server_name, :http_opts)
    {:ok, url} = Server.get_data(server_name, :vault_url)

    Tesla.client([
      {Tesla.Middleware.BaseUrl, "#{url}/v1"},
      {Tesla.Middleware.Headers, creds},
      {Tesla.Middleware.Opts, http_opts},
      {Tesla.Middleware.JSON, []}
    ])
  end

  # Helper functions to make paths
  defp get_kv_path!(server_name, engine_name, secret, operation) when is_atom(secret) do
    with {:ok, conf} <- Server.get_data(server_name, :engines),
         {:ok, kv_conf} <- Keyword.fetch(conf, engine_name),
         %{engine_path: path, secrets: secrets} <- kv_conf do
      {:ok, secret_path} = Map.fetch(secrets, secret)
      make_kv_path!(path, secret_path, operation)
    else
      {:error, "Not found!"} -> raise("#{server_name} does not have a kv_engine config")
      :error -> raise("Could not find engine_name in specified config")
    end
  end

  defp get_kv_path!(server_name, engine_name, secret, operation) when is_bitstring(secret) do
    with {:ok, conf} <- Server.get_data(server_name, :engines),
         {:ok, kv_conf} <- Keyword.fetch(conf, engine_name),
         %{engine_path: path, secrets: _secrets} <- kv_conf do
      make_kv_path!(path, secret, operation)
    else
      {:error, "Not found!"} -> raise("#{server_name} does not have a kv_engine config")
      :error -> raise("Could not find engine_name in specified config")
    end
  end

  defp make_kv_path!(engine_path, secret_path, operation) do
    "/#{engine_path}#{operation}#{secret_path}"
  end
end
