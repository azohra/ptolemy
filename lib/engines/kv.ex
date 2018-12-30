defmodule Ptolemy.Engines.KV do
  @moduledoc """
  `Ptomely.KV` provides interaction with a Vault server's Key Value V2 secret egnine.
  """

  use Tesla
  require Logger

  @doc """
  Reads a secret from a remote vault server using Vault's KV engine but throws errors should it encounter one.
  Params: 
    * Client - Tesla client
    * Path - The path to the secret including the name of the vault secret. 
    * key - Key is the key you wish to find within the vault secret. 
  """
  def read_secret!(client, path, opts \\ []) do
    with {:ok, resp} <- get(client, "#{path}", query: opts) do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          body
        {status, e} ->
          msg = "Could not fetch secret: in remote vault server. Error code: #{status}"
          throw {:error, msg}
      end
    end
  end

  @doc """
  Creates a new vault secret using vault's KV engine, at location keyd path and with secret data named payload. 
  Payload is a map representing N keys with their corresponding values. All data within the 
  payload should be related to the secret.
  """
  def create_secret!(client, path, name, data, cas \\ nil) do
    if is_nil(cas) do
      payload = %{data: data}
    else
      payload = %{
        options: %{cas: cas},
        data: data
      }
    end

    with {:ok, resp} <- post(client, "#{path}", payload) do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          {:ok, status}

        {status, e} ->
          Logger.warn("Could not create secret: #{name} in remote vault server. Error code: #{status}")
          {:error, e}
      end
    end
  end
end
  