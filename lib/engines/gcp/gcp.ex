defmodule Ptolemy.Engines.GCP do
  @moduledoc """
  `Ptolemy.Engines.GCP` provides a public facing API for CRUD operations for the Vault GCP engine.
  """
  alias Ptolemy.Server
  alias Ptolemy.Engines.GCP.Engine

  @typedoc """
  Types of Google Cloud Secrets allowed by Vault
  """
  @type gcp_secret_type() :: :access_token | :service_account_key

  @typedoc """
    A GCP roleset map.

    Fields:
    * `:secret_type` - type of secret generated for this role set. i.e. "access_token", "service_account_key"
    * `:project` - name of the GCP project to which this roleset's service account will belong
    * `:bindings` - bindings configuration string (read more here: https://www.vaultproject.io/docs/secrets/gcp/index.html#roleset-bindings)
    * `:token_scopes` - *Applies only if secret type is `access_token`* list of OAuth scopes belonging to secrets generated under this role set
  """
  @type roleset :: %{
          required(:secret_type) => String.t(),
          required(:project) => String.t(),
          required(:bindings) => String.t(),
          optional(:token_scopes) => list(String.t())
        }

  @doc """
  Creates a roleset account in the given engine, erroring out if an error occurs.
  """
  @spec create!(atom(), atom(), String.t(), roleset) :: :ok
  def create!(server_name, engine_name, roleset_name, roleset_payload) do
    create(server_name, engine_name, roleset_name, roleset_payload)
    |> case do
      {:ok, _body} -> :ok
      {:error, err} -> raise err
    end
  end

  @doc """
  Generates an `access token`/`service account key` from the given roleset, erroring out if an error occurs.
  """
  @spec read!(atom(), atom(), gcp_secret_type, String.t()) :: map()
  def read!(server_name, engine_name, secret_type, roleset_name) do
    read(server_name, engine_name, secret_type, roleset_name)
    |> case do
      {:ok, body} -> body
      {:error, err} -> raise err
    end
  end

  @doc """
  Updates a roleset account given a new payload, erroring out if an error occurs.
  """
  @spec update!(atom(), atom(), String.t(), roleset) :: :ok
  def update!(server_name, engine_name, roleset_name, roleset_payload) do
    update(server_name, engine_name, roleset_name, roleset_payload)
    |> case do
      {:ok, _} -> :ok
      {:error, err} -> raise err
    end
  end

  @doc """
  Rotates a roleset account, erroring out if an error occurs.

  See the documentation for `delete/4` for more information on the exact behaviour
  of rotating rolesets.
  """
  @spec delete!(atom(), atom(), gcp_secret_type, String.t()) :: :ok
  def delete!(server_name, engine_name, secret_type, roleset_name) do
    delete(server_name, engine_name, secret_type, roleset_name)
    |> case do
      {:ok, _} -> :ok
      {:error, err} -> raise err
    end
  end

  @doc """
  Retreives the current configuration for a given roleset, erroring out if an error occurs.

  The response can be used for changing the bindings or scopes to then update the roleset.
  """
  @spec read_roleset!(atom(), atom(), String.t()) :: roleset
  def read_roleset!(server_name, engine_name, roleset_name) do
    create_client(server_name, engine_name)
    |> Engine.read_roleset(roleset_name)
    |> case do
      {:ok, body} -> body
      {:error, err} -> raise err
    end
  end

  @doc """
  Creates a roleset account in the given engine from which `access token`'s and service account key's can be generated.

  ## Example
  ```elixir
  iex(1)> Ptolemy.Engines.GCP.create(server, :gcp_engine, "roleset_name", %{
    bindings: "resource "//cloudresourcemanager.googleapis.com/projects/project-name" {roles = ["roles/viewer"]}",
    project: "project-name",
    secret_type: "service_account_key"
  })
  {:ok, "Roleset implemented"}
  ```
  """
  @spec create(atom(), atom(), String.t(), roleset) :: {:ok, String.t()} | {:error, String.t()}
  def create(server_name, engine_name, roleset_name, roleset_payload) do
    create_client(server_name, engine_name)
    |> Engine.create_roleset(roleset_name, roleset_payload)
  end

  @doc """
  Generates an `access token`/`service account key` from the given roleset

  ## Example
  ```elixir
  iex(2)> Ptolemy.Engines.GCP.read(server, :gcp_engine, :service_account_key, "roleset_name")
  {:ok, %{
    "key_algorithm" => "KEY_ALG_RSA_2048"
    "key_type" => "TYPE_GOOGLE_CREDENTIALS_FILE",
    "private_key_data" => "shhh....."
  }}

  iex(3)> Ptolemy.Engines.GCP.read(server, :gcp_engine, :access_token, "access_roleset")
  {:ok, %{
    "expires_at_seconds" => 1553274174,
    "token" => "shhh.....",
    "token_ttl" => 3599
  }}
  ```
  """
  @spec read(atom(), atom(), gcp_secret_type, String.t()) :: {:ok, map()} | {:error, String.t()}
  def read(server_name, engine_name, secret_type, roleset_name) do
    client = create_client(server_name, engine_name)

    case secret_type do
      :access_token -> client |> Engine.gen_token(roleset_name)
      :service_account_key -> client |> Engine.gen_key(roleset_name)
      _ -> {:error, "unrecognized gcp secret type"}
    end
  end

  @doc """
  Updates a roleset by simply calling `create` with the new payload.

  This changes the account email.

  Note that once a roleset is created, only the attributes `bindings` and `token_scopes` can be changed.

  If you are unsure of a roleset's configuration, it is recommended that you use the
  function `read_roleset!/3`, update the resulting map, and then call `update` with the
  new map to ensure that you are modifying only the editable attributes.

  ## Example
  ```elixir
  iex(4)> Ptolemy.Engines.GCP.update(server, :gcp_engine, "roleset_name", %{
    bindings: "resource "//cloudresourcemanager.googleapis.com/projects/project-name" {roles = ["roles/editor"]}",
    project: "project-name",
    secret_type: "service_account_key"
  })
  {:ok, "Roleset implemented"}
  ```
  """
  @spec update(atom(), atom(), String.t(), roleset) :: {:ok, String.t()} | {:error, String.t()}
  def update(server_name, engine_name, roleset_name, roleset_payload) do
    create(server_name, engine_name, roleset_name, roleset_payload)
  end

  @doc """
  Rotate a roleset account.

  The Vault Google Secret Engine API offers multiple endpoints for rotating roleset accounts to invalidate previously generated secrets.

  There are two methods:

  ## Rotate Roleset Account Key
    * This method is only for `access_token` secrets and is triggered by calling this function with `:access_token`
    * This method will change the KeyID that the roleset account uses to generate secrets
    * Based on testing, this method does not invalidate previously generated tokens but we're supporting it anyway

  ## Rotate Roleset Account
    * This method is works for both `gcp_secret_type`s and is triggered by calling this function with `:service_account_key`
    * This method will replace the KeyID AND the email that the roleset account uses to generate secrets
    * Based on testing, this method immediately invalidates previously generated secrets

  ## Example
  ```elixir
  iex(5)> Ptolemy.Engines.GCP.delete(server, :gcp_engine, :service_account_key, "new_roleset")
  {:ok, "Rotated"}
  ```
  """
  @spec delete(atom(), atom(), gcp_secret_type, String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def delete(server_name, engine_name, secret_type, roleset_name) do
    client = create_client(server_name, engine_name)

    case secret_type do
      :access_token -> client |> Engine.rotate_roleset_key(roleset_name)
      :service_account_key -> client |> Engine.rotate_roleset(roleset_name)
      _ -> {:error, "Unrecognized GCP secret type"}
    end
  end

  @doc """
  Generates type `roleset` from inputs.
  """
  @spec generate_roleset(gcp_secret_type, String.t(), String.t(), list(String.t())) :: roleset
  def generate_roleset(secret_type, project, bindings, scopes \\ []) do
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

  @doc """
  Creates a Tesla Client whose base URL refers to the given GCP engine.

  The GCP Engine requires this client to make API calls to the correct engine.
  """
  @spec create_client(atom(), atom()) :: %Tesla.Client{}
  def create_client(server_name, engine_name) do
    creds = Server.fetch_credentials(server_name)

    {:ok, url} = Server.get_data(server_name, :vault_url)
    {:ok, engines} = Server.get_data(server_name, :engines)

    engine_path =
      engines
      |> Keyword.fetch!(engine_name)
      |> Map.fetch!(:engine_path)

    adapter =
      {Tesla.Adapter.Hackney, [ssl_options: [{:versions, [:"tlsv1.2"]}], recv_timeout: 10_000]}

    middleware = client_middleware(Mix.env(), url, engine_path, creds)

    if Mix.env() == :test do
      Tesla.client(middleware)
    else
      Tesla.client(middleware, adapter)
    end
  end

  defp client_middleware(:test, base_url, engine_path, creds) do
    [
      {Tesla.Middleware.BaseUrl, "#{base_url}/v1/#{engine_path}"},
      {Tesla.Middleware.Headers, creds},
      {Tesla.Middleware.JSON, []}
    ]
  end

  defp client_middleware(_env, base_url, engine_path, creds) do
    [
      {Tesla.Middleware.BaseUrl, "#{base_url}/v1/#{engine_path}"},
      {Tesla.Middleware.Headers, creds},
      {Tesla.Middleware.Timeout, timeout: 10_000},
      {Tesla.Middleware.JSON, []}
    ]
  end
end
