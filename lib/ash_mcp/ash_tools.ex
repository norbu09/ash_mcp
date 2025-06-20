if Code.ensure_loaded?(Ash) do
  defmodule AshMcp.AshTools do
    @moduledoc """
    Tools capability implementation for Ash applications.

    This capability provides tools functionality specifically for Ash applications,
    integrating with AshAi to expose Ash actions as MCP tools.
    """

    @behaviour AshMcp.Capability

    require Logger

    @impl AshMcp.Capability
    def capability_name, do: "tools"

    @impl AshMcp.Capability
    def capability_config do
      %{
        "listChanged" => false
      }
    end

    @impl AshMcp.Capability
    def list_items(_session_id, opts) do
      tools = get_tools(opts)

      tool_list =
        Enum.map(tools, fn function ->
          %{
            "name" => function.name,
            "description" => function.description,
            "inputSchema" => function.parameters_schema
          }
        end)

      {:ok, tool_list}
    end

    @impl AshMcp.Capability
    def handle_method("tools/list", _params, session_id, opts) do
      {:ok, tools} = list_items(session_id, opts)
      {:ok, %{"tools" => tools}}
    end

    def handle_method("tools/call", params, session_id, opts) do
      tool_name = params["name"]
      tool_args = params["arguments"] || %{}

      opts =
        opts
        |> Keyword.update(
          :context,
          %{mcp_session_id: session_id},
          &Map.put(&1, :mcp_session_id, session_id)
        )
        |> Keyword.put(:filter, fn tool -> tool.mcp == :tool end)

      case find_tool(tool_name, opts) do
        nil ->
          {:error, {:tool_not_found, tool_name}}

        tool ->
          context =
            opts
            |> Keyword.take([:actor, :tenant, :context])
            |> Map.new()
            |> Map.update(
              :context,
              %{otp_app: opts[:otp_app]},
              &Map.put(&1, :otp_app, opts[:otp_app])
            )

          case tool.function.(tool_args, context) do
            {:ok, result, _} ->
              {:ok,
               %{
                 "isError" => false,
                 "content" => [%{"type" => "text", "text" => result}]
               }}

            {:error, error} ->
              Logger.warning("Tool execution failed: #{inspect(error)}")
              {:error, {:tool_execution_failed, error}}
          end
      end
    end

    def handle_method(_method, _params, _session_id, _opts) do
      :not_handled
    end

    # Private functions

    defp get_tools(opts) do
      # This base implementation returns an empty list
      # Applications should override this by providing their own tools capability
      # For example, AshAi provides AshAi.Mcp.Tools that integrates with AshAi.functions/1
      tools_function = opts[:tools_function]

      if is_function(tools_function, 1) do
        tools_function.(opts)
      else
        # Return empty list as fallback
        []
      end
    end

    defp find_tool(tool_name, opts) do
      get_tools(opts)
      |> Enum.find(&(&1.name == tool_name))
    end
  end
end
