defmodule Ptolemy.Engines.GCP.Engine do
  @moduledoc """
  `Ptolemy.Engines.GCP.Engine` provides low level interaction with the Vault GCP Engine API
  """
  require Logger

  # client iff server


  def read_roleset(client, name)
  def rotate_roleset(client, name) #equivalent to invalidating the tokens under that roleset

  def create_roleset(client, name, payload)
  def create_token_roleset(client, name, project, bindings, scopes)
  def create_svc_acc_roleset(client, name, project, bindings)

  def gen_token(client, roleset_name)
  def gen_key(client, roleset_name)

  # client (server)  vvvvIn the configvvvvv
  # path (token type, token name)
  # payload (project, binding, scopes)
  def create_roleset(client, name, payload) do
    Tesla.post(client, "/roleset/#{name}", payload)
  end

end