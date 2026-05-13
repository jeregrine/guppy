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
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Guppy.Application, []},
      extra_applications: [:logger, :xmerl]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/jeregrine/guppy",
        "Documentation" => "https://github.com/jeregrine/guppy#readme"
      },
      files: [
        "lib",
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
      ]
    ]
  end

  defp deps do
    [
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:rustler, "~> 0.37.3"},
      {:rustler_precompiled, "~> 0.9.0"},
      {:telemetry, "~> 1.3"}
    ]
  end
end
