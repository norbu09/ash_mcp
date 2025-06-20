defmodule AshMcpTest do
  use ExUnit.Case
  doctest AshMcp

  test "greets the world" do
    assert AshMcp.hello() == :world
  end
end
