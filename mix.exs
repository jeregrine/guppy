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
    []
  end
end
