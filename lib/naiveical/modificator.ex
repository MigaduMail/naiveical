defmodule Naiveical.Modificator do
  @moduledoc """
  Allows creation and modifications of an icalendar file.
  """

  alias Naiveical.Helpers
  alias Naiveical.Extractor

  @datetime_format_str "{YYYY}{0M}{0D}T{h24}{m}Z"

  defp remove_carrier_returns(txt), do: String.replace(txt, "\r\n", "\n")
  defp add_carrier_returns(txt), do: String.replace(txt, ~r/\r?\n/, "\r\n")

  defp update_line(tag, new_value, new_properties) do
    if String.contains?(new_value, tag) do
      # we replace a raw value
      new_value
    else
      if String.length(new_value) > 0 do
        if String.length(new_properties) > 0 do
          "#{tag};#{new_properties}:#{new_value}"
        else
          "#{tag}:#{new_value}"
        end
      else
        ""
      end
    end
  end

  def change_value_txt(ical_text, "", new_value, new_properties), do: ical_text

  def change_value_txt(ical_text, tag, new_value, new_properties) do
    {start_idx, str_len, tag} =
      if String.contains?(ical_text, tag) do
        {:ok, regex} = Regex.compile("^#{tag}[;]?.*:.*$", [:multiline])

        [{start_idx, str_len}] =
          Regex.run(regex, remove_carrier_returns(ical_text), return: :index)

        {start_idx, str_len, tag}
      else
        {:ok, regex} = Regex.compile("^BEGIN:.*$", [:caseless, :multiline])

        [{start_idx, str_len}] =
          Regex.run(regex, remove_carrier_returns(ical_text), return: :index)

        {start_idx + str_len, 0, "\n" <> tag}
      end

    ics_before = String.slice(ical_text, 0, start_idx)
    ics_after = String.slice(ical_text, start_idx + str_len, String.length(ical_text))

    new_line = update_line(tag, new_value, new_properties)

    new_line = Helpers.fold(new_line)

    (ics_before <> "#{new_line}" <> ics_after)
    |> add_carrier_returns
  end

  def change_value_txt(ical_text, tag, new_value) do
    {tag, properties, values} = Extractor.extract_contentline_by_tag(ical_text, tag)
    change_value_txt(ical_text, tag, new_value, "")
  end

  def change_value(ical_text, tag, new_value) when is_binary(new_value) do
    change_value_txt(ical_text, tag, new_value)
  end

  def change_value(ical_text, tag, new_value) when is_nil(new_value) do
    if String.contains?(ical_text, tag) do
      change_value_txt(ical_text, tag, new_value)
    else
      ical_text
    end
  end

  def change_value(
        ical_text,
        tag,
        %DateTime{
          year: year,
          month: month,
          day: day,
          zone_abbr: zone_abbr,
          hour: hour,
          minute: minute,
          second: second,
          microsecond: microsecond,
          utc_offset: utc_offset,
          std_offset: std_offset,
          time_zone: time_zone
        } = datetime
      ) do
    change_value_txt(ical_text, tag, Timex.format(datetime, "{ISO:Basic:Z}"))
  end

  @doc """
  Change a number of values in the ical_text.
  """
  def change_values(ical_text, tag_values) do
    Enum.reduce(tag_values, ical_text, fn {key, value}, acc ->
      change_value(acc, to_string(key), value)
    end)
  end

  @doc """
  Inserts another element (or any text) into the ical_text just before the ending of the element.
  """
  def insert_into(ical_text, new_content, element, opts \\ []) do
    # normalize new element, add newlines if needed
    new_content =
      if String.match?(new_content, ~r/.*\r?\n/) do
        new_content
      else
        new_content <> "\r\n"
      end
      |> String.replace(~r/\r?\n/, "\r\n")

    if String.contains?(ical_text, "END:#{element}") do
      {:ok, regex} =
        if opts[:at] == :beginning do
          Regex.compile("BEGIN:#{element}")
        else
          Regex.compile("END:#{element}")
        end

      [{start_idx, str_len}] =
        Regex.run(regex, String.replace(ical_text, "\r\n", "\n"), return: :index)

      {ics_before, ics_after} =
        if opts[:at] == :beginning do
          {String.slice(ical_text, 0, start_idx + str_len + 1),
           String.slice(ical_text, start_idx + str_len + 1, String.length(ical_text))}
        else
          {String.slice(ical_text, 0, start_idx),
           String.slice(ical_text, start_idx, String.length(ical_text))}
        end

      {:ok,
       (ics_before <> "#{new_content}" <> ics_after)
       |> String.replace(~r/\r?\n/, "\r\n")}
    else
      {:error, "There is no ending of element #{element}"}
    end
  end

  @doc """
  Remove all elements of a specific type.
  """
  def delete_all(ical_text, tag) do
    if String.contains?(ical_text, "END:#{tag}") do
      ical_text = String.replace(ical_text, "\r\n", "\n")
      {:ok, regex_begin} = Regex.compile("BEGIN:#{tag}", [:multiline, :ungreedy])
      {:ok, regex_end} = Regex.compile("END:#{tag}", [:multiline, :ungreedy])

      begins = Regex.scan(regex_begin, ical_text, return: :index)
      ends = Regex.scan(regex_end, ical_text, return: :index)

      if length(begins) == length(ends) do
        [{first_begin_start, first_begin_length}] = Enum.at(begins, 0)
        [{last_end_start, last_end_length}] = Enum.at(ends, -1)

        last_part =
          String.slice(
            ical_text,
            last_end_start + last_end_length,
            String.length(ical_text) - last_end_start + last_end_length
          )

        new_ical =
          Enum.reduce(
            0..(length(begins) - 2),
            String.slice(ical_text, 0, first_begin_start - 1),
            fn i, acc ->
              [{end_start, end_length}] = Enum.at(ends, i)
              [{begin_start, begin_length}] = Enum.at(begins, i + 1)

              start_idx = end_start + end_length
              str_len = begin_start - (end_start + end_length) - 1

              acc <> String.slice(ical_text, start_idx, str_len)
            end
          ) <>
            last_part

        {:ok, String.replace(new_ical, ~r/\r?\n/, "\r\n")}
      else
        {:error, "BEGIN/END do not match"}
      end
    else
      {:ok, ical_text}
    end
  end

  def delete_all!(ical_text, tag) do
    case delete_all(ical_text, tag) do
      {:ok, res} -> res
      {:error, reason} -> raise(reason)
    end
  end

  def add_timezone_info(ical_text) do
    # find all timezone informations
    timezones = Regex.scan(~r/TZID=(.*):/, ical_text) |> Enum.uniq()
    # collect all timezone info
    timezones =
      Enum.reduce(timezones, "", fn [_, tzid], acc ->
        tz = File.read!("priv/zoneinfo/#{tzid}.ics")

        tz =
          Naiveical.Extractor.extract_sections_by_tag(tz, "VTIMEZONE")
          |> Enum.at(0)

        if String.length(acc) == 0 do
          tz
        else
          acc <> "\r\n" <> tz
        end
      end)

    insert_into(ical_text, timezones, "VCALENDAR", at: :beginning)
  end
end
