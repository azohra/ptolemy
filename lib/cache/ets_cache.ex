defmodule Ptolemy.Cache.ETSCache do
  @moduledoc """
  `Ptolemy.Cache.ETSCache` is a cache implementation backed by ETS.

  The cache is started as a named table so the underlying pid does not need to be shared between processes.
  The cache itself is meant to be started by CacheServer so that in the future, if the pid does need to be shared
  other processes can query the pid from CacheServer.
  """
  @behaviour Ptolemy.Cache.CacheBehaviour
  @cache_name __MODULE__

  @spec create_table :: atom
  def create_table() do
    :ets.new(@cache_name, [:public, :named_table])
  end

  @spec put(any, any) :: true
  def put(key, value) do
    :ets.insert(@cache_name, {key, value})
  end

  @spec get(any) :: any | :not_found
  def get(key) do
    case :ets.lookup(@cache_name, key) do
      [{^key, value}] -> value
      [] -> :not_found
    end
  end

  @spec clear_cache :: true
  def clear_cache() do
    :ets.delete_all_objects(@cache_name)
  end
end
