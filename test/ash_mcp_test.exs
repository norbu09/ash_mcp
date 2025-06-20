defmodule AshMcpTest do
  use ExUnit.Case, async: true
  doctest AshMcp

  describe "capability registration" do
    test "can register and retrieve capabilities" do
      # Clear any existing test capabilities
      :ets.delete_all_objects(AshMcp.Registry.table_name())

      # Register a test capability
      defmodule TestCapability do
        @behaviour AshMcp.Capability

        def capability_name, do: "test"
        def capability_config, do: %{}
        def list_items(_session_id, _opts), do: {:ok, []}
        def handle_method(_method, _params, _session_id, _opts), do: :not_handled
      end

      assert :ok = AshMcp.register_capability(:test, TestCapability)

      capabilities = AshMcp.get_capabilities()
      assert is_list(capabilities)
      # Check that our test capability is in the list
      assert Enum.any?(capabilities, fn {name, module, _opts} ->
               name == :test and module == TestCapability
             end)
    end

    test "build_capabilities_config returns proper format" do
      # Clear any existing test capabilities
      :ets.delete_all_objects(AshMcp.Registry.table_name())

      # Register a test capability
      defmodule TestCapability2 do
        @behaviour AshMcp.Capability

        def capability_name, do: "test2"
        def capability_config, do: %{"listChanged" => false}
        def list_items(_session_id, _opts), do: {:ok, []}
        def handle_method(_method, _params, _session_id, _opts), do: :not_handled
      end

      AshMcp.register_capability(:test2, TestCapability2)

      config = AshMcp.build_capabilities_config("test-session")
      assert is_map(config)
      assert Map.has_key?(config, "test2")
      assert config["test2"] == %{"listChanged" => false}
    end
  end

  describe "session management" do
    test "can create and retrieve sessions" do
      session_id = "test-session-#{System.unique_integer()}"

      assert {:ok, session} = AshMcp.create_session(session_id)
      assert session.id == session_id
      assert is_struct(session, AshMcp.Session)

      assert {:ok, retrieved_session} = AshMcp.get_session(session_id)
      assert retrieved_session.id == session_id
    end

    test "can terminate sessions" do
      session_id = "test-session-#{System.unique_integer()}"

      {:ok, _session} = AshMcp.create_session(session_id)
      assert :ok = AshMcp.terminate_session(session_id)

      assert {:error, :not_found} = AshMcp.get_session(session_id)
    end

    test "cannot create duplicate sessions" do
      session_id = "test-session-#{System.unique_integer()}"

      {:ok, _session} = AshMcp.create_session(session_id)
      assert {:error, :already_exists} = AshMcp.create_session(session_id)

      # Clean up
      AshMcp.terminate_session(session_id)
    end
  end
end
