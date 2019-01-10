defmodule Ptolemy.Google.Auth.JWT do
  @moduledoc """
  `Ptolemy.Google.Auth.JWT` provides JWT functionality to `Ptolemy.Google.Auth`
  """
  import Joken
  require Logger

  alias JOSE.JWK, as: Jjwk

  @google_jwt_header %{
    "alg" => "RS256",
    "typ" => "JWT"
  }

  @google_aud "https://www.googleapis.com/oauth2/v4/token"

  @doc """
  Creates a valid JWT according to google specs.
  """
  def create_jwt(svc, base_claim, time) do
    iss = svc |> get_key("client_email")
    #Prep the svc acc's private key
    signer = svc |> get_key("private_key")|> Jjwk.from_pem()|> rs256()

    jwt =
      token()
      |> with_header_args(@google_jwt_header)
      |> with_claim_generator("exp", fn -> current_time() + time end ) #need to overide the overide (T.T) +/- cpu offset
      |> with_claims(base_claim)
      |> with_aud(@google_aud)
      |> with_iss(iss)
      |> with_signer(signer)
      |> sign()
      |> get_compact()
  end

  # Gets a specific key from a Google JSON Service account credential
  defp get_key(svc, key) do
    svc
    |> Map.fetch(key)
    |> unpack
  end

  # Unpack stuff
  defp unpack({:ok, msg}), do: msg
  defp unpack(:error), do: Logger.error("Error unpacking map, could not find key")

end
