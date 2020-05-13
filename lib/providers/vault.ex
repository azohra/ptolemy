defmodule Ptolemy.Providers.Vault do
  @moduledoc """
  `Ptolemy.Providers.Vault` provides from Vault secrets.

  # Example
  Add to your configuration:
  ```elixir
  alias Ptolemy.Providers.Vault
  config :ptolemy, loader: [
    env: [
      {{:app_name, :config_key}, {Vault, [:engine1, [:secret1], ["key1", "key2"]]}}
    ]
  ]
  ```
  The `:app_name` and `:config_key` are added to reference the application environment
  key that will be set. The value can be accessed at any time with `Application.get_env/2`.

  Vault is the module name of this provider is calling

  The second element of the tuple is a list of arguments
  1. The name of engine which this secret belongs to
  2. This is another list which consists of the arguments required to call this engine's `read`
     function. More details can be found in `ptolemy.ex`
  3. This let you specify which part of the returned result should be stored in the application
     environment keys. This support nested strcutures.

  # Required Environment Variables
  None
  """

  use Ptolemy.Provider

  @doc """
  Starts Ptolemy servers are supervised processes under current running process.

  It tries to start all the servers configured in config.exs. If all the servers are started
  successfully, it return :ok back. Else, it returns {:error, res} with res being a list of
  failed servers.
  """
  @callback init(pid) :: :ok | {:error, String.t()}
  def init(_loader_pid) do
    res =
      Application.get_env(:ptolemy, :vaults)
      |> Enum.map(fn {k, _} -> k end)
      |> Enum.reject(&(elem(Ptolemy.start(&1, &1), 0) == :ok))

    case Enum.empty?(res) do
      true -> :ok
      false -> {:error, res}
    end
  end

  @doc """
  Reads in the data from Ptolemy's vault interface and check if the secret will expire.

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

    ttl_fetch_fn = [&fetch_max_ttl/1, &fetch_cert_ttl/1, &fetch_lease/1]

    load_result =
      Enum.reduce_while(ttl_fetch_fn, :error, fn ttl_fn, _ ->
        case ttl_fn.(data) do
          {:ok, ttl} ->
            if ttl > 0 do
              register_ttl(loader_pid, var_args, ttl, :seconds)
            end

            {:halt, :ok}

          _ ->
            {:cont, :error}
        end
      end)

    case load_result do
      :ok ->
        with {:ok, data} <- Map.fetch(data, "data") do
          custom_get_in(data, access_keys)
        else
          _ -> {:error, "'data' key does not exist in the response"}
        end

      _ ->
        {:error, "No matching fetch ttl function"}
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
         {:ok, data} <- Map.fetch(data, "token_ttl") do
      {:ok, data}
    else
      _ -> {:error, "Failed to fetch ttl for token"}
    end
  end

  defp fetch_cert_ttl(data) do
    with {:ok, data} <- Map.fetch(data, "data"),
         {:ok, data} <- Map.fetch(data, "expiration") do
      data = data - :os.system_time(:seconds)
      {:ok, data}
    else
      _ -> {:error, "Failed to fetch ttl for pki certificate"}
    end
  end

  defp custom_get_in(data, [] = _key_list) do
    data
  end

  defp custom_get_in(data, [head | tail]) do
    case data[head] do
      nil -> raise "#{head} key does not exist in the response body!}"
      data -> custom_get_in(data, tail)
    end
  end
end
