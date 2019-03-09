defmodule Ptolemy.Auth.Approle do
  @moduledoc """
    `Ptolemy.Auth.Approle` implements vault authentication process for an approle auth method.
  """
  @behaviour Ptolemy.Auth

  def authenticate(url, %{secret_id: _sid, role_id: _rid} = creds, opt) do
    Ptolemy.Auth.vault_auth_client(url, opt) 
    |> Ptolemy.Auth.login("/auth/approle/login", creds)
  end
end