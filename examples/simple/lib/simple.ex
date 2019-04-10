defmodule Simple.App do
  @moduledoc """
  Simple is a demo application for Ptolemy. It uses the dynamic loader of Ptolemy
  to load secrets into Application environment. More details can be found in `README.md`
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Ptolemy.Loader, [])
    ]

    opts = [name: __MODULE__, strategy: :one_for_all, restart: :permanent]
    Supervisor.start_link(children, opts)
  end
end