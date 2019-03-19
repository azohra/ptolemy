defmodule Ptolemy.Engines.GCP.Engine do
  @moduledoc """
  `Ptolemy.Engines.GCP.Engine` provides low level interaction with the Vault GCP Engine API
  """
  def read_roleset(client, roleset_name) do
    with {:ok, resp} <- Tesla.get(client, "/roleset/#{roleset_name}") do
      case {resp.status, resp.body} do
        {200, body} -> {:ok, body}
        {status, body} -> {:error, body}
      end
    end
  end

  # equivalent to invalidating the tokens under that roleset
  def rotate_roleset(client, roleset_name) do
    with {:ok, resp} <- Tesla.post(client, "/roleset/#{roleset_name}/rotate", %{}) do
      case {resp.status, resp.body} do
        {204, body} -> {:ok, body}
        {status, body} -> {:error, body}
      end
    end
  end

  def rotate_roleset_key(client, roleset_name) do
    with {:ok, resp} <- Tesla.post(client, "/roleset/#{roleset_name}/rotate-key", %{}) do
      case {resp.status, resp.body} do
        {204, body} -> {:ok, body}
        {status, body} -> {:error, body["errors"]}
      end
    end
  end

  def gen_token(client, roleset_name) do
    Tesla.get(client, "token/#{roleset_name}")
  end

  def gen_key(client, roleset_name) do
    Tesla.get(client, "key/#{roleset_name}")
  end

  def create_roleset(client, name, payload) do
    Tesla.post(client, "/roleset/#{name}", payload)
  end
end
