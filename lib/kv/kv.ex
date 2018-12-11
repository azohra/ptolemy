defmodule Ptolemy.KV do
    @moduledoc """
    `Ptomely.KV` provides interaction with a Vault server's Key Value secret egnine.
    """
  
    use Tesla
    require Logger
    alias Iris.Clients.Google.Auth, as: Gauth
  
    @doc """
    Creates a client for interaction with a local dev vault server.
    """
    def client(:dev, token) do
      url =
      Application.get_env(:iris, Iris.VaultStore)
      |> Keyword.get(:vault_url, "")
  
      Tesla.client([
        {Tesla.Middleware.BaseUrl, "#{url}/v1"},
        {Tesla.Middleware.Headers,
         [
          {"X-Vault-Token", token}
         ]},
        {Tesla.Middleware.JSON, []}
      ])
    end
  
    @doc """
    Generate a tesla client to get through IAP... This is to get the prod client
    """
    def client(:prod) do
      url =
        Application.get_env(:iris, Iris.VaultStore)
        |> Keyword.get(:vault_url, "")
  
      iap = Gauth.gen_iap_token()
      vault_tok =
        Gauth.gen_api_token()
        |> gen_auth_tok!()
  
      Tesla.client([
        {Tesla.Middleware.BaseUrl, "#{url}/v1"},
        {Tesla.Middleware.FollowRedirects, [{:max_redirects, 3}]}, #IAP has 3 redirects, Origin --> Google --> Origin
        {Tesla.Middleware.Headers,
         [
          iap, #Authorization Bearer
          vault_tok #X-VAULT-TOKEN
         ]},
        {Tesla.Middleware.JSON, []}
      ],
      {Tesla.Adapter.Hackney,
        [ssl_options:
          [{:versions,
            [:"tlsv1.2"] #Why the fuck does this work??? Does hackney not use 1.2 from the start?
            }]
        ]})
    end
  
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
    Unpacks a tupple
    """
    #Tuple stripping
    defp unpack({:ok, val}), do: val
    #For Map.fetch
    defp unpack({:error, msg}), do: throw {:error, msg}
    defp unpack(:error), do: throw {:error, msg = "Key does not exist in the server!"}
  
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
    Gets the status of the current vault server.
    """
    def get_server_status(client) do
      {:ok, resp} = get(client, "/sys/health")
  
      {:ok, resp.status}
    end
  
    @doc """
    Authenticated to a vault server via the approle auth engine. Returns a X-Vault-Token tuple
    """
    def gen_auth_tok!(access_token) do
      auth_jwt = gen_signed_jwt!(access_token)
      role = Application.get_env(:iris, Iris.VaultStore) |> Keyword.get(:role)
  
      payload = %{
        role: role,
        jwt: auth_jwt
      }
  
      url =
      Application.get_env(:iris, Iris.VaultStore)
      |> Keyword.get(:vault_url, "")
  
      client =
        Tesla.client([
          {Tesla.Middleware.BaseUrl, "#{url}/v1"},
          {Tesla.Middleware.Headers,
          [
            access_token
          ]},
          {Tesla.Middleware.JSON, []}
        ])
        
        with {:ok, resp} <- post(client, "/auth/gcp/login", payload) do
          case {resp.status, resp.body} do
            {status, body} when status in 200..299 ->
              tok =
                body
                |> Map.fetch!("auth")
                |> Map.fetch!("client_token")           
              {"X-Vault-Token", tok}
  
            {status, body} ->
              throw {:error, "Auth denied #{body}"}
            end
        end
    end
  
    @doc """
    Request google to sign a JWT claim. This token will be used to request a X-Vault-Token.
    """
    def gen_signed_jwt!(access_token) do
      svc = Gauth.get_svc()
      sub = svc |> Map.fetch!("client_email")
      project = svc |> Map.fetch!("project_id")
      role = Application.get_env(:iris, Iris.VaultStore) |> Keyword.get(:role)
  
      #Vault claim
      claim = %{
        sub: sub,
        aud: role
      }
      |> Poison.encode!
  
      #This is the json to be sent to google
      payload = %{
        payload: claim
      }
  
      client =
        Tesla.client([
          {Tesla.Middleware.BaseUrl, "https://iam.googleapis.com"},
          {Tesla.Middleware.Headers, [
            access_token,
            {"Content-Type", "application/json; charset=utf-8"}
          ]},
          {Tesla.Middleware.JSON, []}
        ])
  
        with {:ok, resp} <- post(client, "/v1/projects/#{project}/serviceAccounts/#{sub}:signJwt", payload) do
          case {resp.status, resp.body} do
            {status, body} when status in 200..299 ->
              body
              |> Map.fetch!("signedJwt")
  
            {status, body} ->
              throw {:error, "Api denied the JWT #{body}"}
            end
        end
    end
  end
  