defmodule SmartOracle.MixProject do
  use Mix.Project

  def project do
    [
      app: :smart_oracle,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SmartOracle.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:aepp_sdk_elixir, github: "aeternity/aepp-sdk-elixir", tag: "v0.2.0"}
    ]
  end
end
