defmodule Naiveical.Extractor do
  @moduledoc """
  This module allows the extraction of parts of a icalendar text.
  """

  alias Naiveical.Helpers

  @doc """
  Extract parts of an icalender text, such as all VALARMs.
    ## Examples:

  iex> Naiveical.Extractor.extract_sections_by_tag("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "XX")
  ["BEGIN:XX\\r\\nBEGIN:YY\\r\\nA:aa\\r\\nB:bb\\r\\nEND:YY\\r\\nBEGIN:YY\\r\\nC:cc\\r\\nD:dd\\r\\nEND:YY\\r\\nEND:XX"]

  iex> Naiveical.Extractor.extract_sections_by_tag("BEGIN:XX\\r\\nBEGIN:YY\\r\\nA:aa\\r\\nB:bb\\r\\nEND:YY\\r\\nBEGIN:YY\\r\\nC:cc\\r\\nD:dd\\r\\nEND:YY\\r\\nEND:XX", "YY")
  ["BEGIN:YY\\r\\nA:aa\\r\\nB:bb\\r\\nEND:YY", "BEGIN:YY\\r\\nC:cc\\r\\nD:dd\\r\\nEND:YY"]

  """
  def extract_sections_by_tag(ical_text, tag) do
    ical_text = String.replace(ical_text, "\r\n", "\n")
    {:ok, regex} = Regex.compile("BEGIN:#{tag}")
    startings = Regex.scan(regex, ical_text, return: :index)
    {:ok, regex} = Regex.compile("END:#{tag}")
    endings = Regex.scan(regex, ical_text, return: :index)

    if length(startings) != length(endings),
      do: raise("No correct ical file, no matchin BEGIN/END for #{tag}")

    Enum.map(0..(length(startings) - 1), fn idx ->
      [{s, _len}] = Enum.at(startings, idx)
      [{e, len}] = Enum.at(endings, idx)

      String.slice(ical_text, s, e - s + len)
      |> String.replace(~r/\r?\n/, "\r\n")
      |> String.trim()
    end)
  end

  @doc """
  Remove sections of an icalender text, such as remove all VALARMs from a VEVENT.

  The reason of this is to allow the correct extraction of the content lines. If, for example, a VEVENT also contains a VALARM with a description, but the
  VEVENT does not contain a description, the function extract_contentline_by_tag would fetch the description of the VALARM instead of returning nil.

    ## Examples:

  iex> Naiveical.Extractor.remove_sections_by_tag("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\naaaa:bbbb\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "YY")
  "BEGIN:XX\\naaaa:bbbb\\nEND:XX"

  """
  def remove_sections_by_tag(ical_text, tag) do
    ical_text = String.replace(ical_text, "\r\n", "\n")
    {:ok, regex} = Regex.compile("BEGIN:#{tag}")
    startings = Regex.scan(regex, ical_text, return: :index)
    {:ok, regex} = Regex.compile("END:#{tag}")
    endings = Regex.scan(regex, ical_text, return: :index)

    if length(startings) != length(endings),
      do: raise("No correct ical file, no matchin BEGIN/END for #{tag}")

    [{s, _len}] = Enum.at(startings, 0)
    start_acc = String.slice(ical_text, 0, s)
    [{last_e, last_e_len}] = Enum.at(endings, -1)
    end_acc = String.slice(ical_text, (last_e + last_e_len)..-1)

    (Enum.reduce(0..(length(startings) - 2), start_acc, fn idx, acc ->
       [{s, s_len}] = Enum.at(startings, idx + 1)
       [{e, e_len}] = Enum.at(endings, idx)

       from = e - 0 + e_len
       to = s - 1

       (acc <> String.slice(ical_text, from..to))
       |> String.replace(~r/\r?\n/, "\r\n")
       |> String.trim()
     end) <> end_acc)
    |> String.replace(~r/(\\n)+/, "\\n")
  end

  @doc """
  Extract a single content line from an icalendar text split into tag, properties, and values. It returns a tuple with `{tag-name, properties, value}`.

    ## Examples:

  iex> Naiveical.Extractor.extract_contentline_by_tag("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "A")
  {"A","","aa"}

  iex> Naiveical.Extractor.extract_contentline_by_tag("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "ZZZ")
  {"ZZZ","",nil}
  """
  def extract_contentline_by_tag(nil, tag), do: {tag, "", nil}

  def extract_contentline_by_tag(ical_text, tag) do
    tag = String.upcase(tag)

    if String.contains?(ical_text, tag) do
      ical_text = Helpers.unfold(ical_text)
      {:ok, regex} = Regex.compile("^#{tag}[;]?(.*):(.*)$", [:multiline])
      [_, properties, values] = Regex.run(regex, ical_text)
      values = values |> String.replace("\\n", " ") |> String.trim()
      {tag, String.trim(properties), values}
    else
      {tag, "", nil}
    end
  end

  @doc """
  Extract a raw single content line from an icalendar text.

    ## Examples:

  iex> Naiveical.Extractor.extract_raw_contentline_by_tag("BEGIN:XX\\nBEGIN:YY\\nA;xx:aa\\nB:bb\\nEND:YY\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "A")
  "A;xx:aa"

  iex> Naiveical.Extractor.extract_raw_contentline_by_tag("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "ZZZ")
  nil
  """
  def extract_raw_contentline_by_tag(nil, _tag), do: nil

  def extract_raw_contentline_by_tag(ical_text, tag) do
    tag = String.upcase(tag)

    if String.contains?(ical_text, tag) do
      ical_text = Helpers.unfold(ical_text)
      {:ok, regex} = Regex.compile("^#{tag}[;]?.*:.*$", [:multiline])
      [res] = Regex.run(regex, ical_text)
      res |> String.replace("\\n", " ") |> String.trim()
    else
      nil
    end
  end

  @doc """
  Extract a single datetime content line from an icalendar text. It returns a the datetime object.

  Basically, it tries to parse the extracted text as a datetime object with the
  given timezone information

    ## Examples:

  iex> Naiveical.Extractor.extract_datetime_contentline_by_tag!("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nDTSTART;TZID=Europe/Berlin:20210422T150000\\nEND:YY\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "DTSTART")

  """
  def extract_datetime_contentline_by_tag!(ical_text, tag) do
    {_tag, attrs, dtstart_str} = Naiveical.Extractor.extract_contentline_by_tag(ical_text, tag)

    tzid = Naiveical.Extractor.extract_attribute(attrs, "TZID")

    if is_nil(tzid) do
      Naiveical.Helpers.parse_datetime(dtstart_str)
    else
      Naiveical.Helpers.parse_datetime(dtstart_str, tzid)
    end
  end

  @doc """
  Extracts a specific attribute from a list of attributes.
  """
  def extract_attribute(attribute_list_str, attr) do
    if String.contains?(attribute_list_str, attr) do
      attribute_list_str
      |> String.split(";")
      |> Enum.filter(fn x ->
        [name, _value] = String.split(x, "=")
        name == attr
      end)
      |> List.first()
      |> String.split("=")
      |> List.last()
    else
      nil
    end
  end
end
