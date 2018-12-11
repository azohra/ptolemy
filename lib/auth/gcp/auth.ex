defmodule Ptolemy.Google.Auth do
  @moduledoc """
  Defines google api authentication
  """

  alias Ptolemy.Google.JWT, as: JWT
  use Tesla

  @google_auth_url "https://www.googleapis.com"
  @google_iam_auth "https://iam.googleapis.com"
  @google_gcp_scope "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/iam"
  @google_grant_type "urn:ietf:params:oauth:grant-type:jwt-bearer"

  @doc """
  Generates a google API access token used to authenticate your request to google's api.
  Returns a tuple following this format {"Authorization", "Bearer <TOKEN>"}, this can be inserted on tesla's
  middleware headers. The tokens are only valid for 59 minutes - as per .
  """
  def gen_api_token(exp) do
    base = %{scope: @google_gcp_scope}

    gen_tok("access_token", base, exp)
  end

  @doc """
  Generates an IAP access token used to authenticate through IAP secured resource.
  Returns a tuple following this format {"Authorization", "Bearer <TOKEN>"}, this can be inserted on tesla's
  middleware headers.
  """
  def gen_iap_token(exp) do
    client_id =
    Application.get_env(:iris, :google, :client_id)
    |> Keyword.get(:client_id, "")

    base = %{target_audience: client_id}

    gen_tok("id_token", base, exp)
  end

  @doc """
  Helper func to generate a signed jwt used to submit to google's api.
  """
  defp gen_tok(key, base_claim, exp) do
    token =
      parse_svc(key)
      |> JWT.create_jwt(base_claim, exp)
      |> send_jwt!()
      |> Map.fetch!(key)

    {"Authorization", "Bearer #{token}"}
  end

  def client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @google_auth_url},
      {Tesla.Middleware.Headers, [
        {"Content-Type", "application/json; charset=utf-8"}
      ]},
      {Tesla.Middleware.JSON, []}
    ])
  end

  @doc """
  Sends a claim to google's api which upon a succesful 
  """
  def gen_signed_jwt!(svc, claim, exp) do
    sub = svc |> Map.fetch!("client_email")
    project = svc |> Map.fetch!("project_id")
    api_token = gen_api_token(exp)

    #This is the json to be sent to google
    payload = %{
      payload: claim
    }

    client =
      Tesla.client([
        {Tesla.Middleware.BaseUrl, @google_iam_auth},
        {Tesla.Middleware.Headers, [
          api_token,
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

  @doc """
  Sends a newly created JWT to the google auth endpoint, depending on the claim type we will either get:
  - Access token -> used authenticate through the google api
  - id_token -> used to authenticate through IAP
  """
  defp send_jwt!(jwt) do
    goog = client()

    params = %{
      assertion: jwt,
      grant_type: @google_grant_type
  }

    with {:ok, resp} <- post(goog, "/oauth2/v4/token", params) do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          body

        {status, body} ->
          throw {:error, "Api denied the JWT #{body}"}
        end
    end
  end

  @doc """
  Gets a google svc account specified from the config
  """
  def parse_svc(creds) do
    svc =
      creds
      |> Base.url_decode64()
      |> unpack()
      |> serialize()
  end

  @doc """
  Unpacks and decode a string to a map
  """
  defp serialize(svc) do
    svc
    |> Poison.decode()
    |> unpack()
  end

  @doc """
  Tuple unpacking
  """
  defp unpack({:ok, msg}), do: msg
  defp unpack({:error, msg}), do: throw {:error, msg}
  defp unpack(:error), do: throw {:error, msg = "Unable to decode json"}

end
