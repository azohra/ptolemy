defmodule Simple.MixProject do
  use Mix.Project

  def project do
    [
      app: :simple,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Simple.App, []},
      extra_applications: [:logger]
    ]
  end

  # The example project currently depends on Ptolemy V0.2
  defp deps do
    [
      {:ptolemy, git: "git://github.com/azohra/ptolemy.git", branch: "v0.2"},
    ]
  end
end
