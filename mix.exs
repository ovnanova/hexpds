defmodule Hipdster.MixProject do
  use Mix.Project

  def project do
    [
      app: :hipdster,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Hipdster.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:httpoison, "~> 2.2.1"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.28.0", only: :dev, runtime: false},
      {:multibase, "~> 0.0.1"},
      {:ex_multihash, "~> 2.0.0"},
      {:rustler, "~> 0.32"},
      {:toml, "~> 0.7.0"},
      {:varint, "~> 1.4"},
      {:plug, "~> 1.15.3"},
      {:bandit, "~> 1.3.0"},
      {:argon2_elixir, "~> 4.0"},
      {:memento, "~> 0.3.2"},
      {:infer, "~> 0.2.5"},
      {:ecto, "~> 3.11.2"},
      {:ecto_sqlite3, "~> 0.15"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    ]
  end
end
