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

    test "windows timezone alias is resolved" do
      datetime_str = "20250101T120000"

      actual = Naiveical.Helpers.parse_datetime(datetime_str, "W. Europe Standard Time")

      assert {:ok, %DateTime{} = dt} = actual
      assert dt.time_zone == "Europe/Berlin"
      assert dt.year == 2025
      assert dt.hour == 12
    end

    test "returns error for unknown timezone" do
      result = Naiveical.Helpers.parse_datetime("20250101T120000", "Mars/Phobos")

      assert result == {:error, {:unknown_timezone, "Mars/Phobos"}}
    end
  end

  describe "parse_icalendar_datetime/1" do
    test "parses UTC datetime with Z suffix" do
      datetime_str = "20250101T120000Z"

      actual = Naiveical.Helpers.parse_icalendar_datetime(datetime_str)

      expected = {:ok, DateTime.new!(~D[2025-01-01], ~T[12:00:00], "Etc/UTC")}
      assert expected == actual
    end

    test "parses local datetime without Z suffix (treated as UTC)" do
      datetime_str = "20250101T120000"

      actual = Naiveical.Helpers.parse_icalendar_datetime(datetime_str)

      expected = {:ok, DateTime.new!(~D[2025-01-01], ~T[12:00:00], "Etc/UTC")}
      assert expected == actual
    end

    test "parses date only format (treated as midnight UTC)" do
      datetime_str = "20250101"

      actual = Naiveical.Helpers.parse_icalendar_datetime(datetime_str)

      expected = {:ok, DateTime.new!(~D[2025-01-01], ~T[00:00:00], "Etc/UTC")}
      assert expected == actual
    end

    test "returns error for nil value" do
      actual = Naiveical.Helpers.parse_icalendar_datetime(nil)

      assert {:error, :nil_value} == actual
    end

    test "returns error for empty string" do
      actual = Naiveical.Helpers.parse_icalendar_datetime("")

      assert {:error, :empty_string} == actual
    end

    test "returns error for invalid format" do
      actual = Naiveical.Helpers.parse_icalendar_datetime("not-a-date")

      assert {:error, :invalid_format} == actual
    end

    test "returns error for invalid date values" do
      # Invalid month (13)
      actual = Naiveical.Helpers.parse_icalendar_datetime("20251301T120000Z")

      assert {:error, _} = actual
    end
  end

  describe "parse_icalendar_datetime!/1" do
    test "parses valid datetime and returns DateTime" do
      datetime_str = "20250101T120000Z"

      actual = Naiveical.Helpers.parse_icalendar_datetime!(datetime_str)

      expected = DateTime.new!(~D[2025-01-01], ~T[12:00:00], "Etc/UTC")
      assert expected == actual
    end

    test "raises ArgumentError for invalid format" do
      assert_raise ArgumentError, fn ->
        Naiveical.Helpers.parse_icalendar_datetime!("invalid")
      end
    end
  end

  describe "format_icalendar_datetime/1" do
    test "formats DateTime to iCalendar format" do
      dt = DateTime.new!(~D[2025-01-01], ~T[12:30:45], "Etc/UTC")

      actual = Naiveical.Helpers.format_icalendar_datetime(dt)

      expected = "20250101T123045Z"
      assert expected == actual
    end

    test "formats NaiveDateTime to iCalendar format" do
      ndt = ~N[2025-01-01 12:30:45]

      actual = Naiveical.Helpers.format_icalendar_datetime(ndt)

      expected = "20250101T123045Z"
      assert expected == actual
    end

    test "truncates microseconds" do
      dt = DateTime.new!(~D[2025-01-01], ~T[12:30:45.123456], "Etc/UTC")

      actual = Naiveical.Helpers.format_icalendar_datetime(dt)

      expected = "20250101T123045Z"
      assert expected == actual
    end
  end

  describe "parse_icalendar_date/1" do
    test "parses date in YYYYMMDD format" do
      date_str = "20250101"

      actual = Naiveical.Helpers.parse_icalendar_date(date_str)

      expected = {:ok, ~D[2025-01-01]}
      assert expected == actual
    end

    test "returns error for nil value" do
      actual = Naiveical.Helpers.parse_icalendar_date(nil)

      assert {:error, :nil_value} == actual
    end

    test "returns error for empty string" do
      actual = Naiveical.Helpers.parse_icalendar_date("")

      assert {:error, :empty_string} == actual
    end

    test "returns error for invalid format" do
      actual = Naiveical.Helpers.parse_icalendar_date("not-a-date")

      assert {:error, :invalid_format} == actual
    end

    test "returns error for invalid date values" do
      # Invalid day (32)
      actual = Naiveical.Helpers.parse_icalendar_date("20250132")

      assert {:error, _} = actual
    end
  end

  describe "parse_icalendar_date!/1" do
    test "parses valid date and returns Date" do
      date_str = "20250101"

      actual = Naiveical.Helpers.parse_icalendar_date!(date_str)

      expected = ~D[2025-01-01]
      assert expected == actual
    end

    test "raises ArgumentError for invalid format" do
      assert_raise ArgumentError, fn ->
        Naiveical.Helpers.parse_icalendar_date!("invalid")
      end
    end
  end

  describe "format_icalendar_date/1" do
    test "formats Date to iCalendar format" do
      date = ~D[2025-01-01]

      actual = Naiveical.Helpers.format_icalendar_date(date)

      expected = "20250101"
      assert expected == actual
    end

    test "formats single digit month and day with leading zeros" do
      date = ~D[2025-03-05]

      actual = Naiveical.Helpers.format_icalendar_date(date)

      expected = "20250305"
      assert expected == actual
    end
  end
end
