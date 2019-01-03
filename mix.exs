defmodule Ptolemy.MixProject do
  use Mix.Project

  def project do
    [
      app: :ptolemy,
      version: "0.1.0-rc",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.2.1"},
      {:joken, "~> 1.5"},
      {:hackney, "~> 1.6"},
      {:jason, ">= 1.0.0"},
      {:poison, "~> 3.1"}
    ]
  end
end
