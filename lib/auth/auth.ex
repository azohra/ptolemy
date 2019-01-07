defmodule Ptolemy.Auth do
  @moduledoc """
  `Ptolemy.Auth` provides authentication implementation to a remote vault server. As of the current version of this
  documentation the only supported auth methods that ptolemy supports is GCP and Approle auth methods.
  """
  use Tesla
  alias Ptolemy.Google.Auth, as: Gauth

  @sealed_msg "The vault server is sealed, something terrible has happened!"
  @vault_health_err "Seems like the remote vault server is having issues right now contact the admin!"

  @default_exp 900 #Default expiration for tokens

  @doc """
  Authenticates a credential to a remote vault server. A list containing needed authorization tokens. The list
  returned is compatible with tesla's middleware adapters.
  
  Currently available options are:
    - Active Identity Aware Proxy; `iap:` can be either `true` or `false`
  """
  def authenticate!(credential, auth_mode, url, opt \\ []) do
    iap = opt |> Keyword.get(:iap_on, false)
    exp = opt |> Keyword.get(:exp, @default_exp)
    case {auth_mode, iap} do
      {"GCP", _ } ->  
        role = opt |> Keyword.get(:role, "default")
        google_svc = credential |> Map.fetch!(:creds) |> Gauth.parse_svc()
        iap_tok = 
          if iap do
            client_id = credential |> Map.fetch!(:target_audience)
            [Gauth.gen_iap_token(google_svc, client_id, exp)]
          else
            []
          end
        toks =
          google_svc
          |> google_auth!(url, exp, role, iap_tok, [role: role ])
        [toks | iap_tok]

      {"approle", _ } -> 
        creds = Keyword.get(opt, :iap_creds, [])
        iap_tok = 
          if iap do
            google_svc = credential |> Map.fetch!(:creds) |> Gauth.parse_svc()
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

  @doc """
  Authenticates using the Approle authentication method.
  """
  def approle_auth!(creds, url, iap_tok, opt \\ []), do: auth!(creds, url, "/auth/approle/login", iap_tok)

  @doc """
  Authenticates using the gcp authentication method.
  """
  def google_auth!(creds, url, exp, role, iap_tok, opt \\ []) do 
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

  @doc """
  Check the status of the remote vault. 
  """
  def check_health(client) do
    with {:ok, resp} <- get(client, "/sys/health"),
      {:ok, sealed} <- Map.fetch(resp.body, "sealed") 
    do
      case sealed do 
        false -> :ok
        true -> :sealed
      end
    end
  end

  @doc """
  Authenticates to a remote vault server.
  """
  defp auth!(payload, url, auth_endp, iap_tok, opt \\ []) do
    client =
      Tesla.client([
        {Tesla.Middleware.BaseUrl, "#{url}/v1"},
        {Tesla.Middleware.Headers, iap_tok},
        {Tesla.Middleware.JSON, []}
      ])

    with {:ok, resp} <- post(client, auth_endp, payload),
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