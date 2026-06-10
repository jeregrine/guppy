defmodule Guppy.MixProject do
  use Mix.Project

  def project do
    [
      app: :guppy,
      version: "0.2.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      description: "Elixir-owned native desktop UI rendering through GPUI.",
      source_url: "https://github.com/jeregrine/guppy",
      homepage_url: "https://github.com/jeregrine/guppy",
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
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

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "docs/gpui-compliance.md",
        "docs/distribution.md",
        "docs/overlays.md",
        "docs/focus-keyboard.md",
        "docs/accessibility.md",
        "docs/theme.md"
      ],
      groups_for_modules: [
        "Core API": [Guppy, Guppy.Server, Guppy.IR, Guppy.Style],
        Authoring: [Guppy.Window, Guppy.Component, Guppy.Markdown, Guppy.ContextMenu],
        Apps: ~r/^Guppy\.App/,
        "Native bridge": [Guppy.Native, Guppy.Native.Nif]
      ]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
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
