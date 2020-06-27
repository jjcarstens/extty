defmodule ExTTYTest do
  use ExUnit.Case
  doctest ExTTY

  test "greets the world" do
    assert ExTTY.hello() == :world
  end
end
