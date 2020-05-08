defmodule Ptolemy.Cache.Cache do
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

  def clear_cache() do
    :ets.delete_all_objects(@cache_name)
  end
end
