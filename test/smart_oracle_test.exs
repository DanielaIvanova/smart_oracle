defmodule SmartOracleTest do
  use ExUnit.Case
  doctest SmartOracle

  test "greets the world" do
    assert SmartOracle.hello() == :world
  end
end
