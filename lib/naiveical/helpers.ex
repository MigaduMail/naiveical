defmodule Naiveical.Helpers do
  @moduledoc """
  Some helper functions.
  """

  @doc """
  Splits a long line into several lines starting with a space.
  """
  def unfold(ical_text) do
    ical_text
    |> String.replace(~r/\r?\n[ \t]/, "")
  end

  @doc """
  https://www.rfc-editor.org/rfc/rfc5545#section-3.1:

   Lines of text SHOULD NOT be longer than 75 octets, excluding the line
   break.  Long content lines SHOULD be split into a multiple line
   representations using a line "folding" technique.  That is, a long
   line can be split between any two characters by inserting a CRLF
   immediately followed by a single linear white-space character (i.e.,
   SPACE or HTAB).  Any sequence of CRLF followed immediately by a
   single linear white-space character is ignored (i.e., removed) when
   processing the content type.

  The fold function splits a string across graphemes if the byte-size of the substring will
  exceed the max_size. It then adds a CRLF and an empty space at the split-point.
  """
  def fold(line, max_size \\ 75) do
    # current_element = List.last(list)
    # if byte_size(current_element + char) > max_size do

    # end
    # String.split("abc", "", parts: 2)
    line
    |> String.split("")
    |> Enum.reduce([""], fn char, acc ->
      [current_element | rest] = acc

      if byte_size(current_element <> char) > max_size do
        [" " <> char] ++ [current_element <> "\r\n"] ++ rest
      else
        [current_element <> char | rest]
      end
    end)
    |> Enum.reverse()
    |> Enum.join()
  end

  @doc """
  Parse a timedate text into DateTime.
  """
  def parse_datetime(datetime_str) do
    datetime_format_str = "{YYYY}{0M}{0D}T{h24}{m}{s}Z"
    naive_datetime_format_str = "{YYYY}{0M}{0D}T{h24}{m}{s}"

    case Timex.parse(datetime_str, datetime_format_str) do
      {:ok, datetime} ->
        {:ok, DateTime.from_naive!(datetime, "Etc/UTC")}

      _ ->
        case Timex.parse(datetime_str, naive_datetime_format_str) do
          {:ok, datetime} ->
            {:ok, datetime}

          _ ->
            {:error, "could not parse #{datetime_str}"}
        end
    end
  end

  def parse_datetime!(datetime_str) do
    case parse_datetime(datetime_str) do
      {:ok, datetime} -> datetime
      {:error, error} -> raise ArgumentError, error
    end
  end

  def parse_datetime(datetime_str, timezone) do
    # check if we find the timezone, or if we can map it
    if is_nil(timezone) or String.length(timezone) == 0 do
      parse_datetime(datetime_str)
    else
      datetime_format_str = "{YYYY}{0M}{0D}T{h24}{m}{s}"
      # try out parsing of windows timezone
      if Tzdata.zone_exists?(timezone) do
        case Timex.parse(datetime_str, datetime_format_str) do
          {:ok, datetime} -> DateTime.from_naive(datetime, timezone)
        end
      else
        windows_tzs = Naiveical.WindowsIanaConvert.get_iana(timezone)
        tz = List.first(windows_tzs)

        if Tzdata.zone_exists?(tz) do
          case Timex.parse(datetime_str, datetime_format_str) do
            {:ok, datetime} -> DateTime.from_naive(datetime, tz)
          end
        else
          {:error, "No such timezone: #{timezone}"}
        end
      end
    end
  end

  def parse_datetime!(datetime_str, timezone) do
    IO.inspect(datetime_str: datetime_str)
    IO.inspect(timezone: timezone)

    case parse_datetime(datetime_str, timezone) do
      {:ok, datetime} -> datetime
      {:error, error} -> raise ArgumentError, error
    end
  end

  @doc """
  Parse a timedate text into DateTime.
  """
  def parse_date!(date_str) do
    date_format_str = "{YYYY}{0M}{0D}"

    Timex.parse!(date_str, date_format_str)
  end

  def parse_date(date_str) do
    date_str =
      if String.contains?(date_str, "T") do
        date_str
        |> String.split("T")
        |> List.first()
      else
        date_str
      end

    date_format_str = "{YYYY}{0M}{0D}"

    case Timex.parse(date_str, date_format_str) do
      {:ok, parsed_datetime} -> {:ok, NaiveDateTime.to_date(parsed_datetime)}
      {:error, error} -> {:error, error}
    end
  end

  def is_fullday(attributes, datetime_str) do
    date_format_str = "{YYYY}{0M}{0D}"

    if String.contains?(attributes, "VALUE=DATE") do
      true
    else
      case Timex.parse(datetime_str, date_format_str) do
        {:ok, _datetime} -> true
        _ -> false
      end
    end
  end

  @doc """
  Parses iCalendar datetime formats to DateTime using regex-based parsing.

  Supports three formats:
  - UTC datetime: `20250101T120000Z`
  - Local datetime: `20250101T120000` (treated as UTC)
  - Date only: `20250101` (treated as midnight UTC)

  This is a faster alternative to `parse_datetime/1` that doesn't require Timex for simple formats.

  ## Examples

      iex> Naiveical.Helpers.parse_icalendar_datetime("20250101T120000Z")
      {:ok, ~U[2025-01-01 12:00:00Z]}

      iex> Naiveical.Helpers.parse_icalendar_datetime("20250101")
      {:ok, ~U[2025-01-01 00:00:00Z]}

      iex> Naiveical.Helpers.parse_icalendar_datetime("")
      {:error, :empty_string}
  """
  def parse_icalendar_datetime(nil), do: {:error, :nil_value}
  def parse_icalendar_datetime(""), do: {:error, :empty_string}

  def parse_icalendar_datetime(str) when is_binary(str) do
    # Single regex pattern handles all three formats
    pattern = ~r/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?Z?$/

    case Regex.run(pattern, String.trim_trailing(str, "Z")) do
      [_, year, month, day, hour, minute, second] ->
        build_datetime_from_parts(year, month, day, hour, minute, second)

      [_, year, month, day] ->
        build_datetime_from_parts(year, month, day, "0", "0", "0")

      _ ->
        {:error, :invalid_format}
    end
  end

  @doc """
  Parses iCalendar datetime formats to DateTime, raising on error.

  See `parse_icalendar_datetime/1` for supported formats.

  ## Examples

      iex> Naiveical.Helpers.parse_icalendar_datetime!("20250101T120000Z")
      ~U[2025-01-01 12:00:00Z]
  """
  def parse_icalendar_datetime!(str) do
    case parse_icalendar_datetime(str) do
      {:ok, datetime} -> datetime
      {:error, reason} -> raise ArgumentError, "Failed to parse datetime: #{inspect(reason)}"
    end
  end

  defp build_datetime_from_parts(year, month, day, hour, minute, second) do
    with {:ok, date} <-
           Date.new(
             String.to_integer(year),
             String.to_integer(month),
             String.to_integer(day)
           ),
         {:ok, time} <-
           Time.new(
             String.to_integer(hour || "0"),
             String.to_integer(minute || "0"),
             String.to_integer(second || "0")
           ),
         {:ok, dt} <- DateTime.new(date, time, "Etc/UTC") do
      {:ok, dt}
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :parse_failed}
  end

  @doc """
  Formats a DateTime or NaiveDateTime for iCalendar output.

  Returns timestamp in ISO 8601 basic format without separators: YYYYMMDDTHHMMSSZ

  ## Examples

      iex> dt = ~U[2025-01-01 12:30:45Z]
      iex> Naiveical.Helpers.format_icalendar_datetime(dt)
      "20250101T123045Z"
  """
  def format_icalendar_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
    |> String.replace("-", "")
    |> String.replace(":", "")
  end

  def format_icalendar_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> format_icalendar_datetime()
  end

  @doc """
  Formats a Date for iCalendar output.

  Returns date in ISO 8601 basic format: YYYYMMDD

  ## Examples

      iex> date = ~D[2025-01-01]
      iex> Naiveical.Helpers.format_icalendar_date(date)
      "20250101"
  """
  def format_icalendar_date(%Date{} = date) do
    Calendar.strftime(date, "%Y%m%d")
  end

  @doc """
  Parses an iCalendar date string (YYYYMMDD format) to a Date.

  This is a faster alternative to `parse_date/1` for simple date-only formats.

  ## Examples

      iex> Naiveical.Helpers.parse_icalendar_date("20250101")
      {:ok, ~D[2025-01-01]}

      iex> Naiveical.Helpers.parse_icalendar_date("")
      {:error, :empty_string}
  """
  def parse_icalendar_date(nil), do: {:error, :nil_value}
  def parse_icalendar_date(""), do: {:error, :empty_string}

  def parse_icalendar_date(str) when is_binary(str) do
    pattern = ~r/^(\d{4})(\d{2})(\d{2})$/

    case Regex.run(pattern, str) do
      [_, year, month, day] ->
        Date.new(
          String.to_integer(year),
          String.to_integer(month),
          String.to_integer(day)
        )

      _ ->
        {:error, :invalid_format}
    end
  rescue
    _ -> {:error, :parse_failed}
  end

  @doc """
  Parses an iCalendar date string (YYYYMMDD format) to a Date, raising on error.

  ## Examples

      iex> Naiveical.Helpers.parse_icalendar_date!("20250101")
      ~D[2025-01-01]
  """
  def parse_icalendar_date!(str) do
    case parse_icalendar_date(str) do
      {:ok, date} -> date
      {:error, reason} -> raise ArgumentError, "Failed to parse date: #{inspect(reason)}"
    end
  end
end
