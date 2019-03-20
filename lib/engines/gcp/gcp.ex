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


  @typedoc """
    A GCP roleset map

    ## Fields
    * `:secret_type` - type of secret generated for this role set. i.e. "access_token", "service_account_key"
    * `:project` - name of the GCP project to which this roleset's service account will belong
    * `:bindings` - bindings configuration string (read more here: https://www.vaultproject.io/docs/secrets/gcp/index.html#roleset-bindings)
    * `:token_scopes` - **Applies only if secret type is "access_token"** list of OAuth scopes to assign to secrets generated under this role set
  """
  @type roleset :: %{
          required(:secret_type) => String.t(),
          required(:project) => String.t(),
          required(:bindings) => String.t(),
          optional(:token_scopes) => list(String.t())
        }

  @doc """
  Creates a role set in the given engine and returns `:ok` if everything goes well.
  Throws an error message otherwise.
  """
  @spec create!(pid(), atom(), String.t(), roleset) :: :ok
  def create!(pid, engine_name, roleset_name, roleset_payload \\ test_payload()) do
    create(pid, engine_name, roleset_name, roleset_payload)
    |> case do
      {:ok, _body} -> :ok
      {:error, err} -> throw(err)
    end
  end

  @doc """
  Generates an `access token`/`service account key` from the given roleset,
  returning a map containing secret data and throwing an error of an issue occurs.
  """
  @spec read!(pid(), atom(), gcp_secret_type, String.t()) :: map()
  def read!(pid, engine_name, secret_type, roleset_name) do
    read(pid, engine_name, secret_type, roleset_name)
    |> case do
      {:ok, body} -> body
      {:error, err} -> throw(err)
    end
  end

  @doc """
  """
  @spec update!(pid(), atom(), String.t(), roleset) :: :ok
  def update!(pid, engine_name, roleset_name, roleset_payload \\ test_payload()) do
    update(pid, engine_name, roleset_name, roleset_payload)
    |> case do
      {:ok, _} -> :ok
      {:error, err} -> throw(err)
    end
  end

  @doc """
  """
  @spec delete!(pid(), atom(), gcp_secret_type, String.t()) :: :ok
  def delete!(pid, engine_name, secret_type, roleset_name) do
    delete(pid, engine_name, secret_type, roleset_name)
    |> case do
      {:ok, _} -> :ok
      {:error, err} -> throw(err)
    end
  end

  @doc """
  Retreives the current configuration for a given roleset. The response can be used for
  changing the bindings or scopes to then update the roleset. Throws an error if anything
  goes wrong.
  """
  @spec read_roleset!(pid(), atom(), String.t()) :: roleset
  def read_roleset!(pid, engine_name, roleset_name) do
    create_client(pid, engine_name)
    |> Engine.read_roleset(roleset_name)
    |> case do
      {:ok, body} -> body
      {:error, err} -> throw(err)
    end
  end

  @doc """
  Creates a roleset in the given engine from which `access token`s and
  `service account key`s can be generated.
  """
  @spec create(pid(), atom(), String.t(), roleset) :: {:ok | :error, String.t() | atom()}
  def create(pid, engine_name, roleset_name, roleset_payload \\ test_payload()) do
    create_client(pid, engine_name)
    |> Engine.create_roleset(roleset_name, roleset_payload)
  end



  @doc """
  Generates an `access token`/`service account key` from the given roleset
  """
  @spec read(pid(), atom(), gcp_secret_type, String.t()) :: {:ok, map()} | {:error, String.t()}
  def read(pid, engine_name, secret_type, roleset_name) do
    client = create_client(pid, engine_name)
    case secret_type do
      :access_token -> client |> Engine.gen_token(roleset_name)
      :service_account_key -> client |> Engine.gen_key(roleset_name)
      _ -> {:error, "unrecognized gcp secret type"}
    end
  end


  @doc """
  Updates a roleset by simply calling `create` with the new payload. This changes the
  account email. Note that once a roleset is created, only the attributes `bindings` and `token_scopes`
  can be changed.

  If you are unsure of a roleset's configuration, it is recommended that you use the
  function `read_roleset!`, update the resulting map, and then call `update` with the
  new map to ensure that you are modifying only the editable attributes.
  """
  @spec update(pid(), atom(), String.t(), roleset) ::  {:ok | :error, String.t() | atom()}
  def update(pid, engine_name, roleset_name, roleset_payload \\ test_payload()) do
    create(pid, engine_name, roleset_name, roleset_payload)
  end

  @doc """
  Rotates the roleset account by deleting it and creating an identical one with a
  different service account email (and Key ID). This invalidates keys previously
  generated by the roleset.
  """
  @spec delete(pid(), atom(), gcp_secret_type, String.t()) ::  {:ok | :error, String.t() | atom()}
  def delete(pid, engine_name, secret_type, roleset_name) do
    client = create_client(pid, engine_name)

    case secret_type do
      :access_token -> client |> Engine.rotate_roleset_key(roleset_name)
      :service_account_key -> client |> Engine.rotate_roleset(roleset_name)
      _ -> {:error, "Unrecognized GCP secret type"}
    end
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
  Creates a Tesla Client whose base URL refers to the given GCP engine.
  The GCP Engine requires this client to make API calls to the correct engine
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

    adapter = {Tesla.Adapter.Hackney, [ssl_options: [{:versions, [:"tlsv1.2"]}], recv_timeout: 20_000]}


    Tesla.client([
      {Tesla.Middleware.BaseUrl, "#{url}/v1/#{engine_path}"},
      {Tesla.Middleware.Headers, creds},
      {Tesla.Middleware.Timeout, timeout: 20_000},
      {Tesla.Middleware.JSON, []}
    ], adapter)
  end

  @doc """
  Generates type `roleset` from inputs
  """

  @spec create_roleset(gcp_secret_type, String.t(), String.t(), list(String.t())) :: roleset
  def create_roleset(secret_type, project, bindings, scopes \\ []) do
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
        {:error, "Unrecognized GCP secret type"}
    end
  end
end
