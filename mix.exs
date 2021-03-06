defmodule Cassandra.Mixfile do
  use Mix.Project

  def project, do: [
    app: :cassandra,
    version: version(),
    name: "Cassandra",
    elixir: "~> 1.3",
    build_embedded: Mix.env == :prod,
    start_permanent: Mix.env == :prod,
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      "coveralls": :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
    ],
    source_url: "https://github.com/cafebazaar/elixir-cassandra",
    description: "A pure Elixir driver for Apache Cassandra",
    package: package(),
    docs: docs(),
    deps: deps(),
  ]

  def application, do: [
    applications: [:logger],
  ]

  defp deps, do: [
    {:connection, "~> 1.0"},
    {:uuid, "~> 1.1"},
    {:poolboy, "~> 1.5"},
    {:excheck, "~> 0.5", only: :test},
    {:triq, github: "triqng/triq", only: :test},
    {:excoveralls, "~> 0.5", only: :test},
    {:ex_doc, "~> 0.14", only: :dev},
  ]

  defp version, do: "1.0.0-beta.2"

  defp docs, do: [
    main: "readme",
    extras: ["README.md"],
  ]

  defp package, do: [
    licenses: ["Apache 2.0"],
    maintainers: ["Ali Rajabi", "Hassan Zamani"],
    links: %{
      "Github" => "https://github.com/cafebazaar/elixir-cassandra",
      "Docs" => "https://hexdocs.pm/cassandra/#{version()}/",
    },
    files: ~w(mix.exs lib README.md LICENSE.md),
  ]
end
