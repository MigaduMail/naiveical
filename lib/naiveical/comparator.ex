defmodule CalendarClient.Naiveical.Comparator do
  @moduledoc """
  Compares icalendar texts.
  """

  alias Naiveical.Helpers

  def equal?(ical_text_1, ical_text_2, exclude_tags \\ []) do
    ical_text_1_sorted =
      ical_text_1
      |> Helpers.unfold()
      |> String.split("\n")
      |> Enum.reject(fn str ->
        Enum.any?(exclude_tags, fn exclude ->
          String.contains?(String.downcase(str), String.downcase(exclude))
        end)
      end)
      |> Enum.sort()
      |> Enum.join("\n")

    ical_text_2_sorted =
      ical_text_2
      |> Helpers.unfold()
      |> String.split("\n")
      |> Enum.reject(fn str ->
        Enum.any?(exclude_tags, fn exclude ->
          String.contains?(String.downcase(str), String.downcase(exclude))
        end)
      end)
      |> Enum.sort()
      |> Enum.join("\n")

    ical_text_1_sorted == ical_text_2_sorted
  end
end
