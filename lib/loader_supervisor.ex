defmodule Ptolemy.LoaderSupervisor do
    @moduledoc """
  `Ptolemy.LoaderSupervisor` is used as a client applications entrypoint to `Ptolemy.Loader`.
  It is responsible for starting the `Loader` and the `Cache`.

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

  To start your application with the LoaderSupervisor, simply add the `LoaderSupervisor` as the *first process* under your
  application supervision tree.

  ```elixir
    # add to your child supervisor list in application.ex or other top-level supervising process
    children = [
      Ptolemy.LoaderSupervisor,
      # ...
    ]
  ```

  This will populate your application's key/value store for
  all following processes. It is important to note that the one caveat to loading configuration
  this way is that the `Loader` will block the startup of the remainder of the supervision tree
  until initial values have been loaded into the application. This will most likely lead to
  slightly longer startup times, depending on the providers used. All updates the providers
  notify the loader of will be handled concurrently.

  See documentation for `Ptolemy.Loader` for examples on usage and configuration.
  """

  use Supervisor

  def start_link(config \\ Application.get_env(:ptolemy, :loader)) do
    Supervisor.start_link(__MODULE__, config)
  end

  @impl true
  def init(config) do
    children = [
      Ptolemy.Cache.CacheServer,
      {Ptolemy.Loader, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
