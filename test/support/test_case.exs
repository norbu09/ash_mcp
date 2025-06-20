defmodule AshMcp.TestCase do
  @moduledoc """
  Base test case for AshMcp tests.

  Provides common test utilities and setup for AshMcp test modules.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import AshMcp.TestCase
      alias AshMcp.TestCase

      # Common test setup
      setup do
        # Clear any test data from previous runs
        clear_test_state()
        :ok
      end
    end
  end

  @doc """
  Clear test state to ensure test isolation.
  """
  def clear_test_state do
    # Clear registry if it exists
    try do
      :ets.delete_all_objects(AshMcp.Registry.table_name())
    rescue
      _ -> :ok
    end

    # Terminate any test sessions
    try do
      AshMcp.Registry.get_all_sessions()
      |> Enum.each(fn {session_id, _} ->
        AshMcp.Session.terminate(session_id)
      end)
    rescue
      _ -> :ok
    end
  end

  @doc """
  Create a test capability for testing purposes.
  """
  def create_test_capability(name, options \\ []) do
    config = Keyword.get(options, :config, %{})
    items = Keyword.get(options, :items, [])
    methods = Keyword.get(options, :methods, %{})

    defmodule :"TestCapability#{System.unique_integer()}" do
      @behaviour AshMcp.Capability

      def capability_name, do: unquote(name)
      def capability_config, do: unquote(Macro.escape(config))
      def list_items(_session_id, _opts), do: {:ok, unquote(Macro.escape(items))}

      def handle_method(method, params, session_id, opts) do
        case unquote(Macro.escape(methods))[method] do
          nil -> :not_handled
          handler when is_function(handler, 4) -> handler.(method, params, session_id, opts)
          response -> {:ok, response}
        end
      end
    end
  end

  @doc """
  Create a test session with a unique ID.
  """
  def create_test_session(prefix \\ "test") do
    session_id = "#{prefix}-session-#{System.unique_integer()}"
    {:ok, session} = AshMcp.create_session(session_id)
    {session_id, session}
  end

  @doc """
  Build a JSON-RPC request for testing.
  """
  def build_jsonrpc_request(method, params \\ %{}, id \\ 1) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => method,
      "params" => params
    }
  end

  @doc """
  Assert that a JSON-RPC response is successful.
  """
  def assert_successful_response(response, expected_id \\ 1) do
    assert response["jsonrpc"] == "2.0"
    assert response["id"] == expected_id
    assert Map.has_key?(response, "result")
    refute Map.has_key?(response, "error")
    response["result"]
  end

  @doc """
  Assert that a JSON-RPC response is an error.
  """
  def assert_error_response(response, expected_code, expected_id \\ 1) do
    assert response["jsonrpc"] == "2.0"
    assert response["id"] == expected_id
    assert Map.has_key?(response, "error")
    assert response["error"]["code"] == expected_code
    refute Map.has_key?(response, "result")
    response["error"]
  end
end
