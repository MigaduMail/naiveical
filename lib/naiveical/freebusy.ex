defmodule Naiveical.FreeBusy do
  @moduledoc """
  This module provides functions for extracting free/busy time information from iCalendar data.

  It handles timezone conversions, duration calculations, and busy period extraction from VEVENT components.
  """

  require Logger

  @doc """
  Extracts busy periods from an iCalendar event within a given time range.

  Returns a list of busy periods as maps with `:start` and `:end` keys in ISO 8601 basic format.

  ## Parameters

    * `ical_data` - The iCalendar data as a string
    * `time_range` - A map with `:start` and `:end` keys in ISO 8601 basic format (e.g., "20251105T100000Z")

  ## Examples

      iex> ical = "BEGIN:VEVENT\\r\\nDTSTART:20251105T100000Z\\r\\nDTEND:20251105T110000Z\\r\\nEND:VEVENT"
      iex> time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}
      iex> Naiveical.FreeBusy.extract_busy_period_from_event(ical, time_range)
      [%{start: "20251105T100000Z", end: "20251105T110000Z"}]

  """
  @spec extract_busy_period_from_event(String.t(), %{start: String.t(), end: String.t()}) ::
          [%{start: String.t(), end: String.t()}]
  def extract_busy_period_from_event(ical_data, time_range) when is_binary(ical_data) do
    Logger.debug(fn ->
      """
      Extracting busy period from event:
        iCal preview: #{String.slice(ical_data, 0, 200)}
      """
    end)

    # Extract DTSTART - handle multiple formats:
    # 1. UTC: 20251105T100000Z
    # 2. Local/Timezone: 20251105T090000 (with TZID parameter)
    # 3. Date only: 20251105 (with VALUE=DATE parameter)
    dtstart =
      cond do
        # Try UTC format first (YYYYMMDDTHHMMSSZ)
        match = Regex.run(~r/DTSTART(?:;[^:]*)?:(\d{8}T\d{6}Z)/i, ical_data) ->
          [_, dt] = match
          Logger.debug("Matched UTC format: #{dt}")
          dt

        # Try local time format with TZID (YYYYMMDDTHHMMSS without Z)
        match = Regex.run(~r/DTSTART;[^:]*TZID=([^:;]+)[^:]*:(\d{8}T\d{6})\b/i, ical_data) ->
          [_, tzid, dt] = match
          Logger.debug("Matched format with TZID=#{tzid}: #{dt}")
          # Convert from local timezone to UTC
          convert_to_utc(dt, tzid, ical_data)

        # Try local time format without explicit TZID
        match = Regex.run(~r/DTSTART(?:;[^:]*)?:(\d{8}T\d{6})\b/i, ical_data) ->
          [_, dt] = match
          result = "#{dt}Z"
          Logger.debug("Matched local format without TZID: #{dt} -> #{result} (assuming UTC)")
          result

        # Try date-only format (YYYYMMDD)
        match = Regex.run(~r/DTSTART(?:;VALUE=DATE)?:(\d{8})\b/i, ical_data) ->
          [_, date] = match
          result = "#{date}T000000Z"
          Logger.debug("Matched date-only format: #{date} -> #{result}")
          # All-day event: treat as midnight to midnight UTC
          result

        true ->
          Logger.debug("NO DTSTART MATCH!")
          nil
      end

    # Extract DTEND or calculate from DURATION
    dtend =
      cond do
        # Try DTEND UTC format
        match = Regex.run(~r/DTEND(?:;[^:]*)?:(\d{8}T\d{6}Z)/i, ical_data) ->
          [_, dt] = match
          dt

        # Try DTEND with TZID
        match = Regex.run(~r/DTEND;[^:]*TZID=([^:;]+)[^:]*:(\d{8}T\d{6})\b/i, ical_data) ->
          [_, tzid, dt] = match
          Logger.debug("Matched DTEND with TZID=#{tzid}: #{dt}")
          convert_to_utc(dt, tzid, ical_data)

        # Try DTEND local time format without TZID
        match = Regex.run(~r/DTEND(?:;[^:]*)?:(\d{8}T\d{6})\b/i, ical_data) ->
          [_, dt] = match
          "#{dt}Z"

        # Try DTEND date-only format
        match = Regex.run(~r/DTEND(?:;VALUE=DATE)?:(\d{8})\b/i, ical_data) ->
          [_, date] = match
          "#{date}T000000Z"

        # Try DURATION property
        match = Regex.run(~r/DURATION:(P(?:\d+D)?(?:T(?:\d+H)?(?:\d+M)?(?:\d+S)?)?)/i, ical_data) ->
          [_, duration] = match
          calculate_end_from_duration(dtstart, duration)

        true ->
          # Default: use dtstart as fallback (instant event)
          dtstart
      end

    if dtstart && dtend && overlaps_time_range?(dtstart, dtend, time_range) do
      [%{start: dtstart, end: dtend}]
    else
      []
    end
  end

  # ============================================================================
  # Timezone Conversion Functions
  # ============================================================================

  @doc false
  defp convert_to_utc(local_time, tzid, ical_data) do
    with {:ok, naive} <- parse_local_naive_datetime(local_time),
         {:ok, formatted} <- convert_with_timex(naive, tzid) do
      formatted
    else
      _ -> convert_with_offset(local_time, tzid, ical_data)
    end
  end

  @doc false
  defp parse_local_naive_datetime(local_time) do
    with <<year::binary-size(4), month::binary-size(2), day::binary-size(2), "T",
           hour::binary-size(2), minute::binary-size(2), second::binary-size(2)>> <- local_time,
         {y, ""} <- Integer.parse(year),
         {m, ""} <- Integer.parse(month),
         {d, ""} <- Integer.parse(day),
         {h, ""} <- Integer.parse(hour),
         {min, ""} <- Integer.parse(minute),
         {s, ""} <- Integer.parse(second),
         {:ok, naive} <- NaiveDateTime.new(y, m, d, h, min, s) do
      {:ok, naive}
    else
      _ -> :error
    end
  end

  @doc false
  defp convert_with_timex(naive, tzid) do
    try do
      case Timex.to_datetime(naive, tzid) do
        %DateTime{} = dt ->
          dt
          |> DateTime.shift_zone!("Etc/UTC")
          |> DateTime.to_iso8601(:basic)
          |> String.replace(":", "")
          |> then(&{:ok, &1})

        {:error, _} ->
          :error
      end
    rescue
      _ -> :error
    end
  end

  @doc false
  defp convert_with_offset(local_time, tzid, ical_data) do
    <<year::binary-size(4), month::binary-size(2), day::binary-size(2), "T", hour::binary-size(2),
      minute::binary-size(2), second::binary-size(2)>> = local_time

    {standard_offset, daylight_offset, has_dst} = extract_timezone_offsets(tzid, ical_data)
    month_int = String.to_integer(month)

    offset =
      cond do
        has_dst and month_int >= 3 and month_int <= 10 -> daylight_offset
        true -> standard_offset
      end

    case Regex.run(~r/^([+-])(\d{2})(\d{2})$/, offset) do
      [_, sign, hours, minutes] ->
        offset_hours = String.to_integer(hours)
        offset_minutes = String.to_integer(minutes)
        total_minutes = offset_hours * 60 + offset_minutes
        total_minutes = if sign == "-", do: total_minutes, else: -total_minutes

        case DateTime.from_iso8601("#{year}-#{month}-#{day}T#{hour}:#{minute}:#{second}Z") do
          {:ok, local_dt, 0} ->
            utc_dt = DateTime.add(local_dt, total_minutes * 60, :second)

            utc_dt
            |> DateTime.to_iso8601(:basic)
            |> String.replace(":", "")

          _ ->
            "#{local_time}Z"
        end

      _ ->
        "#{local_time}Z"
    end
  end

  @doc false
  defp extract_timezone_offsets(tzid, ical_data) do
    # Extract the VTIMEZONE component for this TZID
    vtimezone_pattern = ~r/BEGIN:VTIMEZONE\s+TZID:#{Regex.escape(tzid)}.*?END:VTIMEZONE/is

    case Regex.run(vtimezone_pattern, ical_data) do
      [vtimezone] ->
        # Extract TZOFFSETTO from DAYLIGHT component (preferred)
        daylight_offset =
          case Regex.run(~r/BEGIN:DAYLIGHT.*?TZOFFSETTO:([+-]\d{4}).*?END:DAYLIGHT/is, vtimezone) do
            [_, offset] -> offset
            _ -> "+0000"
          end

        # Extract TZOFFSETTO from STANDARD component
        standard_offset =
          case Regex.run(~r/BEGIN:STANDARD.*?TZOFFSETTO:([+-]\d{4}).*?END:STANDARD/is, vtimezone) do
            [_, offset] -> offset
            # Fall back to daylight if no standard
            _ -> daylight_offset
          end

        has_dst = daylight_offset != standard_offset
        {standard_offset, daylight_offset, has_dst}

      _ ->
        Logger.debug("Could not find VTIMEZONE for TZID: #{tzid}")
        {"+0000", "+0000", false}
    end
  end

  # ============================================================================
  # Duration and Time Calculation
  # ============================================================================

  @doc false
  defp calculate_end_from_duration(dtstart, duration)
       when is_binary(dtstart) and is_binary(duration) do
    # Parse ISO 8601 duration (simplified)
    # Format: P[nD][T[nH][nM][nS]] or PnW
    cond do
      # P1D - 1 day
      match = Regex.run(~r/P(\d+)D/i, duration) ->
        [_, days] = match
        add_days_to_timestamp(dtstart, String.to_integer(days))

      # PT1H - 1 hour
      match = Regex.run(~r/PT(\d+)H/i, duration) ->
        [_, hours] = match
        add_hours_to_timestamp(dtstart, String.to_integer(hours))

      # Just use dtstart as fallback
      true ->
        dtstart
    end
  end

  @doc false
  defp calculate_end_from_duration(dtstart, _), do: dtstart

  @doc false
  defp add_days_to_timestamp(timestamp, days) do
    # Parse: 20251105T000000Z
    <<year::binary-size(4), month::binary-size(2), day::binary-size(2), rest::binary>> =
      timestamp

    date = Date.from_iso8601!("#{year}-#{month}-#{day}")
    new_date = Date.add(date, days)
    "#{Date.to_iso8601(new_date) |> String.replace("-", "")}#{String.slice(rest, 0..-1//1)}"
  end

  @doc false
  defp add_hours_to_timestamp(timestamp, hours) do
    # Parse: 20251105T090000Z -> 2025-11-05T09:00:00Z
    <<year::binary-size(4), month::binary-size(2), day::binary-size(2), "T", hour::binary-size(2),
      minute::binary-size(2), second::binary-size(2), "Z">> = timestamp

    {:ok, dt, 0} =
      DateTime.from_iso8601("#{year}-#{month}-#{day}T#{hour}:#{minute}:#{second}Z")

    new_dt = DateTime.add(dt, hours * 3600, :second)

    new_dt
    |> DateTime.to_iso8601(:basic)
    |> String.replace("-", "")
    |> String.replace(":", "")
  end

  @doc false
  defp overlaps_time_range?(event_start, event_end, %{start: range_start, end: range_end}) do
    # Simple string comparison works for ISO 8601 dates
    event_start < range_end && event_end > range_start
  end
end
