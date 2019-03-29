defmodule Ptolemy.Providers.Vault do
  @moduledoc """
  A module that provides Vault secrets.
  
  # Example
  Add to your configuration:
  ```elixir
  alias Ptolemy.Providers.SystemEnv
  config :ptolemy, loader: [
    env: [
      {{:app_name, :config_key}, {Vault, "VAR_NAME"}}
    ]
  ]
  ```
  The `:app_name` and `:config_key` are added to reference the application environment
  key that will be set. The value can be accessed at any time with `Application.get_env/2`.
  `"VAR_NAME"` is the name of the system environment variable that will be loaded on
  application startup. Loaded values are all static and will never be updated during runtime.

  # Required Environment Variables
  None
  """
  
  use Ptolemy.Provider

  @doc """
  init/1 starts Ptolemy servers are supervised processes under current running process. It 
  tries to start all the servers configured in config.exs. If all the servers are started
  successfully, it return :ok back. Else, it returns {:error, res} with res being a list of
  failed servers.
  """
  @callback init(pid) :: :ok | {:error, String.t()}
  def init(_loader_pid) do
    res = Application.get_env(:ptolemy, :vaults)
      |> Enum.map(fn {k, _} -> k end)
      |> Enum.reject(&(elem(Ptolemy.start(&1, &1), 0) == :ok))

    case Enum.empty?(res) do
        true -> :ok
        false -> {:error, res}
    end
  end

  @doc """
  load/2 reads in the data from Ptolemy's vault interface and check if the secret will expire.
  If it does, it would register the secret's ttl with the loader, so the loader can load the
  secret again later. If the ttl doesn't exist, it will skip and return the data.

  var_args is a 4-element list
  1. pid
    pid denotes the server that holds the state of vault server
  2. engine_name
    engine_name helps Ptolemy to find the correct engine configuration
  3. opts
    opts is another list, the content depends on engine type. See `ptolemy.ex` docs for more.
  4. access_keys 
    access keys is a list of keys to access a specific element within the returned nested
    data structure
  """
  @callback load(pid, [pid() | atom() | [any()]]) :: :ok | {:error, String.t()}
  def load(loader_pid, var_args) do
    [pid, engine_name, opts, access_keys] = var_args
    calling_args = [pid, engine_name, opts]
    {:ok, data} = apply(Ptolemy, :read, calling_args)

    ttl_fetch_fn = [&fetch_lease/1, &fetch_max_ttl/1 ]

    load_result = Enum.reduce_while(ttl_fetch_fn, :error, fn ttl_fn, _ -> 
      case ttl_fn.(data) do
        {:ok, ttl} -> 
            if ttl > 0 do
                register_ttl(loader_pid, var_args, ttl, :seconds)
            end
            {:halt, :ok}
        _ -> {:cont, :error}
      end
    end)

    case load_result do
      :ok -> 
        with {:ok, data} <- Map.fetch(data, "data")
          do
            custom_get_in(data, access_keys)
          else
            _ -> {:error, "'data' key does not exist in the response"}
        end
      _ -> {:error, "No matching fetch ttl function"}
    end
  end

  #
  # Functions that attempt to extract ttl from the data
  #
  defp fetch_lease(data) do
    Map.fetch(data, "lease_duration")
  end

  defp fetch_max_ttl(data) do
    with {:ok, data} <- Map.fetch(data, "data"),
      {:ok, data} <- Map.fetch(data, "token_ttl") 
    do
      {:ok, data}  
    else
      _ -> {:error, "Failed to fetch ttl for token"}
    end
  end

  defp custom_get_in(data, [] = _key_list) do
    data
  end

  defp custom_get_in(data, key_list) do
    get_in(data, key_list)
  end
end