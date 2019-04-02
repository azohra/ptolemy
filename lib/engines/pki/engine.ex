defmodule Ptolemy.Engines.PKI.Engine do
    @moduledoc """
    `Ptolemy.Engines.PKI.Engine` provides interaction with a Vault server's Key Value V2 secret egnine.
    """
  
    @doc """
    Creates a new role in Vault
    """
    def create_role!(client, path, payload \\ %{}) do
      with {:ok, resp} <- Tesla.post(client, "#{path}", payload) do
        case {resp.status, resp.body} do
          {status, _ } when status in 200..299 ->
            status
  
          {status, _ } ->
             throw "Could not create PKI role in remote vault server. Error code: #{status}"
        end
      end
    end
  
    @doc """
    Reads a secret from a remote vault server using Vault's KV engine.
    """
    def generate_secret!(client, path, common_name, payload \\ %{}) do
        payload = Map.put(payload, "common_name", common_name)
        with {:ok, resp} <- Tesla.post(client, "#{path}", payload) do
          case {resp.status, resp.body} do
            {status, body} when status in 200..299 ->
              body
    
            {status, _ } ->
              throw "Could not generate PKI certificate from the role in remote vault server. Error code: #{status}"
          end
        end
      end  

    @doc """
    Deletes a specific set of version(s) belonging to a specific secret
  
    If a 403 response is received, please check your ACL policy on vault
    """
    def revoke_cert!(client, path, serial_number, payload \\ %{}) do
        payload = Map.put(payload, "serial_number", serial_number)
        with {:ok, resp} <- Tesla.post(client, "#{path}", payload) do
          case {resp.status, resp.body} do
            {status, body} when status in 200..299 ->
              status
    
            {status, _ } ->
              throw "Could not revoke PKI certificate from the remote vault server. Error code: #{status}"
          end
        end
      end  
  
    @doc """
    Revoke a role, but this does not invalidate the cert generated from the role
    """
    def revoke_role!(client, path) do
        with {:ok, resp} <- Tesla.delete(client, "#{path}") do
            case {resp.status, resp.body} do
              {status, body} when status in 200..299 ->
                status
      
              {status, _ } ->
                throw "Could not delete PKI role from the role in remote vault server. Error code: #{status}"
            end
          end
    end
  end
    