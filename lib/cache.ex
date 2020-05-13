defmodule Ptolemy.Cache do
  defp cache() do
    case Application.get_env(:ptolemy, :cache) do
      nil -> Ptolemy.Cache.ETSCache
      cache -> cache
    end
  end

  @spec create_table :: atom
  def create_table(), do: cache().create_table()

  @spec put(any, any) :: true
  def put(key, value), do: cache().put(key, value)

  @spec get(any) :: any | :not_found
  def get(key), do: cache().get(key)

  @spec clear_cache :: true
  def clear_cache(), do: cache().clear_cache()
end
