defmodule Guppy.MixProject do
  use Mix.Project

  def project do
    [
      app: :guppy,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Guppy.Application, []},
      extra_applications: [:logger, :xmerl]
    ]
  end

  defp deps do
    [
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:rustler, "~> 0.37.3"},
      {:telemetry, "~> 1.3"}
    ]
  end
end
