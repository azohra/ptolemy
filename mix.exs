defmodule Ptolemy.MixProject do
  use Mix.Project

  def project do
    [
      app: :ptolemy,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      name: "Ptolemy",
      source_url: "https://github.com/azohra/ptolemy",
      docs: [
        # The main page in the docs
        main: "README.md",
        logo: "assets/logo.svg",
        extras: [
          "docs/v0-2_redesign.md",
          "README.md": [filename: "README.md", title: "Ptolemy"]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description() do
    "Vault + Elixir"
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.2.1"},
      {:joken, "~> 1.5"},
      {:hackney, "~> 1.6"},
      {:jason, ">= 1.0.0"},
      {:poison, "~> 3.1"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      name: "ptolemy",
      licenses: ["MIT"],
      maintainers: ["Brandon Sam Soon", "Frank Vumbaca", "Kevin Hu"],
      links: %{"GitHub" => "https://github.com/azohra/ptolemy"}
    ]
  end
end
