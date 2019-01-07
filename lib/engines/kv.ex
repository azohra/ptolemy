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
  def read_secret!(client, path, vers \\ []) do
    with {:ok, resp} <- get(client, "#{path}", query: vers) do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          body

        {status, _} ->
          throw "Could not fetch secret in remote vault server. Error code: #{status}"
      end
    end
  end

  @doc """
  Creates a new vault secret using vault's KV engine, at location keyd path and with secret data named payload. 
  Payload is a map representing N keys with their corresponding values. All data within the 
  payload should be related to the secret.
  """
  def create_secret!(client, path, data, cas \\ nil) do
    payload = if is_nil(cas), do: %{data: data}, else: %{options: %{cas: cas}, data: data}

    with {:ok, resp} <- post(client, "#{path}", payload) do
      case {resp.status, resp.body} do
        {status, _} when status in 200..299 ->
          status

        {status, e} ->
           throw "Could not create secret in remote vault server. Error code: #{status}"
      end
    end
  end

  @doc """
  Deletes latest version belonging to a specific secret
  """
  def delete_latest!(client, path) do
    with {:ok, resp} <- delete(client, "#{path}") do
      case {resp.status, resp.body} do
        {status, _} when status in 200..299 ->
          status

        {status, e} ->
           throw "Could not delete version(s) of secret in remote vault server. Error code: #{status}"
      end
    end
  end

  @doc """
  Deletes a specific set of version(s) belonging to a specific secret
  """
  def delete!(client, path, vers) do
    payload = %{version: vers}
  
    with {:ok, resp} <- delete(client, "#{path}", payload) do
      case {resp.status, resp.body} do
        {status, _} when status in 200..299 ->
          status

        {status, e} ->
           throw "Could not delete version(s) of secret in remote vault server. Error code: #{status}"
      end
    end
  end


  @doc """
  Destroys a specific set of version(s) belonging to a specific secret
  """
  def destroy!(client, path, vers) do
    payload = %{version: vers}
  
    with {:ok, resp} <- post(client, "#{path}", payload) do
      case {resp.status, resp.body} do
        {status, _} when status in 200..299 ->
          status

        {status, e} ->
           throw "Could not destroy version(s) of secret in remote vault server. Error code: #{status}"
      end
    end
  end
end
  