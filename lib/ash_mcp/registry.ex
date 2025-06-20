defmodule AshMcp.Registry do
  @moduledoc """
  Registry for MCP capabilities.

  This module manages the registration and discovery of MCP capabilities
  such as tools, resources, and prompts. It uses ETS for fast lookups
  and supports dynamic capability registration.
  """

  use GenServer
  require Logger

  @table_name :ash_mcp_capabilities
  @timeout 5_000

  @doc """
  Returns the ETS table name for testing purposes.
  """
  def table_name, do: @table_name

  @doc """
  Starts the registry process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a capability module.
  """
  def register_capability(name, module, opts \\ []) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :capability_name, 0) do
      GenServer.call(__MODULE__, {:register, name, module, opts}, @timeout)
    else
      {:error, {:invalid_capability_module, module}}
    end
  end

  @doc """
  Unregisters a capability.
  """
  def unregister_capability(name) do
    GenServer.call(__MODULE__, {:unregister, name}, @timeout)
  end

  @doc """
  Lists all registered capabilities.
  """
  def list_capabilities do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {name, module, opts} -> {name, module, opts} end)
  end

  @doc """
  Gets capability information by name.
  """
  def get_capability(name) do
    case :ets.lookup(@table_name, name) do
      [{^name, module, opts}] -> {:ok, {module, opts}}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Builds the capabilities configuration for MCP initialize response.
  """
  def build_capabilities_config(_session_id, opts \\ []) do
    capabilities = opts[:capabilities] || list_capabilities()

    capabilities
    |> Enum.reduce(%{}, fn
      {_name, module, _capability_opts}, acc ->
        build_capability_config(module, acc)

      module, acc when is_atom(module) ->
        build_capability_config(module, acc)
    end)
  end

  @doc """
  Handles a method call by dispatching to the appropriate capability.
  """
  def handle_method(method, params, session_id, opts \\ []) do
    capability_name = extract_capability_from_method(method)
    capabilities = opts[:capabilities] || list_capabilities()

    # Handle list methods specially
    if String.ends_with?(method, "/list") do
      handle_list_method(capability_name, params, session_id, capabilities, opts)
    else
      capabilities
      |> Enum.find(fn
        {_name, module, _opts} ->
          try do
            module.capability_name() == capability_name
          rescue
            _ -> false
          end

        module when is_atom(module) ->
          try do
            module.capability_name() == capability_name
          rescue
            _ -> false
          end
      end)
      |> case do
        {_name, module, capability_opts} ->
          merged_opts = Keyword.merge(capability_opts, opts)
          handle_capability_method(module, method, params, session_id, merged_opts)

        module when is_atom(module) ->
          handle_capability_method(module, method, params, session_id, opts)

        nil ->
          :not_handled
      end
    end
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    :ets.new(@table_name, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:register, name, module, opts}, _from, state) do
    # Validate that the module implements the capability behavior
    if function_exported?(module, :capability_name, 0) do
      :ets.insert(@table_name, {name, module, opts})
      Logger.debug("Registered MCP capability: #{name} -> #{inspect(module)}")
      {:reply, :ok, state}
    else
      {:reply, {:error, {:invalid_capability_module, module}}, state}
    end
  rescue
    error ->
      {:reply, {:error, error}, state}
  end

  @impl GenServer
  def handle_call({:unregister, name}, _from, state) do
    :ets.delete(@table_name, name)
    Logger.debug("Unregistered MCP capability: #{name}")
    {:reply, :ok, state}
  end

  # Private functions

  defp build_capability_config(module, acc) do
    capability_name = module.capability_name()
    capability_config = module.capability_config()
    Map.put(acc, capability_name, capability_config)
  rescue
    error ->
      Logger.warning("Failed to get capability config for #{inspect(module)}: #{inspect(error)}")

      acc
  end

  defp handle_list_method(capability_name, _params, session_id, capabilities, opts) do
    # Find the capability and get its list items
    capabilities
    |> Enum.find(fn
      {_name, module, _opts} ->
        try do
          module.capability_name() == capability_name
        rescue
          _ -> false
        end

      module when is_atom(module) ->
        try do
          module.capability_name() == capability_name
        rescue
          _ -> false
        end
    end)
    |> case do
      {_name, module, capability_opts} ->
        merged_opts = Keyword.merge(capability_opts, opts)
        {:ok, items} = module.list_items(session_id, merged_opts)
        {:ok, %{capability_name => items}}

      module when is_atom(module) ->
        {:ok, items} = module.list_items(session_id, opts)
        {:ok, %{capability_name => items}}

      nil ->
        :not_handled
    end
  end

  defp handle_capability_method(module, method, params, session_id, opts) do
    if function_exported?(module, :handle_method, 4) do
      module.handle_method(method, params, session_id, opts)
    else
      :not_handled
    end
  end

  defp extract_capability_from_method(method) do
    case String.split(method, "/", parts: 2) do
      [capability, _] -> capability
      [method] -> method
    end
  end
end
