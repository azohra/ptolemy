defmodule Ptolemy.Cache.CacheServer do
  @moduledoc """
  CacheServer is responsible for starting the cache.

  Starting the cache is wrapped in a GenServer so that the cache can be started via a supervisor along side the loader.
  """
  use GenServer
  alias Ptolemy.Cache

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    Cache.create_table()
    {:ok, nil}
  end
end
