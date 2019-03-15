defmodule Ptolemy.Engines.KV do
  @moduledoc """
  `Ptolemy.Engines.KV.Vault` 
  """

  @doc """
  Read a specific key from given secret via the `:kv_engine` configuration.

  Specifying a version will read that specific version.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_cread(:production, :kv_engine1, :ptolemy, "foo")
  {:ok, "test"} 
  ```
  """

  alias Ptolemy.Engines.KV.Engine
  alias Ptolemy.Server

  def kv_cread(pid, engine_name, secret, key, version \\ 0) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    kv_read(pid, path, key, version)
  end

  @doc """
  Read a specific key from given secret via a KV engine.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_cread(:production, "secret/data/ptolemy", "foo")
  {:ok, "test"} 
  ```
  """
  def kv_read(pid, secret_path, key, version \\ 0) do
    with map <- kv_fetch!(pid, secret_path, true, version),
      {:ok, values} <- Map.fetch(map, key)
    do
      {:ok, values}
    else
      :error -> {:error, "Could not find: #{key} in the remote vault server"}
    end
  end

  @doc """
  Fetches all of a secret's keys and value via the `:kv_engine` configuration.
  
  See `kv_fetch!/2` for the description of the silent and version options.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_cfetch!(:production, :kv_engine1, :ptolemy)
  %{ 
      "Foo" => test"
      ...
    } 
  ```
  """
  def kv_cfetch!(pid, engine_name, secret, silent \\ false, version \\ 0) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    kv_fetch!(pid, path, silent, version)
  end

  @doc """
  Fetches all of a  given secret's key and values from a KV engine

  This function returns the full reponse of the remote vault server, enabling the silent option will only return a map with the key and value
  of the secret. The version option will allow you to fetch specific version of the target secret.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_fetch!(:production, "secret/data/ptolemy")
  %{ 
      "Foo" => test"
      ...
    } 
  ```
  """
  def kv_fetch!(pid, secret, silent \\ false, version \\ 0) when is_bitstring(secret) do
    client = create_client(pid)
    opts = [version: version]

    resp = Engine.read_secret!(client, secret, opts)
    case resp do
      %{} ->     
        case silent do
          true -> 
            {:ok ,resp
            |> Map.get("data")
            |> Map.get("data")
            }
          false ->
            {:ok, resp}
        end
      _ -> {:error, "Fetch from kv engine failed"}
    end
  end

  @doc """
  Updates an already existing secret via the `:kv_engine` configuration.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_cupdate!(:production, :engine1, :ptolemy, %{test: "asda"}, 1)
  200
  ```
  """
  def kv_cupdate!(pid, engine_name, secret, payload, cas \\ nil) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    kv_create!(pid, path, payload, cas)
  end

  @doc """
  Updates an already existing secret.

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_update!(:production, "secret/data/ptolemy", %{test: "asda"}, 1)
  200
  ```
  """
  def kv_update!(pid, secret, payload, cas \\ nil) when is_bitstring(secret) do
    kv_create!(pid, secret, payload, cas)
  end


  @doc """
  Creates a secret according to the path specified in the ":kv_engine" specification
  
  ## Example
  ```
  iex(2)> Ptolemy.kv_ccreate!(:production, :engine1, :ptolemy, %{test: "asda"}, 1)
  ```
  """
  def kv_ccreate!(pid, engine_name, secret, payload, cas \\ nil) do
    path = get_kv_path!(pid, engine_name, secret, "data")
    kv_create!(pid, path, payload, cas)
  end

  @doc """
  Creates a new secret via a KV engine

  ## Example
  ```elixir
  iex(2)> Ptolemy.kv_create!(:production, "secret/data/new", %{test: "test"}, 1)
  200
  """
  def kv_create!(pid, secret, payload, cas \\ nil) when is_bitstring(secret) do
    client = create_client(pid)
    case Engine.create_secret!(client, secret, payload, cas) do
      status when status in 200..299 -> :ok
      _ -> :error
    end
  end

  @doc """
  Deletes a secific version of a secret via the `:kv_engine` configuration.

  ```elixir
  iex(2)> Ptolemy.kv_cdelete!(:production, :engine1, :ptolemy, [1,2])
  204
  ```
  """
  def kv_cdelete!(pid, engine_name, secret, vers, destroy \\ false) do
    case destroy do
      true -> 
        path = get_kv_path!(pid, engine_name, secret, "destroy")
        kv_delete!(pid, path, vers)
      false -> 
        path = get_kv_path!(pid, engine_name, secret, "delete")
        kv_destroy!(pid, path, vers)
    end
  end

  @doc """
  Deletes a secific version of a secret.

  ```elixir
  iex(2)> Ptolemy.kv_delete!(:production, "secret/delete/ptolemy", [1,2])
  204
  ```
  """
  def kv_delete!(pid, secret, vers) do
    client = create_client(pid)
    case Engine.delete!(client, secret, vers) do
      status when status in 200..299 -> :ok
      _ -> :error
    end
  end

  @doc """
  Destroys a secific version of a secret via the `:kv_engine` configuration.

  ```elixir
  iex(2)> Ptolemy.kv_cdestroy!(:production, :engine1, :ptolemy, [1,2])
  204
  ```
  """
  def kv_cdestroy!(pid, engine_name, secret, vers) do
    path = get_kv_path!(pid, engine_name, secret, "destroy")
    kv_destroy!(pid, path, vers)
  end

  @doc """
  Destroys a specific version of secret.

  ```elixir
  iex(2)> Ptolemy.kv_destroy!(:production, "secret/destroy/ptolemy", [1,2])
  204
  ```
  """
  def kv_destroy!(pid, secret, vers) do
    client = create_client(pid)
    case Engine.destroy!(client, secret, vers) do
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
  defp get_kv_path!(pid, engine_name, secret, operation) when is_atom(secret) do
    with {:ok, kv_conf} <- Server.get_data(pid, engine_name),
      %{engine_path: path, secrets: secrets} <- kv_conf
    do
      {:ok, secret_path} = Map.fetch(secrets, secret)
      make_kv_path!(path, secret_path, operation)
    else
      {:error, "Not found!"} -> throw "#{pid} does not have a kv_engine config"
      :error -> throw "Could not find engine_name in specified config"
    end
  end

  defp get_kv_path!(pid, engine_name, secret, operation) when is_bitstring(secret) do
    with {:ok, kv_conf} <- Server.get_data(pid, engine_name),
      %{engine_path: path, secrets: secrets} <- kv_conf
    do
      make_kv_path!(path, secret, operation)
    else
      {:error, "Not found!"} -> throw "#{pid} does not have a kv_engine config"
      :error -> throw "Could not find engine_name in specified config"
    end
  end

  defp make_kv_path!(engine_path, secret_path, operation) do
    "/#{engine_path}#{operation}#{secret_path}"
  end

end