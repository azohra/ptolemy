defmodule Ptolemy.Engines.GCP do
    @moduledoc """
    `Ptolemy.Engines.GCP` provides interaction with a Vault server's GCP secret egnine to get access tokens and service account keys.
    """

    require Logger

    @doc """
    Generate a service account key, this is equiv to read service account key. 
    For create operation, please use `create_roleset`.
    The roleset variable should be an entire path  /gcp/roleset/my-key-roleset
    """
    def generate_service_account_key(client, roleset, key_alg \\ "KEY_ALG_RSA_2048", key_type \\ "TYPE_GOOGLE_CREDENTIALS_FILE" ) do
        payload = %{key_algorithm: key_alg, key_type: key_type}

        with {:ok, resp} <- Tesla.post(client, "#{roleset}", payload) do
            case {resp.status, resp.body} do
                {status, _} when status in 200..299 ->
                    status
                {status, msg} -> 
                    throw "Could not generate service account key.\nError code: #{status}"
            end
        end
    end

    @doc """
    Generate an access token, this is equiv to read oath2 token opertaions.
    For create operation, please use `create_roleset`.
    The roleset variable should be an entire path  /gcp/roleset/my-token-roleset
    """
    def generate_service_token(client, roleset) do
        with {:ok, resp} <- Tesla.get(client, "#{roleset}") do
            case {resp.status, resp.body} do
                {status, _} when status in 200..299 ->
                    status
                {status, msg} -> 
                    throw "Could not generate access token.\nError code: #{status}"
            end
        end
    end


    @doc """
    Create/Update Roleset
    Accepted secret_type values: "access_token", "service_account_key"
    """
    def create_roleset(client, name, project, bindings, secret_type \\ "access_token", token_scopes \\ []) do
       payload = case secret_type do
           "access_token" -> 
                %{secret_type: secret_type,
                 project: project,
                 token_scopes: token_scopes,
                 bindings: bindings
                }
           "service_account_key" ->
                %{secret_type: secret_type,
                project: project,
                bindings: bindings
                }
       end

       with {:ok, resp} <- Tesla.post(client, "#{name}", payload) do
           case {resp.status, resp.body} do
               {status, _} when status in 200..299 ->
                   status
               {status, msg} -> 
                   throw "Could not create role set.\nError code: #{status}"
           end
       end
    end

    @doc """
    Delete Roleset, this only support service account keys
    """
    def delete_roleset(client, lease_id) do
        payload = %{lease_id: lease_id}
 
        with {:ok, resp} <- Tesla.put(client, "/sys/leases/revoke", payload) do
            case {resp.status, resp.body} do
                {status, _} when status in 200..299 ->
                    status
                {status, msg} -> 
                    throw "Could not delete role set.\nError code: #{status}"
            end
        end
     end

end