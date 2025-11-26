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

    case startings do
      [] ->
        []

      _ ->
        Enum.map(0..(length(startings) - 1), fn idx ->
          [{s, _len}] = Enum.at(startings, idx)
          [{e, len}] = Enum.at(endings, idx)

          String.slice(ical_text, s, e - s + len)
          |> String.replace(~r/\r?\n/, "\r\n")
          |> String.trim()
        end)
    end
  end

  @doc """
  Remove sections of an icalender text, such as remove all VALARMs from a VEVENT.

  The reason of this is to allow the correct extraction of the content lines. If, for example, a VEVENT also contains a VALARM with a description, but the
  VEVENT does not contain a description, the function extract_contentline_by_tag would fetch the description of the VALARM instead of returning nil.

    ## Examples:

  iex> Naiveical.Extractor.remove_sections_by_tag("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\nEND:XX", "YY")
  "BEGIN:XX\\nEND:XX"

  iex> Naiveical.Extractor.remove_sections_by_tag("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\naaaa:bbbb\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "NOTEXIST")
  "BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\naaaa:bbbb\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX"
  """
  def remove_sections_by_tag(ical_text, tag) do
    if String.contains?(ical_text, tag) do
      ical_text = String.replace(ical_text, "\r\n", "\n")
      {:ok, regex} = Regex.compile("BEGIN:#{tag}")

      startings =
        Regex.scan(regex, ical_text, return: :index) ++ [[{String.length(ical_text), 0}]]

      {:ok, regex} = Regex.compile("END:#{tag}")
      endings = [[{0, 0}]] ++ Regex.scan(regex, ical_text, return: :index)

      if length(startings) != length(endings),
        do: raise("No correct ical file, no matchin BEGIN/END for #{tag}")

      [{s, _len}] = Enum.at(startings, 0)
      [{last_e, last_e_len}] = Enum.at(endings, -1)
      end_acc = String.slice(ical_text, (last_e + last_e_len)..-1)

      if length(startings) < 2 do
        [{e, e_len}] = Enum.at(endings, 0)

        (String.slice(ical_text, 0..(s - 1)) <> String.slice(ical_text, (e + e_len)..-1))
        |> String.replace(~r/(\r?\n)+/, "\\1")
      else
        # |> String.replace(~r/\r?\n/, "\r\n")
        (Enum.reduce(0..(length(startings) - 2), "", fn idx, acc ->
           [{s, _len}] = Enum.at(startings, idx)
           [{e, e_len}] = Enum.at(endings, idx)
           from = e + e_len
           to = s - 1

           (acc <> String.slice(ical_text, from..to))
           |> String.trim()
         end) <> end_acc)
        |> String.replace(~r/((\\r)?\\n)+/, "\\1")
      end
    else
      ical_text
    end
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

      case Regex.run(regex, ical_text) do
        [_, properties, values] ->
          values = values |> String.replace("\\n", " ") |> String.trim()
          {tag, String.trim(properties), values}

        nil ->
          {tag, "", nil}
      end
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

  iex> Naiveical.Extractor.extract_datetime_contentline_by_tag("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nDTSTART;TZID=Europe/Berlin:20210422T150000\\nEND:YY\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "DTSTART")

  """
  def extract_datetime_contentline_by_tag(ical_text, tag) do
    {_tag, attrs, dtstart_str} = Naiveical.Extractor.extract_contentline_by_tag(ical_text, tag)

    tzid = Naiveical.Extractor.extract_attribute(attrs, "TZID")

    if is_nil(tzid) do
      Naiveical.Helpers.parse_datetime(dtstart_str)
    else
      Naiveical.Helpers.parse_datetime(dtstart_str, tzid)
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
    {_tag, attrs, datetime_str} = Naiveical.Extractor.extract_contentline_by_tag(ical_text, tag)

    tzid = Naiveical.Extractor.extract_attribute(attrs, "TZID")

    if is_nil(tzid) do
      Naiveical.Helpers.parse_datetime!(datetime_str)
    else
      Naiveical.Helpers.parse_datetime!(datetime_str, tzid)
    end
  end

  @doc """
  Extract a single date content line from an icalendar text. It returns a the datetime object.

  Basically, it tries to parse the extracted text as a date object

    ## Examples:

  iex> Naiveical.Extractor.extract_date_contentline_by_tag!("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nDTSTART;TZID=Europe/Berlin:20210422\\nEND:YY\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "DTSTART")

  """
  def extract_date_contentline_by_tag!(ical_text, tag) do
    {_tag, _attrs, date_str} = Naiveical.Extractor.extract_contentline_by_tag(ical_text, tag)

    Naiveical.Helpers.parse_date!(date_str)
  end

  def extract_date_contentline_by_tag(ical_text, tag) do
    {_tag, _attrs, date_str} = Naiveical.Extractor.extract_contentline_by_tag(ical_text, tag)

    Naiveical.Helpers.parse_date(date_str)
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

  @doc """
  Detects the component type from iCalendar data.

  Returns an atom representing the component type found in the iCalendar data.
  Priority order: :vfreebusy > :vtodo > :vjournal > :vevent (default)

  ## Examples

      iex> Naiveical.Extractor.detect_component_type("BEGIN:VCALENDAR\\nBEGIN:VEVENT\\nEND:VEVENT\\nEND:VCALENDAR")
      :vevent

      iex> Naiveical.Extractor.detect_component_type("BEGIN:VCALENDAR\\nBEGIN:VTODO\\nEND:VTODO\\nEND:VCALENDAR")
      :vtodo

      iex> Naiveical.Extractor.detect_component_type("BEGIN:VCALENDAR\\nEND:VCALENDAR")
      :vevent

  """
  @spec detect_component_type(String.t()) :: atom()
  def detect_component_type(ical_data) do
    cond do
      extract_sections_by_tag(ical_data, "VFREEBUSY") != [] -> :vfreebusy
      extract_sections_by_tag(ical_data, "VTODO") != [] -> :vtodo
      extract_sections_by_tag(ical_data, "VJOURNAL") != [] -> :vjournal
      extract_sections_by_tag(ical_data, "VEVENT") != [] -> :vevent
      true -> :vevent
    end
  end
end
