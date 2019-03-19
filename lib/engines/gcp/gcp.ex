defmodule Ptolemy.Engines.GCP do
  @moduledoc """
  `Ptolemy.Engines.GCP` provides interaction with Vault's Google Cloud Secrets Engine.

  {{:app_name, :another_secret}, {GCP.Provider, {server, engine_name, gcp_secret_type, secret_name}}}

  """
  alias Ptolemy.Server
  alias Ptolemy.Engines.GCP.Engine

  @typedoc """
  Types of Google Cloud Secrets allowed by Vault
  """
  @type gcp_secret_type :: :access_token | :service_account_key

  @spec create(pid, atom, binary, map) :: map
  def create(pid, engine_name, token_name, roleset_payload \\ test_payload()) do
    create_client(pid, engine_name)
    |> Engine.create_roleset(token_name, roleset_payload)
  end

  @spec read(pid, atom, gcp_secret_type, binary) :: map
  def read(pid, engine_name, secret_type, roleset_name) do
    client = create_client(pid, engine_name)

    case secret_type do
      :access_token -> client |> Engine.gen_token(roleset_name)
      :service_account_key -> client |> Engine.gen_key(roleset_name)
      _ -> {:error, "unrecognized gcp secret type"}
    end
  end

  @spec update(pid, atom, binary, map) :: map
  def update(pid, engine_name, token_name, roleset_payload \\ test_payload()) do
    create(pid, engine_name, token_name, roleset_payload)
  end

  @spec delete(pid, atom, gcp_secret_type, binary) :: map
  def delete(pid, engine_name, secret_type, roleset_name) do
    create_client(pid, engine_name)
    |> Engine.gen_token(roleset_name)
  end

  @doc false
  def test_payload() do
    %{
      secret_type: "access_token",
      project: "internal-tools-playground",
      bindings:
        "resource \"//cloudresourcemanager.googleapis.com/projects/internal-tools-playground\" {roles = [\"roles/viewer\"]}",
      token_scopes: [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/bigquery"
      ]
    }
  end

  @doc """
  Creates a Tesla Client with 
  """
  @spec create_client(pid, atom) :: map
  def create_client(pid, engine_name) do
    creds = Server.fetch_credentials(pid)
    {:ok, url} = Server.get_data(pid, :vault_url)
    {:ok, engines} = Server.get_data(pid, :engines)

    engine_path =
      engines
      |> Map.fetch!(engine_name)
      |> Map.fetch!(:path)

    IO.inspect(
      Tesla.client([
        {Tesla.Middleware.BaseUrl, "#{url}/v1/#{engine_path}"},
        {Tesla.Middleware.Headers, creds},
        {Tesla.Middleware.Timeout, timeout: 20_000},
        {Tesla.Middleware.JSON, []}
      ])
    )
  end

  @doc """
    Creates a map that represents a GCP role set 

    ## Fields
    * `:secret_type` - type of secret generated for this role set. i.e. "access_token", "service_account_key"
    * `:project` - name of the GCP project to which this roleset's service account will belong 
    * `:bindings` - bindings configuration string (read more here: https://www.vaultproject.io/docs/secrets/gcp/index.html#roleset-bindings)
    * `:token_scopes` - **Applies only if secret type is "access_token"** list of OAuth scopes to assign to secrets generated under this role set
  """
  @spec create_roleset(gcp_secret_type, binary, binary, [binary]) :: map
  def create_roleset(secret_type, project, bindings, scopes \\ []) do
    payload =
      case secret_type do
        :access_token ->
          %{
            secret_type: "access_token",
            project: project,
            bindings: bindings,
            token_scopes: scopes
          }

        :service_account_key ->
          %{
            secret_type: "service_account_key",
            project: project,
            bindings: bindings
          }

        _ ->
          {:error, "unrecognized gcp secret type"}
      end
  end
end
