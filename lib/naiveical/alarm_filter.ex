defmodule Naiveical.AlarmFilter do
  @moduledoc """
  Filters calendar objects by checking whether any VALARM triggers fall within a requested range.
  """

  alias Naiveical.Extractor

  def apply(objects, nil), do: objects

  def apply(objects, %{start: start_str, end: end_str}) do
    with {:ok, range_start} <- parse_caldav_datetime(start_str),
         {:ok, range_end} <- parse_caldav_datetime(end_str) do
      Enum.filter(objects, fn object ->
        alarm_in_range?(object, range_start, range_end)
      end)
    else
      _ -> objects
    end
  end

  def apply(objects, _), do: objects

  defp alarm_in_range?(object, range_start, range_end) do
    with {:ok, {event_start, event_end}} <- extract_event_bounds(object) do
      extract_alarm_triggers(object.calendardata, event_start, event_end)
      |> Enum.any?(fn trigger ->
        DateTime.compare(trigger, range_start) != :lt and
          DateTime.compare(trigger, range_end) == :lt
      end)
    else
      _ -> false
    end
  end

  defp extract_event_bounds(object) do
    data = to_string(object.calendardata || "")
    component = String.upcase(object.componenttype || "")

    case extract_datetime_field(data, "DTSTART") do
      {:ok, start_dt} ->
        end_dt =
          case extract_datetime_field(data, "DTEND") do
            {:ok, dt} -> dt
            _ -> calculate_end_from_duration(start_dt, data)
          end

        {:ok, {start_dt, end_dt}}

      _ ->
        if component == "VTODO" do
          case extract_datetime_field(data, "DUE") do
            {:ok, due} -> {:ok, {due, due}}
            _ -> {:error, :no_start}
          end
        else
          {:error, :no_start}
        end
    end
  end

  defp extract_alarm_triggers(ical_data, event_start, event_end) do
    ical_data
    |> normalize_newlines()
    |> split_valarms()
    |> Enum.flat_map(fn alarm_text ->
      compute_alarm_occurrences(alarm_text, event_start, event_end)
    end)
  end

  defp compute_alarm_occurrences(alarm_text, event_start, event_end) do
    case Extractor.extract_contentline_by_tag(alarm_text, "TRIGGER") do
      {_tag, _attrs, nil} ->
        []

      {_tag, attrs, trigger_value} ->
        related =
          attrs
          |> Extractor.extract_attribute("RELATED")
          |> to_string()
          |> String.upcase()
          |> case do
            "" -> "START"
            value -> value
          end

        value_type =
          attrs
          |> Extractor.extract_attribute("VALUE")
          |> to_string()
          |> String.upcase()

        tzid = Extractor.extract_attribute(attrs, "TZID")

        base_time =
          case related do
            "END" -> event_end || event_start
            _ -> event_start
          end

        with {:ok, base_dt} <- ensure_datetime(base_time),
             {:ok, initial_trigger} <-
               compute_trigger_datetime(trigger_value, value_type, tzid, base_dt) do
          repeat_count = parse_integer_property(alarm_text, "REPEAT")
          interval_seconds = duration_property_seconds(alarm_text, "DURATION")

          build_trigger_series(initial_trigger, repeat_count, interval_seconds)
        else
          _ -> []
        end
    end
  end

  defp ensure_datetime(%DateTime{} = dt), do: {:ok, dt}
  defp ensure_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive(ndt, "Etc/UTC")
  defp ensure_datetime(_), do: {:error, :no_base_time}

  defp compute_trigger_datetime(value, "DATE-TIME", tzid, _base_dt) do
    parse_datetime_value(value, tzid)
  end

  defp compute_trigger_datetime(value, _value_type, _tzid, base_dt) do
    {sign, duration_str} =
      case value do
        "-" <> rest -> {-1, rest}
        "+" <> rest -> {1, rest}
        other -> {1, other}
      end

    with {:ok, seconds} <- parse_duration_to_seconds(duration_str) do
      {:ok, DateTime.add(base_dt, sign * seconds, :second)}
    end
  end

  defp build_trigger_series(initial_trigger, repeat_count, interval_seconds) do
    additional =
      cond do
        repeat_count <= 0 ->
          []

        interval_seconds <= 0 ->
          []

        true ->
          Enum.map(1..repeat_count, fn idx ->
            DateTime.add(initial_trigger, interval_seconds * idx, :second)
          end)
      end

    [initial_trigger | additional]
  end

  defp extract_datetime_field(ical_data, property) do
    case Extractor.extract_contentline_by_tag(ical_data, property) do
      {_tag, _attrs, nil} ->
        {:error, :not_found}

      {_tag, attrs, value} ->
        parse_datetime_value(value, Extractor.extract_attribute(attrs, "TZID"))
    end
  end

  defp parse_datetime_value(value, nil), do: parse_caldav_datetime(value)

  defp parse_datetime_value(value, tzid) do
    case Naiveical.Helpers.parse_datetime(value, tzid) do
      {:ok, %DateTime{} = dt} -> DateTime.shift_zone(dt, "Etc/UTC")
      {:ok, %NaiveDateTime{} = ndt} -> {:ok, DateTime.from_naive!(ndt, tzid)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_duration_to_seconds(duration) when is_binary(duration) do
    regex = ~r/^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/

    case Regex.run(regex, duration) do
      nil ->
        {:error, :invalid_duration}

      [_ | captures] ->
        [days, hours, mins, secs] = pad_duration_captures(captures)
        days = parse_int(days)
        hours = parse_int(hours)
        mins = parse_int(mins)
        secs = parse_int(secs)

        {:ok, days * 86_400 + hours * 3600 + mins * 60 + secs}
    end
  end

  defp parse_duration_to_seconds(_), do: {:error, :invalid_duration}

  defp duration_property_seconds(ical_data, property) do
    case Extractor.extract_contentline_by_tag(ical_data, property) do
      {_tag, _attrs, nil} ->
        0

      {_tag, _attrs, value} ->
        case parse_duration_to_seconds(value) do
          {:ok, seconds} -> seconds
          _ -> 0
        end
    end
  end

  defp parse_integer_property(ical_data, property) do
    case Extractor.extract_contentline_by_tag(ical_data, property) do
      {_tag, _attrs, nil} -> 0
      {_tag, _attrs, value} -> parse_int(value)
    end
  end

  defp parse_int(nil), do: 0
  defp parse_int(""), do: 0

  defp parse_int(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp pad_duration_captures(captures) do
    taken = Enum.take(captures, 4)
    pad_count = max(4 - length(taken), 0)
    taken ++ List.duplicate(nil, pad_count)
  end

  defp normalize_newlines(text) do
    text
    |> to_string()
    |> String.replace("\r\n", "\n")
  end

  defp split_valarms(text) do
    text
    |> String.split("BEGIN:VALARM")
    |> Enum.drop(1)
    |> Enum.reduce([], fn chunk, acc ->
      case String.split(chunk, "END:VALARM", parts: 2) do
        [body, _rest] ->
          section = "BEGIN:VALARM" <> body <> "END:VALARM"
          [section | acc]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp calculate_end_from_duration(dtstart, ical_data) do
    case Extractor.extract_contentline_by_tag(ical_data, "DURATION") do
      {_tag, _attrs, nil} ->
        dtstart

      {_tag, _attrs, duration} ->
        case parse_duration_to_seconds(duration) do
          {:ok, seconds} -> DateTime.add(dtstart, seconds, :second)
          _ -> dtstart
        end
    end
  end

  defp parse_caldav_datetime(nil), do: {:error, :nil_value}
  defp parse_caldav_datetime(""), do: {:error, :empty_string}

  defp parse_caldav_datetime(str) when is_binary(str) do
    trimmed = String.trim_trailing(str, "Z")
    regex = ~r/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?$/

    case Regex.run(regex, trimmed) do
      [_, year, month, day, hour, minute, second] ->
        build_datetime(year, month, day, hour, minute, second)

      [_, year, month, day] ->
        build_datetime(year, month, day, "0", "0", "0")

      _ ->
        {:error, :invalid_format}
    end
  end

  defp build_datetime(year, month, day, hour, minute, second) do
    with {:ok, date} <-
           Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day)),
         {:ok, time} <-
           Time.new(
             String.to_integer(hour || "0"),
             String.to_integer(minute || "0"),
             String.to_integer(second || "0")
           ),
         {:ok, datetime} <- DateTime.new(date, time, "Etc/UTC") do
      {:ok, datetime}
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :parse_failed}
  end
end
