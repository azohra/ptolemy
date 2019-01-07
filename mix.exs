defmodule Ptolemy.MixProject do
  use Mix.Project

  def project do
    [
      app: :ptolemy,
      version: "0.1.0-alpha",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Ptolemy",
      source_url: "https://github.com/azohra/ptolemy",
      docs: [
        main: "Ptolemy", # The main page in the docs
        logo: "path/to/logo.png",
        extras: ["README.md"]
      ]
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
      {:jason, ">= 1.0.0"}
    ]
  end

  defp description() do
    "Vault + Elixir"
  end


  defp package() do
    [
      name: "ptolemy",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/azohra/ptolemy"}
    ]
  end
end
