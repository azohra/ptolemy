defmodule Ptolemy.MixProject do
  use Mix.Project

  def project do
    [
      app: :ptolemy,
      version: "1.0.0",
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
          "README.md": [filename: "README.md", title: "Ptolemy"]
        ]
      ],
      elixirc_paths: elixirc_paths(Mix.env),
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
      {:tesla, "~> 1.3.1"},
      {:joken, "~> 1.5"},
      {:hackney, "~> 1.6"},
      {:jason, ">= 1.0.0"},
      {:poison, "~> 3.1"},
      {:mox, "~> 0.5.1"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Application Environment Manager, with support for Hashicorp's Vault and much more!"
  end

  defp package() do
    [
      name: "ptolemy",
      licenses: ["MIT"],
      maintainers: ["Brandon Sam Soon", "Frank Vumbaca", "Kevin Hu"],
      links: %{"GitHub" => "https://github.com/azohra/ptolemy"}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_),     do: ["lib"]
end
