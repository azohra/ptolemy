defmodule Ptolemy.Engines.GCP do
    @moduledoc """
    `Ptolemy.Engines.GCP` provides interaction with a Vault server's GCP secret egnine to get access tokens and service account keys.
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