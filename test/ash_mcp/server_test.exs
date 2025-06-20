defmodule AshMcp.ServerTest do
  use ExUnit.Case, async: true
  alias AshMcp.Server

  describe "MCP protocol handling" do
    test "handles initialize request" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "2025-03-26",
          "capabilities" => %{},
          "clientInfo" => %{
            "name" => "test-client",
            "version" => "1.0.0"
          }
        }
      }

      capabilities = []
      session_id = "test-session"

      response = Server.handle_request(request, capabilities, session_id, [])

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert Map.has_key?(response, "result")
      assert response["result"]["protocolVersion"] == "2025-03-26"
      assert Map.has_key?(response["result"], "capabilities")
      assert Map.has_key?(response["result"], "serverInfo")
    end

    test "handles invalid JSON-RPC request" do
      request = %{
        "invalid" => "request"
      }

      response = Server.handle_request(request, [], "test-session", [])

      assert response["jsonrpc"] == "2.0"
      assert Map.has_key?(response, "error")
      assert response["error"]["code"] == -32_600
    end

    test "handles method not found" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "unknown/method",
        "params" => %{}
      }

      response = Server.handle_request(request, [], "test-session", [])

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert Map.has_key?(response, "error")
      assert response["error"]["code"] == -32_601
    end

    test "handles ping request" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "ping",
        "params" => %{}
      }

      response = Server.handle_request(request, [], "test-session", [])

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert response["result"] == %{}
    end
  end

  describe "capability delegation" do
    defmodule TestCapability do
      @behaviour AshMcp.Capability

      def capability_name, do: "test"
      def capability_config, do: %{"listChanged" => false}

      def list_items(_session_id, _opts) do
        {:ok, [%{"name" => "test_item", "description" => "A test item"}]}
      end

      def handle_method("test/call", %{"name" => "test_item"}, _session_id, _opts) do
        {:ok, %{"result" => "success"}}
      end

      def handle_method(_method, _params, _session_id, _opts) do
        :not_handled
      end
    end

    test "delegates to capability for list requests" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "test/list",
        "params" => %{}
      }

      capabilities = [TestCapability]
      session_id = "test-session"

      response = Server.handle_request(request, capabilities, session_id, [])

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert Map.has_key?(response, "result")
      assert is_list(response["result"]["test"])
      assert length(response["result"]["test"]) == 1
    end

    test "delegates method calls to capabilities" do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "test/call",
        "params" => %{"name" => "test_item"}
      }

      capabilities = [TestCapability]
      session_id = "test-session"

      response = Server.handle_request(request, capabilities, session_id, [])

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert Map.has_key?(response, "result")
      assert response["result"]["result"] == "success"
    end
  end
end
