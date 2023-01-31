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
        DateTime.from_naive!(datetime, "Etc/UTC")

      _ ->
        case Timex.parse(datetime_str, naive_datetime_format_str) do
          {:ok, datetime} -> datetime
          _ -> raise ArgumentError, "could not parse #{datetime_str} into #{datetime_format_str}"
        end
    end
  end

  def parse_datetime(datetime_str, timezone) do
    if is_nil(timezone) or String.length(timezone) == 0 do
      parse_datetime(datetime_str)
    else
      datetime_format_str = "{YYYY}{0M}{0D}T{h24}{m}{s}"

      case Timex.parse(datetime_str, datetime_format_str) do
        {:ok, datetime} -> DateTime.from_naive!(datetime, timezone)
        _ -> raise ArgumentError, "could not parse #{datetime_str} into #{datetime_format_str}"
      end
    end
  end
end
