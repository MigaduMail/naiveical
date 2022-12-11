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
  Extract a single content line from an icalendar text. It returns a tuple with `{tag-name, properties, value}`.

    ## Examples:

  iex> Naiveical.Extractor.extract_contentline_by_tag("BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX", "A")
  {"A","","aa"}

  """
  def extract_contentline_by_tag(ical_text, tag) do
    tag = String.upcase(tag)

    if String.contains?(ical_text, tag) do
      {:ok, regex} = Regex.compile("^#{tag}[;]?(.*):(.*)$", [:multiline])
      ical_text = Helpers.unfold(ical_text)

      [_, properties, values] = Regex.run(regex, ical_text)
      {tag, String.trim(properties), String.trim(values)}
    else
      nil
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
        [name, value] = String.split(x, "=")
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
