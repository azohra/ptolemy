defmodule Ptolemy.Provider do
  @moduledoc """
  `Ptolemy.Provider` defines behaviours for implementing a configuration provider.

  The source that `Ptolemy.Loader` pulls values from are defined
  by providers. Each provider is responsible for retrieving a value, given a query.
  Once implemented, a provider can supply dynamic run time environment variables and
  keep them up to date.

  # Example

  In it's simplest form, a provider should be a light API wrapper for retrieving a
  value given some kind of query. A good example would be `Ptolemy.Providers.SystemEnv`:

  ```elixir
  defmodule Ptolemy.Providers.SystemEnv do
    use Ptolemy.Provider

    def init(_loader_pid), do: :ok

    def load(_loader_pid, var_name) do
      System.get_env(var_name)
    end
  end
  ```

  When `Ptolemy.Loader` first starts up, it will iterate over each item from the environment config.
  The first time the loader comes across a provider, it will be initialized by calling
  the `init/1` callback. For every other occurrence in the startup sequence, `init/1` will **not**
  be called. In the example above, there is no setup action required to use `System.get_env/1`,
  so it will simply return `:ok`.

  During the loader's startup iteration over the configuration, it will potentially query the same
  loader many times. Each time it queries, it will invoke the `load/2` callback to preform the lookup.
  For the example above, the lookup is a call to `System.get_env/1`.

  # Managing Expiring or Changing Configurations

  Sometimes, secrets are needed that change over time. When this is the case, the loader can be sent
  a message signaling that a configuration has likely changed. The most common form of such dynamic
  secrets is with a TTL. Providers can support values with a TTL by utilizing the `register_ttl/3`
  utility method. A simple example would look like:

  ```elixir
    defmodule TtlExample do
      use Ptolemy.Provider

      def init(_loader_pid), do: :ok

      def load(loader_pid, query) do
        {value, ttl} = MyApp.get_value(query)
        register_ttl(loader_pid, query, ttl)
        value
      end
    end
  ```

  This implementation will notify the loader to re-load the value after a given TTL has expired. When
  the loader is notified, it will call the `load/2` callback again, returning the updated value and
  giving the opportunity to set another TTL.

  # Loading as a Single Process

  The loader and providers all execute on the same process. The primary reason for this is because of the role
  of a provider must perform. Foremost, providers should yield values in the order they are defined in the configuration.
  This requirement allows earlier providers to supply configuration to later executing providers that may
  require additional configuration before they could yield values. After the initialization of the loader,
  there is little reason for providers to remain on the same process, however for now it simplifies the loader.

  # Depending on External Processes

  The intention of a provider is to be a simple external API wrapper. Sometimes, external APIs require
  a process to be started to manage interactions. The loader process should usually be  started first
  in the application's supervision tree, as it will need to populate the configuration of the application.
  Any required process should then be started in a provider's `init/1` definition. This will ensure that
  process dependencies are started as late as possible in the startup of the application. This ensures that
  dependent process will also be able to be configured by providers that appear earlier in the loader configuration.
  """

  @doc """
  Invoked to setup a provider. This callback is only called once per provider, and is called lazily.
  """
  @callback init(pid) :: :ok | {:error, String.t()}

  @doc """
  Invoked when querying the provider for a value.
  """
  @callback load(pid, any) :: any

  @doc false
  defmacro __using__(_args) do
    implement_helpers()
  end

  defp implement_helpers do
    quote do
      @behaviour Ptolemy.Provider

      @doc false
      def register_ttl(loader_pid, query, ttl, ttl_unit \\ :milliseconds) do
        Process.send_after(
          loader_pid,
          {:expired, {__MODULE__, query}},
          Ptolemy.Provider.to_millis(ttl, ttl_unit)
        )
      end
    end
  end

  @typedoc """
  Accepted units of time for scheduling a ttl.
  """
  @type time_unit :: :milliseconds | :seconds | :minutes | :hours

  @doc """
  Used to convert accepted time units to milliseconds.

  This is used internally for scheduling.
  """
  @spec to_millis(non_neg_integer, time_unit) :: non_neg_integer
  def to_millis(time, time_unit)
  def to_millis(time, :hours), do: time * 3.6e+6
  def to_millis(time, :minutes), do: time * 60000
  def to_millis(time, :seconds), do: time * 1000
  def to_millis(time, :milliseconds), do: time
end
