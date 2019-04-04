defmodule Ptolemy.Engines.PKI.Engine do
    @moduledoc """
    `Ptolemy.Engines.PKI.Engine` provides interaction with a Vault server's Key Value V2 secret egnine.
    """
  
    @doc """
    Creates a new role in Vault
    """
    @spec create_role(Tesla.Client.t(), String.t(), map()) :: {:ok | :error, String.t()}
    def create_role(client, path, payload \\ %{}) do
      with {:ok, resp} <- Tesla.post(client, "#{path}", payload) do
        case {resp.status, resp.body} do
          {status, _} when status in 200..299 ->
            {:ok, "PKI role created"}
  
          {status, _ } ->
            {:error, "Could not create PKI role in remote vault server. Error code: #{status}"}
        end
      end
    end
  
    @doc """
    Reads a secret from a remote vault server using Vault's KV engine.
    """
    @spec generate_secret(Tesla.Client.t(), String.t(), String.t(), map()) :: {:ok | :error, map()}
    def generate_secret(client, path, common_name, payload \\ %{}) do
        payload = Map.put(payload, "common_name", common_name)
        with {:ok, resp} <- Tesla.post(client, "#{path}", payload) do
          case {resp.status, resp.body} do
            {status, body} when status in 200..299 ->
              {:ok, body}
    
            {status, _ } ->
              {:error, "Could not generate PKI certificate from the role in remote vault server. Error code: #{status}"}
          end
        end
      end  

    @doc """
    Deletes a specific set of version(s) belonging to a specific secret
  
    If a 403 response is received, please check your ACL policy on vault
    """
    @spec revoke_cert(Tesla.Client.t(), String.t(), String.t(), map()) :: {:ok | :error, String.t()}
    def revoke_cert(client, path, serial_number, payload \\ %{}) do
        payload = Map.put(payload, "serial_number", serial_number)
        with {:ok, resp} <- Tesla.post(client, "#{path}", payload) do
          case {resp.status, resp.body} do
            {status, _} when status in 200..299 ->
              {:ok, "PKI certificate revoked"}
    
            {status, _ } ->
              {:error, "Could not revoke PKI certificate from the remote vault server. Error code: #{status}"}
          end
        end
      end  
  
    @doc """
    Revoke a role, but this does not invalidate the cert generated from the role
    """
    @spec revoke_role(Tesla.Client.t(), String.t()) :: {:ok | :error, String.t()}
    def revoke_role(client, path) do
        with {:ok, resp} <- Tesla.delete(client, "#{path}") do
            case {resp.status, resp.body} do
              {status, _} when status in 200..299 ->
                {:ok, "PKI role revoked"}
      
              {status, _ } ->
                {:error, "Could not revoke PKI role from the remote vault server. Error code: #{status}"}
            end
          end
    end
  end
    