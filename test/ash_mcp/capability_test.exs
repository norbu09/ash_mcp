defmodule AshMcp.CapabilityTest do
  use ExUnit.Case, async: true

  describe "capability behaviour" do
    defmodule TestCapability do
      @behaviour AshMcp.Capability

      def capability_name, do: "test"

      def capability_config do
        %{"listChanged" => false, "supportsSubscription" => true}
      end

      def list_items(_session_id, _opts) do
        {:ok,
         [
           %{
             "name" => "test_tool",
             "description" => "A test tool",
             "inputSchema" => %{
               "type" => "object",
               "properties" => %{
                 "message" => %{"type" => "string"}
               }
             }
           }
         ]}
      end

      def handle_method(
            "test/call",
            %{"name" => "test_tool", "arguments" => args},
            _session_id,
            _opts
          ) do
        case args do
          %{"message" => message} ->
            {:ok,
             %{
               "isError" => false,
               "content" => [%{"type" => "text", "text" => "Echo: #{message}"}]
             }}

          _ ->
            {:error, %{"code" => -32_602, "message" => "Invalid arguments"}}
        end
      end

      def handle_method("test/subscribe", _params, _session_id, _opts) do
        {:ok, %{"subscriptionId" => "test-subscription-#{System.unique_integer()}"}}
      end

      def handle_method(_method, _params, _session_id, _opts) do
        :not_handled
      end
    end

    test "implements all required callbacks" do
      assert TestCapability.capability_name() == "test"
      assert is_map(TestCapability.capability_config())
      assert {:ok, items} = TestCapability.list_items("session", [])
      assert is_list(items)
      assert length(items) == 1
    end

    test "handles method calls" do
      params = %{
        "name" => "test_tool",
        "arguments" => %{"message" => "hello world"}
      }

      assert {:ok, result} = TestCapability.handle_method("test/call", params, "session", [])
      assert result["isError"] == false
      assert [%{"type" => "text", "text" => "Echo: hello world"}] = result["content"]
    end

    test "handles subscription methods" do
      assert {:ok, result} = TestCapability.handle_method("test/subscribe", %{}, "session", [])
      assert Map.has_key?(result, "subscriptionId")
      assert String.starts_with?(result["subscriptionId"], "test-subscription-")
    end

    test "returns not_handled for unknown methods" do
      assert :not_handled = TestCapability.handle_method("unknown/method", %{}, "session", [])
    end

    test "handles invalid arguments gracefully" do
      params = %{
        "name" => "test_tool",
        "arguments" => %{"wrong_field" => "value"}
      }

      assert {:error, error} = TestCapability.handle_method("test/call", params, "session", [])
      assert error["code"] == -32_602
      assert error["message"] == "Invalid arguments"
    end
  end

  describe "capability configuration" do
    defmodule MinimalCapability do
      @behaviour AshMcp.Capability

      def capability_name, do: "minimal"
      def capability_config, do: %{}
      def list_items(_session_id, _opts), do: {:ok, []}
      def handle_method(_method, _params, _session_id, _opts), do: :not_handled
    end

    test "minimal implementation works" do
      assert MinimalCapability.capability_name() == "minimal"
      assert MinimalCapability.capability_config() == %{}
      assert {:ok, []} = MinimalCapability.list_items("session", [])
      assert :not_handled = MinimalCapability.handle_method("any", %{}, "session", [])
    end
  end
end
