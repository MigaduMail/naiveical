defmodule NaiveicalTest do
  use ExUnit.Case
  doctest Naiveical

  test "greets the world" do
    assert Naiveical.hello() == :world
  end
end
