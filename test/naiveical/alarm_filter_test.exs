defmodule Naiveical.AlarmFilterTest do
  use ExUnit.Case, async: true

  alias Naiveical.AlarmFilter

  @range %{start: "20260101T000000Z", end: "20260102T000000Z"}

  setup_all do
    Application.ensure_all_started(:tzdata)
    :ok
  end

  defp build_object(ics, overrides \\ []) do
    base = %{
      calendardata: String.trim(ics),
      componenttype: "VEVENT",
      uri: "event.ics"
    }

    overrides
    |> Enum.into(%{})
    |> Map.merge(base)
  end

  test "returns original objects when filter is nil" do
    object = build_object("BEGIN:VEVENT\nEND:VEVENT")
    assert [object] == AlarmFilter.apply([object], nil)
  end

  test "matches alarms relative to start time" do
    ical = """
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART;TZID=US/Eastern:20260101T180000
DURATION:PT1H
UID:alarm-start
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER;RELATED=START:-PT10M
END:VALARM
END:VEVENT
END:VCALENDAR
"""

    object = build_object(ical, uri: "alarm-start.ics")

    assert [^object] = AlarmFilter.apply([object], @range)
  end

  test "matches repeating alarm triggers" do
    ical = """
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART;TZID=US/Eastern:20260101T030000
DURATION:PT30M
UID:alarm-repeat
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER;RELATED=START:-PT15M
REPEAT:2
DURATION:PT5M
END:VALARM
END:VEVENT
END:VCALENDAR
"""

    object = build_object(ical, uri: "alarm-repeat.ics")
    range = %{start: "20251231T230000Z", end: "20260101T090000Z"}

    assert [^object] = AlarmFilter.apply([object], range)
  end

  test "ignores events whose alarms fall outside the range" do
    ical = """
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART;TZID=US/Eastern:20260105T180000
DURATION:PT1H
UID:alarm-future
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER;RELATED=START:-PT10M
END:VALARM
END:VEVENT
END:VCALENDAR
"""

    object = build_object(ical, uri: "alarm-future.ics")

    assert [] == AlarmFilter.apply([object], @range)
  end
end
