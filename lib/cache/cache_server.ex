defmodule Ptolemy.Cache.CacheServer do
  use GenServer
  alias Ptolemy.Cache.Cache

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    Cache.create_table()
    {:ok, nil}
  end

  def set_cache_ttl(ttl, ttl_unit \\ :milliseconds, notify_pid \\ nil) do
    Process.send_after(__MODULE__, {:clear_cache, notify_pid}, Ptolemy.Provider.to_millis(ttl, ttl_unit))
  end

  def handle_info({:clear_cache, notify_pid}, _from, _state) do
    Cache.clear_cache()
    notify_cache_clear(notify_pid)
    {:noreply, nil}
  end

  defp notify_cache_clear(nil), do: nil
  defp notify_cache_clear(notify_pid) do
    send(notify_pid, :cache_cleared)
  end
end
