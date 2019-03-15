defmodule Ptolemy.Engines.KV.Engine do
  @moduledoc """
  `Ptolemy.Engines.KV` provides interaction with a Vault server's Key Value V2 secret egnine.
  """

  require Logger

  @doc """
  Reads a secret from a remote vault server using Vault's KV engine.
  """
  def read_secret!(client, path, vers \\ []) do
    with {:ok, resp} <- Tesla.get(client, "#{path}", query: vers) do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          body

        {status, _ } ->
          throw "Could not fetch secret in remote vault server. Error code: #{status}"
      end
    end
  end

  @doc """
  Creates a new vault secret using vault's KV engine.
  """
  def create_secret!(client, path, data, cas \\ nil) do
    payload = if is_nil(cas), do: %{data: data}, else: %{options: %{cas: cas}, data: data}

    with {:ok, resp} <- Tesla.post(client, "#{path}", payload) do
      case {resp.status, resp.body} do
        {status, _ } when status in 200..299 ->
          status

        {status, _ } ->
           throw "Could not create secret in remote vault server. Error code: #{status}"
      end
    end
  end

  @doc """
  Deletes a specific set of version(s) belonging to a specific secret

  If a 403 response is received, please check your ACL policy on vault
  """
  def delete!(client, path, vers) do
    payload = %{versions: vers}

    with {:ok, resp} <- Tesla.post(client, "#{path}", payload) do
      case {resp.status, resp.body} do
        {status, _ } when status in 200..299 ->
          status

        {status, _ } ->
           throw "Could not delete version(s) of secret in remote vault server. Error code: #{status}"
      end
    end
  end


  @doc """
  Destroys a specific set of version(s) belonging to a specific secret.
  
  If a 403 response is received, please check your ACL policy on vault
  """
  def destroy!(client, path, vers) do
    payload = %{versions: vers}
  
    with {:ok, resp} <- Tesla.post(client, "#{path}", payload) do
      case {resp.status, resp.body} do
        {status, _ } when status in 200..299 ->
          status

        {status, _ } ->
           throw "Could not destroy version(s) of secret in remote vault server. Error code: #{status}"
      end
    end
  end
end
  