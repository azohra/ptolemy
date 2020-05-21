defmodule Ptolemy.Providers.SystemEnvTest do
  use ExUnit.Case
  import Mox

  alias Ptolemy.Loader

  setup :verify_on_exit!

  test "can load a system env var", %{test: test_name} do
    expect(CacheMock, :clear_cache, fn -> true end)

    {:ok, _loader} =
      Loader.start_link(
        env: [
          {{test_name, :loaded_value}, {Ptolemy.Providers.SystemEnv, "PATH"}}
        ]
      )

    assert Application.get_env(test_name, :loaded_value) == System.get_env("PATH")
  end
end
