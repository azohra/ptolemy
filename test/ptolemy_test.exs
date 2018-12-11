defmodule PtolemyTest do
  use ExUnit.Case
  doctest Ptolemy

  test "greets the world" do
    assert Ptolemy.hello() == :world
  end
end
