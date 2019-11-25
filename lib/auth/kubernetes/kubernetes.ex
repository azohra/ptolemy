defmodule Ptolemy.Auth.Kubernetes do
  @moduledoc """
  `Ptolemy.Auth.Kube` provides implementation vault authentication process for the Kubernetes auth method.
  """
  @behaviour Ptolemy.Auth

  def authenticate(url, %{kube_client_token: client_key, vault_role: role, cluster_name: cname}, headers, http_opts \\ []) do
    payload = %{
      role: "#{role}",
      jwt: "#{client_key}"
    }

    Ptolemy.Auth.vault_auth_client(url, headers, http_opts)
    |> Ptolemy.Auth.login("/auth/#{cname}/login", payload)
  end
end
