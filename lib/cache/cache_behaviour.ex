defmodule Ptolemy.Cache.CacheBehaviour do
  @callback create_table() :: atom
  @callback put(any(), any()) :: true
  @callback get(any()) :: any() | :not_found
  @callback clear_cache() :: true
end
