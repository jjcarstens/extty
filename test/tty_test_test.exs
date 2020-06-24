defmodule TtyTestTest do
  use ExUnit.Case
  doctest TtyTest

  test "greets the world" do
    assert TtyTest.hello() == :world
  end
end
