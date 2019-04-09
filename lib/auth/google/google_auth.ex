defmodule Ptolemy.Auth.Google do
  @moduledoc """
  `Ptolemy.Auth.Google` provides authentication functionality for Google's public APIs.
  """
  import Joken
  require Logger

  @google_auth_url "https://www.googleapis.com"
  @google_iam_auth "https://iam.googleapis.com"
  @google_gcp_scope "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/iam"
  @google_aud "https://www.googleapis.com/oauth2/v4/token"
  @google_grant_type "urn:ietf:params:oauth:grant-type:jwt-bearer"
  @google_jwt_header %{
    "alg" => "RS256",
    "typ" => "JWT"
  }

  @doc """
  Generates a google API access token used to authenticate your request to google's api.
  """
  @spec authenticate(:api, map(), String.t(), pos_integer()) ::
          {String.t(), String.t()} | {:error, String.t()}
  def authenticate(:api, creds, exp) do
    base = %{scope: @google_gcp_scope}
    gen_tok(creds, "access_token", base, exp)
  end

  @doc """
  Generates an IAP access token used to authenticate through IAP secured resource.
  """
  @spec authenticate(:iap, map(), String.t(), pos_integer()) ::
          {String.t(), String.t()} | {:error, String.t()}
  def authenticate(:iap, creds, client_id, exp) do
    base = %{target_audience: client_id}
    gen_tok(creds, "id_token", base, exp)
  end

  @doc """
  Request Google to sign a given JWT claim.
  """
  @spec req_signing(String.t(), map(), pos_integer()) :: String.t() | {:error, String.t()}
  def req_signing(jwt_claim, svc, exp) do
    sub = svc["client_email"]
    project = svc["project_id"]

    api_token = authenticate(:api, svc, exp)

    payload = %{
      payload: jwt_claim
    }

    client = iam_auth_client(api_token)

    with {:ok, resp} <-
           Tesla.post(client, "/v1/projects/#{project}/serviceAccounts/#{sub}:signJwt", payload) do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          body
          |> Map.fetch!("signedJwt")

        {_status, body} ->
          message = Map.fetch!(body, "error") |> Map.fetch!("message")
          {:error, "Signing failed, #{message}"}
      end
    end
  end

  # Creates google specific JWT
  defp create_jwt(svc, base_claim, time) do
    iss = svc["client_email"]
    signer = svc["private_key"] |> JOSE.JWK.from_pem() |> rs256()

    token()
    |> with_header_args(@google_jwt_header)
    # need to override the override (T.T) +/- cpu offset
    |> with_claim_generator("exp", fn -> :os.system_time(:seconds) + time end)
    |> with_claims(base_claim)
    |> with_aud(@google_aud)
    |> with_iss(iss)
    |> with_signer(signer)
    |> sign()
    |> get_compact()
  end

  # Helper func to generate a signed jwt used to submit to google's api.
  defp gen_tok(creds, key, base_claim, exp) do
    resp =
      creds
      |> create_jwt(base_claim, exp)
      |> req_tokens()

    case resp do
      {:error, msg} -> {:error, msg}
      _ -> {"Authorization", "Bearer #{Map.fetch!(resp, key)}"}
    end
  end

  # Sends a newly created JWT to the google auth endpoint, depending on the claim type we will either get:
  # - Access token -> used authenticate through the google api
  # - id_token -> used to authenticate through IAP
  defp req_tokens(jwt) do
    client = auth_client()

    params = %{
      assertion: jwt,
      grant_type: @google_grant_type
    }

    with {:ok, resp} <- Tesla.post(client, "/oauth2/v4/token", params) do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          body

        {_status, body} ->
          message = body |> Map.fetch!("error_description")
          {:error, "Token request failed: #{message}"}
      end
    end
  end

  # Create client used to authenticate against the oauth2 api.
  defp auth_client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @google_auth_url},
      {Tesla.Middleware.Headers,
       [
         {"Content-Type", "application/json; charset=utf-8"}
       ]},
      {Tesla.Middleware.JSON, []}
    ])
  end

  # Create client used to authenticate through the iam api
  defp iam_auth_client(api_tok) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @google_iam_auth},
      {Tesla.Middleware.Headers,
       [
         api_tok,
         {"Content-Type", "application/json; charset=utf-8"}
       ]},
      {Tesla.Middleware.JSON, []}
    ])
  end
end
