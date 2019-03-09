defmodule Ptolemy.Auth do
  @moduledoc """
  `Ptolemy.Auth` provides authentication implementations to a remote vault server.

  ## Usage
  All token request should call the `Ptolemy.Auth.authenticate/4` function and *not* the `c:authenticate/3` callback found
  in each modules implementing this behaviour!

  Here are a few examples of the usage:
  ```elixir
  #Approle, no IAP
  Ptolemy.Auth.authenticate(:Approle, "https://test-vault.com", %{secret_id: "test", role_id; "test"}, [])
  
  #Approle with IAP
  Ptolemy.Auth.authenticate(:Approle, "https://test-vault.com", %{secret_id: "test", role_id; "test"}, [iap_svc_acc:  @gcp_svc1_with_vault_perm, client_id: @fake_id, exp: 2000])
  
  #Approle with IAP and `bearer` token being re-used
  Ptolemy.Auth.authenticate(:Approle, "https://test-vault.com", %{secret_id: "test", role_id: "test"}, {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"})
  
  #GCP with no IAP
  Ptolemy.Auth.authenticate(:GCP, "https://test-vault.com", my_svc, [])
  
  #GCP with IAP, 2 Google service accounts, one for vault one for IAP
  Ptolemy.Auth.authenticate(:GCP, @vurl, %{gcp_svc_acc: @gcp_svc1_with_vault_perm, vault_role: "test", exp: 3000}, [iap_svc_acc:  my_svc, client_id: @fake_id, exp: 2000])
  
  #GCP with IAP, re-using the same GCP service account being used to authenticate to vault inorder to auth into IAP
  Ptolemy.Auth.authenticate(:GCP, @vurl, %{gcp_svc_acc: @gcp_svc1_with_vault_perm, vault_role: "test", exp: 3000}, [iap_svc_acc:  :reuse, client_id: @fake_id, exp: 2000])
 
  #GCP with IAP and `bearer` token being re-used
  Ptolemy.Auth.authenticate(:GCP, @vurl, %{gcp_svc_acc: @gcp_svc1_with_vault_perm, vault_role: "test", exp: 3000}, {"Authorization", "Bearer 98a4c7ab98a4c7ab98a4c7ab"})
  ```
  """

  @typedoc """
  Vault authentication data.
  """
  @type vault_auth_data ::
    %{
      token: {String.t(), String.t()},
      renewable: boolean(), 
      lease_duration: pos_integer()
    }

  @typedoc """
  Google Identity Aware Proxy authentication data.
  """
  @type iap_auth_data ::
    %{
      token: {String.t(), String.t()}
    }

  @typedoc """
  Credential data needed to authenticated to a remote vault server.

  Each specific auth method's credential data have a different schema.
  """
  @type cred_data :: 
    %{ 
      gcp_svc_acc: map(), 
      vault_role: String.t(), 
      exp: pos_integer()
    } 
    | %{
        secret_id:  String.t(), 
        role_id:  String.t()
      }

  @typedoc """
  Authentication options, used to specify IAP credentials and other future authentication options.

  If under the `:iap_svc_acc` key `:reuse` is specified and the auth method was set to `:GCP`, `Ptolemy.Auth` 
  will attempt to re-use the GCP service account specified under the supplied `cred_data` type. 

  `:client_id` is the OAuth2 client id, this can be found in Security -> Identity-Aware-Proxy -> Select the IAP resource -> Edit OAuth client.
  
  `:exp` is the validity period for the token in seconds, google's API specifies that a token can only be valid for up to 3600 seconds.

  Specifying a tuple of type {"Authorization", "Bearer ....."} will notify `Ptolemy.Auth.authenticate/4` to reuse the token to prevent
  exessive auhtnetication calls to IAP.
  """
  @type iap_auth_opts :: 
    [] 
    | [iap_svc_acc: map(), client_id: String.t(), exp: pos_integer()]
    | [iap_svc_acc: :reuse, client_id: String.t(), exp: pos_integer()]
    | {String.t(), String.t()}

  @typedoc """
  Atoms representing the authentication methods that is currently supported on ptolemy.

  Currently supported methods are:
    - GCP -> `:GCP`
    - Approle -> `:Approle`
  """
  @type auth_method :: :GCP | :Approle

  @typedoc """
  List representing an IAP token.

  The token type returned from a sucessfull IAP call will always be of type `Authorization Bearer`.
  """
  @type iap_tok :: [] | [{String.t(), String.t()}]

  @doc """
  Authentication method specific callback to be implemented by different modules.

  Each modules representing a specific authentication method should implement this callback in its own module.
  """
  @callback authenticate(endpoint :: String.t(), cred_data, iap_tok) :: vault_auth_data | {:error, String.t()}

  @doc """
  Authenticates against a remote vault server with specified auth strategy and options.

  Currently the only supported options deals with IAP.

  Note Specifying an empty list or a tuple to this function under `iap_auth_opts` will *NOT* return an IAP token and IAP credentials metadata.
  """
  @spec authenticate(auth_method, String.t(), cred_data, iap_auth_opts) :: 
    vault_auth_data 
    | %{vault: vault_auth_data, iap: iap_auth_data} 
    | {:error, String.t()}
  def authenticate(method, url, credentials, opts)
  
  #IAP not defined or not enabled
  def authenticate(method, url, credentials, [] = opts) do
    auth(method, url, credentials, opts)
  end

  #Re-use IAP Bearer tokens
  def authenticate(method, url, credentials, {"Authorization", bearer} = opts) do
    auth(method, url, credentials, [opts])
  end

  #IAP is enabled and has a seperate service account.
  def authenticate(method, url, credentials, [iap_svc_acc: svc, client_id: cid, exp: exp]) when is_map(svc) do
    iap_tok = Ptolemy.Auth.Google.authenticate(:iap, svc, cid, exp)
    vault_tok = auth(method, url, credentials, [iap_tok])

    %{vault: vault_tok, iap: %{token: iap_tok}}
  end

  #IAP is enabled with instruction to re-use `credentials` as the IAP service account
  def authenticate(method, url, credentials, [iap_svc_acc: :reuse, client_id: cid, exp: exp]) do
    iap_tok = Ptolemy.Auth.Google.authenticate(:iap, credentials[:gcp_svc_acc], cid, exp)
    vault_tok = auth(method, url, credentials, [iap_tok])

    %{vault: vault_tok, iap: %{token: iap_tok}}
  end

  defp auth(method, url, credentials, opts) do
    auth_type = Module.concat(Ptolemy.Auth, method)
    auth_type.authenticate(url, credentials, opts)
  end

  @doc """
  Sends a payload to a remote vault server's authentication endpoint.
  """
  @spec login(%Tesla.Client{}, String.t(), map()) :: vault_auth_data | {:error, String.t()}
  def login(client, auth_endp, payload) do
    with {:ok, resp} <- Tesla.post(client, auth_endp, payload) do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          parse_vault_resp(body)
          
        {status, body} ->
          message = Map.fetch!(body, "errors")
          {:error, "Authentication failed, Status: #{status} with error: #{message}"}
      end
    else  
      err -> err
    end
  end


  @doc """
  Creates a `%Tesla.Client{}` pointing to a remote vault server.
  """
  @spec vault_auth_client(String.t(), iap_auth_opts) :: %Tesla.Client{}
  def vault_auth_client(url, iap_tok) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "#{url}/v1"},
      {Tesla.Middleware.Headers, iap_tok},
      {Tesla.Middleware.JSON, []}
    ])
  end

  #parses auth body to return relevant information
  defp parse_vault_resp(body) do
    %{
      "auth" => %{
        "client_token" => client_token,
        "renewable" => renewable,
        "lease_duration" => lease_duration
      }
    } = body

    %{token: {"X-Vault-Token", client_token}, renewable: renewable, lease_duration: lease_duration}
  end
end