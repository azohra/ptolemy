defmodule Ptolemy.LoaderSupervisor do
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
