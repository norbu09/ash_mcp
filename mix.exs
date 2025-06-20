defmodule AshMcp.MixProject do
  use Mix.Project

  @description """
  A Model Context Protocol (MCP) server implementation for Elixir applications.
  Provides a framework for building MCP servers with support for tools, resources,
  prompts, and sampling capabilities. Includes optional integration with the Ash framework.
  """

  @version "0.1.0"
  @source_url "https://github.com/norbu09/ash_mcp"

  def project do
    [
      app: :ash_mcp,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      consolidate_protocols: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      warnings_as_errors: Mix.env() == :test,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      dialyzer: [
        plt_add_apps: [:ash, :mix],
        ignore_warnings: "dialyzer.ignore-warnings"
      ],
      description: @description,
      source_url: @source_url,
      homepage_url: @source_url,
      preferred_cli_env: []
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AshMcp.Application, []}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      before_closing_head_tag: fn type ->
        if type == :html do
          """
          <script>
            if (location.hostname === "hexdocs.pm") {
              var script = document.createElement("script");
              script.src = "https://plausible.io/js/script.js";
              script.setAttribute("defer", "defer")
              script.setAttribute("data-domain", "ashhexdocs")
              document.head.appendChild(script);
            }
          </script>
          """
        end
      end,
      extras: [
        {"README.md", title: "Home"},
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        "About AshMcp": [
          "CHANGELOG.md"
        ]
      ],
      groups_for_modules: [
        AshMcp: [
          AshMcp
        ],
        Core: [
          AshMcp.Server,
          AshMcp.Session,
          AshMcp.Registry,
          AshMcp.Router
        ],
        Capabilities: [
          AshMcp.Capability,
          AshMcp.AshTools
        ]
      ]
    ]
  end

  defp elixirc_paths(:test) do
    ["test/support/", "lib/"]
  end

  defp elixirc_paths(_env) do
    ["lib/"]
  end

  defp package do
    [
      name: :ash_mcp,
      licenses: ["MIT"],
      maintainers: ["norbu09"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:plug, "~> 1.17"},
      {:jason, "~> 1.4"},

      # Optional Phoenix integration
      {:phoenix, "~> 1.7", optional: true},

      # Optional Ash integration
      {:ash, "~> 3.5", optional: true},
      {:ash_json_api, "~> 1.4", optional: true},

      # Optional authentication
      {:ash_authentication, "~> 4.8", optional: true},

      # HTTP client for OAuth
      {:req, "~> 0.4", optional: true},

      # Development and testing dependencies
      {:ex_doc, "~> 0.37-rc", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict",
      docs: [
        "docs"
      ],
      setup: ["deps.get"],
      test: ["test"]
    ]
  end
end
