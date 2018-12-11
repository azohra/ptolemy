defmodule Ptolemy.KV do
  @moduledoc """
  `Ptomely.KV` provides interaction with a Vault server's Key Value secret egnine.
  """

  use Tesla
  require Logger
  alias Iris.Clients.Google.Auth, as: Gauth
  
  @doc """
  Reads a secret from a remote vault server using Vault's KV engine but throws errors should it encounter one.
  Params: 
    * Client - Tesla client
    * Path - The path to the secret including the name of the vault secret. 
    * key - Key is the key you wish to find within the vault secret. 
  """
  def read_secret!(client, path, key) do
    with {:ok, resp} <- get(client, "#{path}") do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          try do
            body
            |> Map.get("data")
            |> Map.fetch("data")
            |> unpack()
            |> Map.fetch(key)
            |> unpack()
          catch
            {:error, msg} ->
              throw {:error, msg}
          end
        {status, e} ->
          msg = "Could not fetch secret: #{key} in remote vault server. Error code: #{status}"
          throw {:error, msg}
      end
    end
  end

  @doc """
  Creates a new vault secret using vault's KV engine, at location keyd path and with secret data named payload. 
  Payload is a map representing N keys with their corresponding values. All data within the 
  payload should be related to the secret.
  """
  def create_secret(client, path, name, payload) do
    data = %{
      data: payload
    }

    with {:ok, resp} <- post(client, "#{path}/#{name}", data) do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          {:ok, status}

        {status, e} ->
          Logger.warn("Could not create secret: #{name} in remote vault server. Error code: #{status}")
          {:error, e}
      end
    end
  end

  @doc """
  Overides a given secret's keys and values with a new payload using vault's KV engine.
  """
  def overide_secret(client, path, name, payload) do
    create_secret(client,  path, name, payload)
  end
    
  @doc """
  Unpacks a tupple
  """
  #Tuple stripping
  defp unpack({:ok, val}), do: val
  #For Map.fetch
  defp unpack({:error, msg}), do: throw {:error, msg}
  defp unpack(:error), do: throw {:error, msg = "Key does not exist in the server!"}
  end
  