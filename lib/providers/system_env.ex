defmodule Ptolemy.Providers.SystemEnv do
  @moduledoc """
  `Ptolemy.Providers.SystemEnv` provides from system environment variables.

  # Example
  Add to your configuration:
  ```elixir
  alias Ptolemy.Providers.SystemEnv
  config :ptolemy, loader: [
    env: [
      {{:app_name, :config_key}, {SystemEnv, "VAR_NAME"}}
    ]
  ]
  ```
  The `:app_name` and `:config_key` are added to reference the application environment
  key that will be set. The value can be accessed at any time with `Application.get_env/2`.
  `"VAR_NAME"` is the name of the system environment variable that will be loaded on
  application startup. Loaded values are all static and will never be updated during runtime.

  # Required Environment Variables
  None
  """

  use Ptolemy.Provider

  def init(_loader_pid), do: :ok

  def load(_loader_pid, var_name) do
    System.get_env(var_name)
  end
end
