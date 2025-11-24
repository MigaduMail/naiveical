defmodule Naiveical.FreeBusyTest do
  use ExUnit.Case
  doctest Naiveical.FreeBusy

  alias Naiveical.FreeBusy

  describe "extract_busy_period_from_event/2 - UTC format" do
    test "extracts busy period from simple UTC event" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T100000Z
      DTEND:20251105T110000Z
      SUMMARY:Test Event
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T100000Z", end: "20251105T110000Z"}]
    end

    test "returns empty list when event is outside time range" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T100000Z
      DTEND:20251105T110000Z
      SUMMARY:Test Event
      END:VEVENT
      """

      # Time range is before the event
      time_range = %{start: "20251104T000000Z", end: "20251104T235959Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == []
    end

    test "detects overlap when event starts before range and ends during range" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T100000Z
      DTEND:20251105T150000Z
      END:VEVENT
      """

      time_range = %{start: "20251105T120000Z", end: "20251105T180000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T100000Z", end: "20251105T150000Z"}]
    end

    test "detects overlap when event starts during range and ends after range" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T140000Z
      DTEND:20251105T200000Z
      END:VEVENT
      """

      time_range = %{start: "20251105T120000Z", end: "20251105T180000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T140000Z", end: "20251105T200000Z"}]
    end
  end

  describe "extract_busy_period_from_event/2 - date-only format" do
    test "extracts busy period from all-day event" do
      ical = """
      BEGIN:VEVENT
      DTSTART;VALUE=DATE:20251105
      DTEND;VALUE=DATE:20251106
      SUMMARY:All Day Event
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251107T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T000000Z", end: "20251106T000000Z"}]
    end

    test "extracts busy period from date-only format without VALUE parameter" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105
      DTEND:20251106
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251107T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T000000Z", end: "20251106T000000Z"}]
    end
  end

  describe "extract_busy_period_from_event/2 - DURATION property" do
    test "calculates end time from DURATION with days" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T100000Z
      DURATION:P1D
      SUMMARY:One Day Event
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251107T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T100000Z", end: "20251106T100000Z"}]
    end

    test "calculates end time from DURATION with hours" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T100000Z
      DURATION:PT2H
      SUMMARY:Two Hour Event
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T100000Z", end: "20251105T120000Z"}]
    end

    test "calculates end time from DURATION with multiple days" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T090000Z
      DURATION:P3D
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251110T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T090000Z", end: "20251108T090000Z"}]
    end
  end

  describe "extract_busy_period_from_event/2 - local time without TZID" do
    test "treats local time without TZID as UTC" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T100000
      DTEND:20251105T110000
      SUMMARY:Local Time Event
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T100000Z", end: "20251105T110000Z"}]
    end
  end

  describe "extract_busy_period_from_event/2 - TZID with VTIMEZONE" do
    test "converts event with TZID using embedded VTIMEZONE standard time" do
      ical = """
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:-//Test//Test//EN
      BEGIN:VTIMEZONE
      TZID:America/New_York
      BEGIN:STANDARD
      DTSTART:20231105T020000
      TZOFFSETFROM:-0400
      TZOFFSETTO:-0500
      END:STANDARD
      BEGIN:DAYLIGHT
      DTSTART:20240310T020000
      TZOFFSETFROM:-0500
      TZOFFSETTO:-0400
      END:DAYLIGHT
      END:VTIMEZONE
      BEGIN:VEVENT
      DTSTART;TZID=America/New_York:20251105T100000
      DTEND;TZID=America/New_York:20251105T110000
      SUMMARY:EST Event
      END:VEVENT
      END:VCALENDAR
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      # November is standard time (EST = UTC-5), so 10:00 EST = 15:00 UTC
      assert result == [%{start: "20251105T150000Z", end: "20251105T160000Z"}]
    end

    test "converts event with TZID using embedded VTIMEZONE daylight time" do
      ical = """
      BEGIN:VCALENDAR
      VERSION:2.0
      BEGIN:VTIMEZONE
      TZID:America/New_York
      BEGIN:STANDARD
      DTSTART:20231105T020000
      TZOFFSETFROM:-0400
      TZOFFSETTO:-0500
      END:STANDARD
      BEGIN:DAYLIGHT
      DTSTART:20240310T020000
      TZOFFSETFROM:-0500
      TZOFFSETTO:-0400
      END:DAYLIGHT
      END:VTIMEZONE
      BEGIN:VEVENT
      DTSTART;TZID=America/New_York:20250615T100000
      DTEND;TZID=America/New_York:20250615T110000
      SUMMARY:EDT Event
      END:VEVENT
      END:VCALENDAR
      """

      time_range = %{start: "20250615T000000Z", end: "20250616T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      # June is daylight time (EDT = UTC-4), so 10:00 EDT = 14:00 UTC
      assert result == [%{start: "20250615T140000Z", end: "20250615T150000Z"}]
    end

    test "handles TZID with Timex when timezone is recognized" do
      ical = """
      BEGIN:VEVENT
      DTSTART;TZID=Europe/Berlin:20251105T100000
      DTEND;TZID=Europe/Berlin:20251105T110000
      SUMMARY:Berlin Event
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      # November in Berlin is CET (UTC+1), so 10:00 CET = 09:00 UTC
      assert [%{start: start, end: end_time}] = result
      assert start == "20251105T090000Z"
      assert end_time == "20251105T100000Z"
    end
  end

  describe "extract_busy_period_from_event/2 - edge cases" do
    test "returns empty list when DTSTART is missing" do
      ical = """
      BEGIN:VEVENT
      DTEND:20251105T110000Z
      SUMMARY:No Start Event
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == []
    end

    test "uses DTSTART as end time when DTEND and DURATION are missing" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T100000Z
      SUMMARY:Instant Event
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      # Both start and end should be the same (instant event)
      assert result == [%{start: "20251105T100000Z", end: "20251105T100000Z"}]
    end

    test "handles event that exactly matches time range boundaries" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T000000Z
      DTEND:20251106T000000Z
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T000000Z", end: "20251106T000000Z"}]
    end

    test "handles multi-line folded properties" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T100000Z
      DTEND:20251105T110000Z
      SUMMARY:This is a very long summary that might be folded in a real iCalend
       ar file according to RFC 5545
      END:VEVENT
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T100000Z", end: "20251105T110000Z"}]
    end
  end

  describe "extract_busy_period_from_event/2 - time range boundaries" do
    test "event that touches but does not overlap (ends at range start)" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T090000Z
      DTEND:20251105T100000Z
      END:VEVENT
      """

      # Range starts exactly when event ends
      time_range = %{start: "20251105T100000Z", end: "20251105T120000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      # No overlap: event_end (10:00) <= range_start (10:00)
      assert result == []
    end

    test "event that touches but does not overlap (starts at range end)" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T120000Z
      DTEND:20251105T130000Z
      END:VEVENT
      """

      # Range ends exactly when event starts
      time_range = %{start: "20251105T100000Z", end: "20251105T120000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      # No overlap: event_start (12:00) >= range_end (12:00)
      assert result == []
    end

    test "event completely contains time range" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T080000Z
      DTEND:20251105T180000Z
      END:VEVENT
      """

      time_range = %{start: "20251105T100000Z", end: "20251105T150000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T080000Z", end: "20251105T180000Z"}]
    end

    test "time range completely contains event" do
      ical = """
      BEGIN:VEVENT
      DTSTART:20251105T110000Z
      DTEND:20251105T120000Z
      END:VEVENT
      """

      time_range = %{start: "20251105T100000Z", end: "20251105T150000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      assert result == [%{start: "20251105T110000Z", end: "20251105T120000Z"}]
    end
  end

  describe "extract_busy_period_from_event/2 - multiple datetime formats in same event" do
    test "handles DTSTART with TZID and DTEND in UTC" do
      ical = """
      BEGIN:VCALENDAR
      BEGIN:VTIMEZONE
      TZID:Europe/London
      BEGIN:STANDARD
      TZOFFSETFROM:+0100
      TZOFFSETTO:+0000
      END:STANDARD
      BEGIN:DAYLIGHT
      TZOFFSETFROM:+0000
      TZOFFSETTO:+0100
      END:DAYLIGHT
      END:VTIMEZONE
      BEGIN:VEVENT
      DTSTART;TZID=Europe/London:20251105T100000
      DTEND:20251105T110000Z
      END:VEVENT
      END:VCALENDAR
      """

      time_range = %{start: "20251105T000000Z", end: "20251106T000000Z"}

      result = FreeBusy.extract_busy_period_from_event(ical, time_range)

      # November in London is GMT (UTC+0), so 10:00 GMT = 10:00 UTC
      assert [%{start: start, end: end_time}] = result
      assert start == "20251105T100000Z"
      assert end_time == "20251105T110000Z"
    end
  end
end
