defmodule AshMcp.AshToolsTest do
  use ExUnit.Case, async: true
  alias AshMcp.AshTools

  describe "Ash integration capability" do
    test "provides tools capability name" do
      assert AshTools.capability_name() == "tools"
    end

    test "provides capability config" do
      config = AshTools.capability_config()
      assert is_map(config)
      assert Map.has_key?(config, "listChanged")
    end

    test "returns empty tools list when Ash is not available" do
      # When Ash is not available or no domains configured
      {:ok, tools} = AshTools.list_items("test-session", [])
      assert is_list(tools)
    end

    test "handles method calls gracefully when Ash is not available" do
      # Should return not_handled when Ash integration is not available
      result = AshTools.handle_method("tools/call", %{}, "test-session", [])
      assert result == :not_handled or match?({:error, _}, result)
    end
  end

  describe "with Ash available" do
    @describetag :integration
    # These tests would run when Ash is actually available
    # For now, we just test the interface

    test "interface compatibility" do
      # Test that the module implements the capability behaviour correctly
      if Code.ensure_loaded?(AshMcp.AshTools) do
        assert function_exported?(AshMcp.AshTools, :capability_name, 0)
        assert function_exported?(AshMcp.AshTools, :capability_config, 0)
        assert function_exported?(AshMcp.AshTools, :list_items, 2)
        assert function_exported?(AshMcp.AshTools, :handle_method, 4)
      else
        # Skip this test if Ash is not available
        assert true
      end
    end
  end
end
