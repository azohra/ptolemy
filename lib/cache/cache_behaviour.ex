defmodule Ptolemy.Cache.CacheBehaviour do
  @moduledoc """
  `Ptolemy.Cache.CacheBehaviour` defines behaviours that any implementation of a cache must satisfy.
  """

  @callback create_table() :: atom
  @callback put(any(), any()) :: true
  @callback get(any()) :: any() | :not_found
  @callback clear_cache() :: true
end
