defmodule ExTTY.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jjcarstens/extty"

  def project do
    [
      app: :extty,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      package: package(),
      preferred_cli_env: %{
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.22", only: :docs}
    ]
  end

  defp description() do
    "Terminal shell emulation as a process"
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp package() do
    [
      files: ["src", "lib", "mix.exs", "README.md", "LICENSE"],
      licenses: ["Apache-2.0"],
      links: %{
        "Github" => @source_url
      }
    ]
  end
end
