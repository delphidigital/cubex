defmodule Cubex.MixProject do
  use Mix.Project

  def project do
    [
      app: :cubex,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Cube client for Elixir",
      package: package(),
      preferred_cli_env: [
        "test.watch": :test
      ],
      test_coverage: [
        summary: [
          threshold: 85
        ]
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Bob Stockdale"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/delphidigital/cubex"},
      files: ~w(.formatter.exs README.md lib mix.exs mix.lock test)
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
      {:jason, "~> 1.4"},
      {:tesla, "~> 1.4"},
      {:joken, "~> 2.5"},
      {:uuid, "~> 1.1"},
      {:mix_test_watch, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end
end
