defmodule Naiveical.MixProject do
  use Mix.Project

  @version "0.1.3"

  def project do
    [
      app: :naiveical,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: description(),
      name: "Naiveical",
      package: package(),
      deps: deps(),
      docs: docs(),
      source_url: "https://github.com/MigaduMail/naiveical"
    ]
  end

  def package do
    [
      maintainers: ["swerter", "Michael Bruderer"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/MigaduMail/naiveical"}
    ]
  end

  defp description() do
    "Library to create and edit iCalendar files without parsing."
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
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
      {:tzdata, "~> 1.1"},
      {:timex, "~> 3.7"},
      {:uuid, "~> 1.1"},
      {:ex_parameterized, "~> 1.3", only: :test},
      {:ex_doc, "~> 0.28.2", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end
