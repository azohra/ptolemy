defmodule Ptolemy.Cache do
  @moduledoc """
  `Ptolemy.Cache` is a facade module used to access different implementations of the cache.

  When using Ptolemy to load enviroment variables, the actual `ETSCache` is used.
  During testing, the cache is mocked using `Mox` and that mock is substituted in.
  This substitution is done via configurations set.
  """

  # This needs to be done since when an application starts up the LoaderSupervisor, the config for Ptolemy is not read
  # and so the application variable to set the cache is not configured.
  # It needs to be a function and not a module constant since we need to be able to change the config during testing.
  defp cache(), do: Application.get_env(:ptolemy, :cache, Ptolemy.Cache.ETSCache)

  @doc """
  Initializes the cache.
  """
  @spec create_table :: atom
  def create_table(), do: cache().create_table()

  @doc """
  Put a Key-Value-Pair into the cache.any()

  If the key already exists, the old value will be overwritten by the new value.
  """
  @spec put(any, any) :: true
  def put(key, value), do: cache().put(key, value)

  @doc """
  Get a value from the cache.
  """
  @spec get(any) :: any | :not_found
  def get(key), do: cache().get(key)

  @doc """
  Delete all entries in the cache.
  """
  @spec clear_cache :: true
  def clear_cache(), do: cache().clear_cache()
end
