defmodule Ptolemy.Auth do
  @moduledoc """
  `Ptolemy.Auth` provides authentication implementations to a remote vault server.
  
  As of the current version of this documentation the only supported auth methods that ptolemy supports is GCP and Approle auth methods.
  """

  alias Ptolemy.Google.Auth, as: Gauth

  @sealed_msg "The vault server is sealed, something terrible has happened!"

  @default_exp 900 #Default expiration for tokens

  @doc """
  Authenticates a credential to a remote vault server. 
  
  A list containing needed authorization tokens. The list returned is compatible with tesla's middleware adapters.
  
  Currently available options are:
    - `iap_on`
      - This option can be set to either true or false. Setting it to true will allow your request to pass through
      Google's Identity Aware Proxy.
    - `exp`
      - The expiry that the access tokens will be valid for. This is depended on the remote vault server's configuration
      and whether GCP auth is being performed. 
      - Keep in mind Google does not allow you to create tokens that have an exp value larger than 3600 seconds (1 hour)
      - Vault on the other hand is configurable but generally speaking has a validity period of atleast 900 seconds (15 min).
  """
  def authenticate!(credential, auth_mode, url, opt \\ []) do
    iap = opt |> Keyword.get(:iap_on, false)
    exp = opt |> Keyword.get(:exp, @default_exp)
    case {auth_mode, iap} do
      {"GCP", _ } ->  
        role = opt |> Keyword.get(:role, "default")
        google_svc = credential |> Map.fetch!(:svc_acc) |> Gauth.parse_svc()
        iap_tok = 
          if iap do
            client_id = credential |> Map.fetch!(:target_audience)
            [Gauth.gen_iap_token(google_svc, client_id, exp)]
          else
            []
          end
        toks =
          google_svc
          |> google_auth!(url, exp, iap_tok, [role: role ])
        [toks | iap_tok]

      {"approle", _ } -> 
        iap_tok = 
          if iap do
            google_svc = credential |> Map.fetch!(:svc_acc) |> Gauth.parse_svc()
            client_id = credential |> Map.fetch!(:target_audience)
            [Gauth.gen_iap_token(google_svc, client_id, exp)]
          else
            []
          end
        toks =
          credential
          |> approle_auth!(url, iap_tok)
        [toks | iap_tok]
  
      { _, _ } -> throw {:error, "Authentication mode not supported"}
    end
  end

  # Authenticates using the Approle authentication method.
  defp approle_auth!(creds, url, iap_tok), do: auth!(creds, url, "/auth/approle/login", iap_tok)

  # Authenticates using the gcp authentication method.
  defp google_auth!(creds, url, exp, iap_tok, opt) do 
    str = opt |> Keyword.get(:role, "default") 

    vault_claim = %{
      sub: Map.fetch!(creds, "client_email"),
      aud:  "vault/#{str}",
      exp: exp + Joken.current_time()
    }
    |> Jason.encode!

    signed_jwt =
      creds
      |> Gauth.gen_signed_jwt!(vault_claim, exp)

    payload = %{
      role:  "#{str}",
      jwt: "#{signed_jwt}"
    }

    auth!(payload, url, "/auth/gcp/login", iap_tok)
  end

  # Check the status of the remote vault.
  defp check_health(client) do
    with {:ok, resp} <- Tesla.get(client, "/sys/health"),
      {:ok, sealed} <- Map.fetch(resp.body, "sealed") 
    do
      case sealed do 
        false -> :ok
        true -> :sealed
      end
    end
  end


  # Authenticates to a remote vault server.
  defp auth!(payload, url, auth_endp, iap_tok) do
    client =
      Tesla.client([
        {Tesla.Middleware.BaseUrl, "#{url}/v1"},
        {Tesla.Middleware.Headers, iap_tok},
        {Tesla.Middleware.JSON, []}
      ])

    with {:ok, resp} <- Tesla.post(client, auth_endp, payload),
        :ok <- check_health(client)
    do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          tok =
            body
            |> Map.fetch!("auth")
            |> Map.fetch!("client_token")           
          {"X-Vault-Token", tok}

        {status, body} ->
          message = Map.fetch!(body, "errors")
          throw {:error, "Authentication failed, Status:#{status} with error: #{message}"}
      end
    else
      :sealed -> raise @sealed_msg
    end
  end
end