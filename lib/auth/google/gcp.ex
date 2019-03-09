defmodule Ptolemy.Auth.GCP do
  @moduledoc """
  `Ptolemy.Auth.GCP` provides implementation vault authentication process for the GCP auth method.
  """
  alias Ptolemy.Auth.Google, as: Gauth
  @behaviour Ptolemy.Auth

  def authenticate(url, %{gcp_svc_acc: svc, vault_role: role, exp: exp}, opt) do
    jwt = %{
      sub: svc["client_email"],
      aud:  "vault/#{role}",
      exp: exp + :os.system_time(:seconds)
    }
    |> Jason.encode! 
    |> Gauth.req_signing(svc, exp)

    payload = %{
      role:  "#{role}",
      jwt: "#{jwt}"
    } 

    Ptolemy.Auth.vault_auth_client(url, opt)
    |> Ptolemy.Auth.login("/auth/gcp/login", payload)
  end

end