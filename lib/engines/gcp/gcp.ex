defmodule Ptolemy.Engines.GCP.Engine do
  @moduledoc """
  `Ptolemy.Engines.GCP` provides interaction with Vault's Google Cloud Secrets Engine.
  """
  require Logger

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
end