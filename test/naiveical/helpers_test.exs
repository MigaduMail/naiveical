defmodule Naiveical.HelpersTest do
  use ExUnit.Case

  describe "parse_datetime" do
    test "UTC date string" do
      datetime_str = "20200506T141742Z"

      actual = Naiveical.Helpers.parse_datetime(datetime_str)

      expected = {:ok, DateTime.new!(~D[2020-05-06], ~T[14:17:42], "Etc/UTC")}
      assert expected == actual
    end

    test "simple date string" do
      datetime_str = "20200514T100000"

      actual = Naiveical.Helpers.parse_datetime(datetime_str, "Europe/Zurich")

      expected = {:ok, DateTime.new!(~D[2020-05-14], ~T[10:00:00], "Europe/Zurich")}
      assert expected == actual
    end
  end
end
