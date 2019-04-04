defmodule Ptolemy.Engines.KV do
  @moduledoc """
  `Ptolemy.Engines.KV` provides interaction with Vaults KV2 Engine
  """

  alias Ptolemy.Engines.KV.Engine
  alias Ptolemy.Server

  @doc """
  Read a specific key from given secret via the `:kv_engine` configuration.
  Specifying a version will read that specific version.
  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.read(:production, :engine1, :ptolemy, "test")
  {:ok, "test"}
  ```
  """
  @spec read(pid(), atom(), atom(), String.t(), integer) :: {:ok | :error, String.t()}
  def read(pid, engine_name, secret, key, version \\ 0) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    path_read(pid, path, key, version)
  end

  @doc """
  Same as function without an exclamation mark, but it raise an exception when failed, refer to above
  """
  @spec read!(pid(), atom(), atom(), String.t(), integer) :: {:ok, String.t()}
  def read!(pid, engine_name, secret, key, version \\ 0) do
    case read(pid, engine_name, secret, key, version) do
      {:error, msg} -> raise RuntimeError, message: msg
      resp -> resp
    end
  end

  @doc """
  Read a specific key from given secret via a KV engine.
  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_read(:production, "secret/data/ptolemy", "test")
  {:ok, "test"}
  ```
  """
  @spec path_read(pid(), String.t(), String.t(), integer) :: {:ok | :error, String.t()}
  def path_read(pid, secret_path, key, version \\ 0) do
    with {:ok, map} <- path_fetch(pid, secret_path, true, version),
         {:ok, values} <- Map.fetch(map, key) do
      {:ok, values}
    else
      :error -> {:error, "Could not find: #{key} in the remote vault server"}
    end
  end

  @doc """
  Fetches all of a secret's keys and value via the `:kv_engine` configuration.
  See `fetch/2` for the description of the silent and version options.
  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.fetch(:production, :engine1, :ptolemy)
  {:ok, %{
      "test" => i am some value"
      ...
    }
  }
  ```
  """
  @spec fetch(pid(), atom(), atom(), boolean, integer) :: {:ok | :error, String.t()}
  def fetch(pid, engine_name, secret, silent \\ false, version \\ 0) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    path_fetch(pid, path, silent, version)
  end

  @doc """
  Same as function without an exclamation mark, but it raise an exception when failed, refer to above
  """
  @spec fetch!(pid(), atom(), atom(), boolean, integer) :: {:ok | :error, String.t()}
  def fetch!(pid, engine_name, secret, silent \\ false, version \\ 0) do
    case fetch(pid, engine_name, secret, silent, version) do
      {:error, msg} -> raise RuntimeError, message: msg
      resp -> resp
    end
  end

  @doc """
  Fetches all of a  given secret's key and values from a KV engine
  This function returns the full reponse of the remote vault server, enabling the silent option will only return a map with the key and value
  of the secret. The version option will allow you to fetch specific version of the target secret.
  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_fetch(:production, "secret/data/ptolemy")
  {:ok, %{
      "Foo" => test"
      ...
    }
  }
  ```
  """
  @spec path_fetch(pid(), String.t(), boolean, integer) :: {:ok | :error, String.t()}
  def path_fetch(pid, secret, silent \\ false, version \\ 0) when is_bitstring(secret) do
    client = create_client(pid)
    opts = [version: version]

    {:ok, resp} = Engine.read_secret(client, secret, opts)

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
        {:error, "Fetch from kv engine failed"}
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
  @spec update(pid(), atom(), atom(), map(), integer) :: {:ok | :error, String.t()}
  def update(pid, engine_name, secret, payload, cas \\ nil) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    path_update(pid, path, payload, cas)
  end

  @doc """
  Same as function without an exclamation mark, but it raise an exception when failed, refer to above
  """
  @spec update!(pid(), atom(), atom(), map(), integer) :: :ok
  def update!(pid, engine_name, secret, payload, cas \\ nil) do
    case update(pid, engine_name, secret, payload, cas) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Updates an already existing secret.
  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_update(:production, "secret/data/ptolemy", %{test: "i am up-to-date from path"}, 1)
  {:ok, "KV secret updated"}
  ```
  """
  @spec path_update(pid(), String.t(), integer) :: {:ok | :error, String.t()}
  def path_update(pid, secret, payload, cas \\ nil) when is_bitstring(secret) do
    case path_create(pid, secret, payload, cas) do
      {:ok, _} -> {:ok, "KV secret updated"}
      err -> err
    end
  end

  @doc """
  Creates a secret according to the path specified in the ":kv_engine" specification

  ## Example
  ```
  iex(2)> Ptolemy.Engines.KV.create(:production, :engine1, :ptolemy, %{test: "i was created from config"})
  {:ok, "KV secret created"}
  ```
  """
  @spec create(pid(), atom(), atom(), map(), integer) :: :ok
  def create(pid, engine_name, secret, payload, cas \\ nil) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    path_create(pid, path, payload, cas)
  end

  @doc """
  Same as function without an exclamation mark, but it raise an exception when failed, refer to above
  """
  @spec create!(pid(), atom(), atom(), map(), integer) :: :ok
  def create!(pid, engine_name, secret, payload, cas \\ nil) do
    case create(pid, engine_name, secret, payload, cas) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Creates a new secret via a KV engine
  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_create(:production, "secret/data/new", %{test: "i am created from path"})
  {:ok, "KV secret created"}
  """
  @spec path_create(pid(), String.t(), map(), integer) :: {:ok | :error, String.t()}
  def path_create(pid, secret, payload, cas \\ nil) when is_bitstring(secret) do
    client = create_client(pid)
    Engine.create_secret(client, secret, payload, cas)
  end

  @doc """
  Deletes a secific version of a secret via the `:kv_engine` configuration.
  ```elixir
  iex(2)> Ptolemy.Engines.KV.delete(:production, :engine1, :ptolemy, [1,2])
  {:ok, "KV secret deleted"}
  ```
  """
  @spec delete(pid(), atom(), atom(), integer, boolean) :: {:ok | :error, String.t()}
  def delete(pid, engine_name, secret, vers, destroy \\ false) do
    case destroy do
      true ->
        path = get_kv_path!(pid, engine_name, secret, "destroy")
        path_destroy(pid, path, vers)

      false ->
        path = get_kv_path!(pid, engine_name, secret, "delete")
        path_delete(pid, path, vers)
    end
  end

  @doc """
  Same as function without an exclamation mark, but it raise an exception when failed, refer to above
  """
  @spec delete!(pid(), atom(), atom(), integer, boolean) :: :ok
  def delete!(pid, engine_name, secret, vers, destroy \\ false) do
    case delete(pid, engine_name, secret, vers, destroy) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Deletes a secific version of a secret.
  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_delete(:production, "secret/delete/ptolemy", [1,2])
  {:ok, "KV secret deleted"}
  ```
  """
  @spec path_delete(pid(), String.t(), integer) :: {:ok | :error, String.t()}
  def path_delete(pid, secret, vers) do
    client = create_client(pid)
    Engine.delete(client, secret, vers)
  end

  @doc """
  Destroys a secific version of a secret via the `:kv_engine` configuration.
  ```elixir
  iex(2)> Ptolemy.Engines.KV.destroy(:production, :engine1, :ptolemy, [1,2])
  {:ok, "KV secret destroyed"}
  ```
  """
  @spec destroy(pid(), atom(), atom(), integer) :: {:ok | :error, String.t()}
  def destroy(pid, engine_name, secret, vers) do
    path = get_kv_path!(pid, engine_name, secret, "destroy")
    path_destroy(pid, path, vers)
  end

  @doc """
  Same as function without an exclamation mark, but it raise an exception when failed, refer to above
  """
  @spec destroy!(pid(), atom(), atom(), integer) :: :ok
  def destroy!(pid, engine_name, secret, vers) do
    case destroy(pid, engine_name, secret, vers) do
      {:error, msg} -> raise RuntimeError, message: msg
      _resp -> :ok
    end
  end

  @doc """
  Destroys a specific version of secret.
  ```elixir
  iex(2)> Ptolemy.Engines.KV.path_destroy(:production, "secret/destroy/ptolemy", [1,2])
  {:ok, "KV secret destroyed"}
  ```
  """
  @spec path_destroy(pid(), atom(), integer) :: {:ok | :error, String.t()}
  def path_destroy(pid, secret, vers) do
    client = create_client(pid)
    Engine.destroy(client, secret, vers)
  end

  # Tesla client function
  defp create_client(pid) do
    creds = Server.fetch_credentials(pid)
    {:ok, url} = Server.get_data(pid, :vault_url)

    Tesla.client([
      {Tesla.Middleware.BaseUrl, "#{url}/v1"},
      {Tesla.Middleware.Headers, creds},
      {Tesla.Middleware.JSON, []}
    ])
  end

  # Helper functions to make paths
  defp get_kv_path!(pid, engine_name, secret, operation) when is_atom(secret) do
    with {:ok, conf} <- Server.get_data(pid, :engines),
         {:ok, kv_conf} <- Keyword.fetch(conf, engine_name),
         %{engine_path: path, secrets: secrets} <- kv_conf do
      {:ok, secret_path} = Map.fetch(secrets, secret)
      make_kv_path!(path, secret_path, operation)
    else
      {:error, "Not found!"} -> raise("#{pid} does not have a kv_engine config")
      :error -> raise("Could not find engine_name in specified config")
    end
  end

  defp get_kv_path!(pid, engine_name, secret, operation) when is_bitstring(secret) do
    with {:ok, conf} <- Server.get_data(pid, :engines),
         {:ok, kv_conf} <- Keyword.fetch(conf, engine_name),
         %{engine_path: path, secrets: _secrets} <- kv_conf do
      make_kv_path!(path, secret, operation)
    else
      {:error, "Not found!"} -> raise("#{pid} does not have a kv_engine config")
      :error -> raise("Could not find engine_name in specified config")
    end
  end

  defp make_kv_path!(engine_path, secret_path, operation) do
    "/#{engine_path}#{operation}#{secret_path}"
  end
end
