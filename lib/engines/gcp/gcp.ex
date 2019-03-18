defmodule Ptolemy.Engines.GCP do
  @moduledoc """
  `Ptolemy.Engines.GCP` provides interaction with Vault's Google Cloud Secrets Engine.

  {:app_name, :another_secret, {GCP.Provider, {gcp_secret_type}}}

  """
  require Logger
  alias Ptolemy.Server
  alias Ptolemy.Engines.GCP.Engine

  @typedoc """
  Types of Google Cloud Secrets allowed by Vault. see
  """
  @type gcp_secret_type :: :access_token | :service_account_key

  def create_roleset(pid, engine_name, token_name, payload \\ test_payload()) do
    create_client(pid, engine_name)
    |> Engine.create_roleset(token_name, payload)
  end

  def test_payload() do
    %{
      "secret_type": "access_token",
      "project": "internal-tools-playground",
      "bindings": "resource \"//cloudresourcemanager.googleapis.com/projects/internal-tools-playground\" {roles = [\"roles/viewer\"]}",
      "token_scopes": [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/bigquery"
      ]
    }
  end

  #Tesla client function
  def create_client(pid, engine_name) do
    creds = Server.fetch_credentials(pid)
    {:ok, url} = Server.get_data(pid, :vault_url)
    {:ok, engines} = Server.get_data(pid, :engines)

    engine_path = engines
    |> Map.fetch!(engine_name)
    |> Map.fetch!(:engine_path)

    IO.inspect Tesla.client([
      {Tesla.Middleware.BaseUrl, "#{url}/v1/#{engine_path}"},
      {Tesla.Middleware.Headers, creds},
      {Tesla.Middleware.JSON, []}
    ])
  end

  @moduledoc """
   ## Fields

    * `:secret_type` - type of secret generated for this role set. i.e. "access_token", "service_account_key"
    * `:project` - name of the GCP project to which this roleset's service account will belong 
    * `:bindings` - bindings configuration string (read more here: https://www.vaultproject.io/docs/secrets/gcp/index.html#roleset-bindings)
    * `:token_scopes` - *Applies only if secret type is "access_token"** list of OAuth scopes to assign to secrets generated under this role set
  """
  def create_roleset(:access_token, project, bindings, scopes) do
    %{
      secret_type: "access_token",
      project: project,
      bindings: bindings,
      token_scopes: scopes
    }
  end

  def create_roleset(:service_account_key, project, bindings) do
    %{
      secret_type: "service_account_key",
      project: project,
      bindings: bindings
    }
  end
end


