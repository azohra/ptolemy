defmodule Ptolemy.Cache.CacheServer do
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
