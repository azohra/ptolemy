defmodule Ptolemy.Auth do
  @moduledoc """
  `Ptolemy.Auth` provides authentication implementation to a remote vault server.
  """
  use Tesla
  alias Ptolemy.Auth.GCP.Auth, as: Gauth

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
    iap = opt |> Keyword.get(:iap, false)
    exp = opt |> Keyword.get(:exp, @default_exp)
    iap_tok = if iap, do: [Gauth.gen_iap_token(exp)], else: []
    case {auth_mode, iap} do
      {"GCP", _ } ->  
        role = opt |> Keyword.get(:role, "default")
        toks =
          credential
          |> Gauth.parse_svc()
          |> google_auth!(url, exp, role, iap_tok)
        [toks | iap_tok]

      {"approle", _ } -> 
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
    creds = Gauth.parse_svc(creds)
    
    vault_claim = %{
      sub: Map.fetch!(creds, :client_email),
      aud: opt |> Keyword.get(:role, "default"),
      exp: opt |> Keyword.get(:exp)
    }
    |> Poison.encode!

    signed_jwt =
      creds
      |> Gauth.gen_signed_jwt!(vault_claim, exp)

    auth!(signed_jwt, url, "/auth/gcp/login", iap_tok)
  end

  @doc """
  Check the status of the remote vault 
  """
  def check_health(client) do
    with {:ok, resp} <- get(client, "/sys/health") do
      case resp.status do 
        200 -> :ok
        503 -> :sealed
        _ -> :error
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

    with :ok <- check_health(client),
      {:ok, resp} <- post(client, auth_endp, payload) 
    do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          tok =
            body
            |> Map.fetch!("auth")
            |> Map.fetch!("client_token")           
          {"X-Vault-Token", tok}

        {status, body} ->
          throw {:error, "Authentication failed, Status:#{status} with error: #{body}"}
      end
    else
      :sealed -> raise @sealed_msg
      _ -> throw {:error, @vault_health_err}
    end
  end
end