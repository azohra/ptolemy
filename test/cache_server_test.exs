defmodule CacheServerTest do
  use ExUnit.Case

  alias Ptolemy.Cache
  alias Ptolemy.Cache.{ETSCache, CacheServer}

  setup do
    Application.put_env(:ptolemy, :cache, ETSCache)

    on_exit fn ->
      Application.put_env(:ptolemy, :cache, CacheMock)
    end
  end

  test "starting the server also starts the cache" do
    assert_raise(ArgumentError, fn -> Cache.get("key") end)
    CacheServer.start_link(nil)
    assert Cache.put("key", "value")
  end
end
