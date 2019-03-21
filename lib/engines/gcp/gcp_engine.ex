defmodule Ptolemy.Engines.GCP.Engine do
  @moduledoc """
  `Ptolemy.Engines.GCP.Engine` provides low level API interaction with the Vault GCP Secrets Engine

  More information on the API this implements can be found at https://www.vaultproject.io/api/secret/gcp/index.html
  """

  alias Ptolemy.Engines.GCP

  @doc """
  Submits a POST request to create a roleset
  """
  @spec create_roleset(Tesla.Client.t(), String.t(), GCP.roleset()) ::
          {:ok | :error, String.t() | atom()}
  def create_roleset(client, name, payload) do
    with {:ok, resp} <- Tesla.post(client, "/roleset/#{name}", payload) do
      case {resp.status, resp.body} do
        {status, _body} when status in 200..299 ->
          {:ok, "Roleset implemented"}

        {status, body} ->
          message = Map.fetch!(body, "errors")
          {:error, "Roleset creation failed, Status: #{status} with error: #{message}"}
      end
    else
      err -> err
    end
  end

  @doc """
  Submits a GET request to retrieve the configuration of a given roleset.
  """
  @spec read_roleset(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, String.t() | atom()}
  def read_roleset(client, roleset_name) do
    with {:ok, resp} <- Tesla.get(client, "/roleset/#{roleset_name}") do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          {:ok, body["data"]}

        {status, body} ->
          message = Map.fetch!(body, "errors")
          {:error, "Reading roleset failed, Status: #{status} with error: #{message}"}
      end
    end
  end

  @doc """
  Submits a POST request to rotate a roleset account's email and Key ID
  """
  @spec rotate_roleset(Tesla.Client.t(), String.t()) :: {:ok | :error, String.t() | atom()}
  def rotate_roleset(client, roleset_name) do
    with {:ok, resp} <- Tesla.post(client, "/roleset/#{roleset_name}/rotate", %{}) do
      case {resp.status, resp.body} do
        {status, _body} when status in 200..299 ->
          {:ok, "Rotated"}

        {status, body} ->
          message = Map.fetch!(body, "errors")
          {:error, "Rotate roleset failed, Status: #{status} with error: #{message}"}
      end
    end
  end

  @doc """
  Submits a POST request to rotate a roleset account's Key ID. Only works on
  `access_token` type rolesets.
  """
  @spec rotate_roleset_key(Tesla.Client.t(), String.t()) :: {:ok | :error, String.t() | atom()}
  def rotate_roleset_key(client, roleset_name) do
    with {:ok, resp} <- Tesla.post(client, "/roleset/#{roleset_name}/rotate-key", %{}) do
      case {resp.status, resp.body} do
        {status, _body} when status in 200..299 ->
          {:ok, "Rotated"}

        {status, body} ->
          message = Map.fetch!(body, "errors")
          {:error, "Rotate roleset-key failed, Status: #{status} with error: #{message}"}
      end
    end
  end

  @doc """
  Submits a GET request to retrieve a temporary Oauth2 token from an `access_token` roleset.
  """
  @spec gen_token(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, String.t() | atom()}
  def gen_token(client, roleset_name) do
    with {:ok, resp} <- Tesla.get(client, "token/#{roleset_name}") do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          {:ok, body["data"]}

        {status, body} ->
          message = Map.fetch!(body, "errors")
          {:error, "Generating Oauth2 token failed, Status: #{status} with error: #{message}"}
      end
    else
      err -> err
    end
  end

  @doc """
  Submits a GET request to retrieve a service account key from a `service_account_key` roleset.
  """
  @spec gen_key(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, String.t() | atom()}
  def gen_key(client, roleset_name) do
    with {:ok, resp} <- Tesla.get(client, "key/#{roleset_name}") do
      case {resp.status, resp.body} do
        {status, body} when status in 200..299 ->
          {:ok, body["data"]}

        {status, body} ->
          message = Map.fetch!(body, "errors")
          {:error, "Generating svc acc key failed, Status: #{status} with error: #{message}"}
      end
    else
      err -> err
    end
  end

  def create_roleset(client, name, payload) do
    Tesla.post(client, "/roleset/#{name}", payload)
  end
end
