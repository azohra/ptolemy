defmodule Ptolemy.Loader do
  @moduledoc """
  `Ptolemy.Loader` implements a highly opinionated Application Configuration solution.

  Instead of having compile-time configuration and secrets, or simple system environment variables
  on application startup, this module provides infrastructure on loading configuration
  from anywhere, with the bonus support of dynamic configurations.

  # Basics
  Tell `Loader` what and where your configuration values should go. This is done in `config.exs`:

  ```elixir
  alias Ptolemy.Providers.SystemEnv
  config :ptolemy, loader: [
    env: [
      {{:app_name, :secret_key}, {SystemEnv, "PATH"}},
      # ...
    ]
  ]
  ```
  > The above configuration will result in the system environment variable `PATH` being set to
  > your application's `:secret_key` value. It can be retrieved at any time afterwards with
  > `Application.get_env(:app_name, :secret_key)`

  To start your application with the loader, simply add it as the *first process* under your
  application supervision tree.

  ```elixir
    # add to your child process list in application.ex or other top-level supervising process
    children = [
      Ptolemy.Loader,
      # ...
    ]
  ```

  This will populate your application's key/value store for
  all following processes. It is important to note that the one caveat to loading configuration
  this way is that the `Loader` will block the startup of the remainder of the supervision tree
  until initial values have been loaded into the application. This will most likely lead to
  slightly longer startup times, depending on the providers used. All updates the providers
  notify the loader of will be handled concurrently.

  # Nested Configurations

  Nested configurations are also supported by `Ptolemy.Loader`. To achieve the equivalent configuration as:
  ```elixir
  config :app_name, top_key: [
    first_nest: %{
      target_key: "hello!"
    }
  ]
  ```

  The loader configuration would be similar to:
  ```elixir
  config :app_name, top_key: [
    first_nest: %{
      target_key: "dummy_value"
    }
  ]

  alias Ptolemy.Providers.SystemEnv
  config :ptolemy, loader: [
    env: [
      {{:app_name, [:top_key, :first_nest, :target_key]}, {SystemEnv, "TARGET_VAR"}}
    ]
  ]
  ```

  The loader can only populate configuration values with no stub if the value is stored as the top level value.
  Once the first value stored in a configuration is a structure, loader will not be able to imply what structure
  the value is expected to be stored in. The dummy value is included in the stub to be explicit; but only the surrounding
  structure is required. For example, the configuration below will also work:

  ```elixir
  config :app_name, top_key: [
    first_nest: %{}
  ]
  ```

  The loader will make no assumptions on the structure of configurations. It will raise an error on initialization
  if the structure can not be updated to ensure configuration is always as intended after loader was initialized.

  # Built-In Providers
  Providers that ship with Ptolemy include:
  - `Ptolemy.Providers.SystemEnv` - Loads system environment variables

  # Performance Considerations
  The best practices implied by the purpose of `Ptolemy.Loader` is that `Application.get_env/2`
  should be called repeatedly at runtime whenever configuration dependent code is executed. This raises the question
  of performance impacts on that dependent code from constantly calling a lookup function. As explored
  in [this article](https://engineering.tripping.com/blazing-fast-elixir-configuration-475aca10011d),
  you may incur small costs on massively frequent invocations and/or large return values, however at the
  time of writing these docs, it is felt that this is an acceptable price to pay. If ever the case does arise where
  there is a performance bottleneck, support for application environment will not be replaced to preserve
  integration with third party libraries.
  """
  use GenServer

  @typedoc """
  The target configuration to be updated by a provider.

  Targets are mapped to be later retrieved from `Application.get_env/2`.
  """
  @type config_target :: {atom, atom | list(atom)}

  @typedoc """
  The specification to query a provider.
  """
  @type provider_spec :: {module, any}

  @load_callback_name :load

  @doc """
  Starts the Loader process.

  While still functioning as a typical `start_link/1` helper, this implementation also contains blocking business
  logic to ensure subsequent processes can retrieve populated application state values.
  """
  def start_link(config \\ Application.get_env(:ptolemy, :loader)) do
    case GenServer.start_link(__MODULE__, config) do
      {:ok, pid} = result ->
        GenServer.call(pid, :startup)
        result

      result ->
        result
    end
  end

  @doc """
  Initializes the process's state.

  This process is a special case where the state will already be built in the same process as the supervisor to
  intentionally delay other processes from starting when loading configuration.
  """
  @impl true
  def init(args) do
    {:ok, args}
  end

  @doc """
  Retrieves the configuration of the loader.
  """
  @spec config(pid) :: keyword
  def config(pid) do
    GenServer.call(pid, :config)
  end

  @doc """
  Invokes a provider with a query and sets the result to the mapped application environment target.
  """
  @spec load(config_target, provider_spec) :: :ok
  def load(config_target, provider_spec)

  def load({app, [env_key]}, provider_spec) when is_atom(env_key),
    do: load({app, env_key}, provider_spec)

  def load({app, env_key}, {provider, provider_arg}) when is_atom(env_key) do
    Application.put_env(
      app,
      env_key,
      apply(provider, @load_callback_name, [self(), provider_arg])
    )
  end

  def load({app, [top_key | nested_keys] = keys}, {provider, provider_arg})
      when is_list(keys) do
    case Application.get_env(app, top_key) do
      nil ->
        raise(
          "No configuration structure to update! Please provide dummy configurations for all loaded configurations."
        )

      config ->
        Application.put_env(
          app,
          top_key,
          update_in(config, nested_keys, fn _ ->
            apply(provider, @load_callback_name, [self(), provider_arg])
          end)
        )
    end
  end

  ####### impl
  @impl true
  def handle_call(:startup, _from, config) do
    started_providers =
      config
      |> Keyword.get(:env, [])
      |> Enum.reduce([], fn
        {target, {provider, _} = provider_spec}, started ->
          unless provider in started do
            apply(provider, :init, [self()])
          end

          load(target, provider_spec)
          [provider | started]
      end)
      |> Enum.uniq()

    {:reply, :ok, config |> Keyword.put(:started, started_providers)}
  end

  @impl true
  def handle_call(:config, _from, config) do
    {:reply, config, config}
  end

  @impl true
  def handle_info({:expired, {module, module_args}}, config) do
    config
    |> Keyword.get(:env)
    |> Enum.find(fn
      {_, {^module, ^module_args}} ->
        true

      _ ->
        false
    end)
    |> case do
      {target, provider} ->
        load(target, provider)

      nil ->
        # TODO: Maybe log that a token expired with no env target?
        nil
    end

    {:noreply, config}
  end
end
