defmodule Guppy.MixProject do
  use Mix.Project

  def project do
    [
      app: :guppy,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: "Elixir-owned native desktop UI rendering through GPUI.",
      package: package(),
      deps: deps(),
      aliases: aliases(),
      dialyzer: [ignore_warnings: ".dialyzer_ignore.exs"]
    ]
  end

  def application do
    [
      mod: {Guppy.Application, []},
      extra_applications: [:logger, :xmerl]
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/jeregrine/guppy",
        "Documentation" => "https://github.com/jeregrine/guppy#readme"
      },
      files:
        [
          "lib",
          "data",
          "mix.exs",
          "README.md",
          "LICENSE",
          "CHANGELOG.md",
          "docs/distribution.md",
          "docs/gpui-compliance.md",
          "docs/performance.md",
          "native/guppy_nif/src",
          "native/guppy_nif/Cargo.toml",
          "native/guppy_nif/Cargo.lock",
          "native/guppy_nif/build.rs"
        ] ++ Path.wildcard("checksum-*.exs")
    ]
  end

  defp deps do
    [
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:vibe_kit, "~> 0.1"},
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:rustler, "~> 0.38.0"},
      {:rustler_precompiled, "~> 0.9.0"},
      {:telemetry, "~> 1.3"}
    ]
  end

  defp aliases() do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer",
        "ex_dna lib examples --max-clones 0",
        "reach.check --arch --smells",
        &reach_examples/1
      ]
    ]
  end

  defp reach_examples(_args) do
    Mix.Task.reenable("reach.check")
    Mix.Task.run("reach.check", ["--smells", "examples/**/*.exs"])
  end
end
