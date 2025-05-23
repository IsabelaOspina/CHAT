defmodule Proyecto.MixProject do
  use Mix.Project

  def project do
    [
      app: :proyecto,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Proyecto.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:phoenix_pubsub, "~> 2.1"},
    {:plug_cowboy, "~> 2.0"},
    {:jason, "~> 1.2"}] # Para trabajar con JSON
  end
end
