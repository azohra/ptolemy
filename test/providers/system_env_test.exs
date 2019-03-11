defmodule Ptolemy.Providers.SystemEnvTest do
  use ExUnit.Case

  alias Ptolemy.Loader

  test "can load a system env var", %{test: test_name} do
    {:ok, _loader} =
      Loader.start_link(
        env: [
          {{test_name, :loaded_value}, {Ptolemy.Providers.SystemEnv, "PATH"}}
        ]
      )

    assert Application.get_env(test_name, :loaded_value) == System.get_env("PATH")
  end
end
