defmodule Naiveical.CreatorTest do
  use ExUnit.Case

  describe "create vtodo" do
    test "change a description" do
      vtodo =
        """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:Excalt
        BEGIN:VTODO
        SUMMARY:Hello world
        DTSTART:20221224T1200Z
        DUE:20221224T1200Z
        UUID:123456
        DTSTAMP:20221202T1200Z
        END:VTODO
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      updated_vtodo = Naiveical.Modificator.change_value(vtodo, "SUMMARY", "a new summary")

      actual = Naiveical.Extractor.extract_contentline_by_tag(updated_vtodo, "SUMMARY")

      expected = {"SUMMARY", "", "a new summary"}
      assert expected == actual
    end
  end

  describe "create vevent" do
    test "simple vevent" do
      dtstart = DateTime.new!(~D[2022-12-24], ~T[12:00:00], "Etc/UTC")
      due = DateTime.new!(~D[2022-12-24], ~T[12:00:00], "Etc/UTC")
      dtstamp = DateTime.new!(~D[2022-12-02], ~T[12:00:00], "Etc/UTC")

      expected =
        """
        BEGIN:VTODO
        SUMMARY:Hello world
        DTSTAMP:20221202T120000Z
        DUE:20221224T1200Z
        UUID:123456
        DTSTART:20221224T1200Z
        END:VTODO
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      actual =
        Naiveical.Creator.Icalendar.create_vtodo("Hello world", due, dtstamp,
          uuid: "123456",
          dtstamp: dtstamp,
          dtstart: dtstart
        )

      assert expected == actual
    end
  end

  describe "create valarm" do
    test "simple valarm" do
      expected =
        """
        BEGIN:VALARM
        ACTION:DISPLAY
        DESCRIPTION:Birthday Party
        TRIGGER:-PT15M
        END:VALARM
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      actual = Naiveical.Creator.Icalendar.create_valarm("Birthday Party", "-PT15M")

      assert expected == actual
    end

    test "simple valarm with datetime" do
      expected =
        """
        BEGIN:VALARM
        ACTION:DISPLAY
        DESCRIPTION:Birthday Party
        TRIGGER:2022-12-24 12:00:00Z
        END:VALARM
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      trigger = DateTime.new!(~D[2022-12-24], ~T[12:00:00], "Etc/UTC")

      actual = Naiveical.Creator.Icalendar.create_valarm("Birthday Party", trigger)

      assert expected == actual
    end
  end

  describe "build_aggregated_vcalendar/3" do
    test "builds vcalendar with single event and no timezone" do
      components = [
        """
        BEGIN:VEVENT
        UID:event-123
        SUMMARY:Test Event
        END:VEVENT
        """
        |> String.replace(~r/\r?\n/, "\r\n")
      ]

      vtimezones = %{}

      actual = Naiveical.Creator.Icalendar.build_aggregated_vcalendar(components, vtimezones)

      assert actual =~ "BEGIN:VCALENDAR\r\n"
      assert actual =~ "VERSION:2.0\r\n"
      assert actual =~ "PRODID:-//ExCaldav//CalDAV Server//EN\r\n"
      assert actual =~ "BEGIN:VEVENT\r\n"
      assert actual =~ "UID:event-123\r\n"
      assert actual =~ "END:VCALENDAR\r\n"
      refute actual =~ "X-WR-CALNAME"
    end

    test "builds vcalendar with displayname" do
      components = [
        """
        BEGIN:VEVENT
        UID:event-123
        END:VEVENT
        """
        |> String.replace(~r/\r?\n/, "\r\n")
      ]

      vtimezones = %{}

      actual =
        Naiveical.Creator.Icalendar.build_aggregated_vcalendar(
          components,
          vtimezones,
          "My Calendar"
        )

      assert actual =~ "X-WR-CALNAME:My Calendar\r\n"
    end

    test "builds vcalendar with multiple events" do
      components = [
        """
        BEGIN:VEVENT
        UID:event-1
        SUMMARY:Event 1
        END:VEVENT
        """
        |> String.replace(~r/\r?\n/, "\r\n"),
        """
        BEGIN:VEVENT
        UID:event-2
        SUMMARY:Event 2
        END:VEVENT
        """
        |> String.replace(~r/\r?\n/, "\r\n")
      ]

      vtimezones = %{}

      actual = Naiveical.Creator.Icalendar.build_aggregated_vcalendar(components, vtimezones)

      assert actual =~ "UID:event-1"
      assert actual =~ "UID:event-2"
      assert actual =~ "SUMMARY:Event 1"
      assert actual =~ "SUMMARY:Event 2"
    end

    test "builds vcalendar with timezone components" do
      components = [
        """
        BEGIN:VEVENT
        UID:event-123
        DTSTART;TZID=America/New_York:20250101T120000
        END:VEVENT
        """
        |> String.replace(~r/\r?\n/, "\r\n")
      ]

      vtimezones = %{
        "America/New_York" =>
          """
          BEGIN:VTIMEZONE
          TZID:America/New_York
          BEGIN:STANDARD
          DTSTART:20241103T020000
          TZOFFSETFROM:-0400
          TZOFFSETTO:-0500
          END:STANDARD
          END:VTIMEZONE
          """
          |> String.replace(~r/\r?\n/, "\r\n")
      }

      actual = Naiveical.Creator.Icalendar.build_aggregated_vcalendar(components, vtimezones)

      assert actual =~ "BEGIN:VTIMEZONE\r\n"
      assert actual =~ "TZID:America/New_York\r\n"
      assert actual =~ "BEGIN:STANDARD\r\n"

      # Verify VTIMEZONE comes before VEVENT
      vtimezone_pos = :binary.match(actual, "BEGIN:VTIMEZONE") |> elem(0)
      vevent_pos = :binary.match(actual, "BEGIN:VEVENT") |> elem(0)
      assert vtimezone_pos < vevent_pos
    end

    test "builds vcalendar with multiple timezones" do
      components = [
        """
        BEGIN:VEVENT
        UID:event-123
        END:VEVENT
        """
        |> String.replace(~r/\r?\n/, "\r\n")
      ]

      vtimezones = %{
        "America/New_York" =>
          """
          BEGIN:VTIMEZONE
          TZID:America/New_York
          END:VTIMEZONE
          """
          |> String.replace(~r/\r?\n/, "\r\n"),
        "Europe/London" =>
          """
          BEGIN:VTIMEZONE
          TZID:Europe/London
          END:VTIMEZONE
          """
          |> String.replace(~r/\r?\n/, "\r\n")
      }

      actual = Naiveical.Creator.Icalendar.build_aggregated_vcalendar(components, vtimezones)

      assert actual =~ "TZID:America/New_York"
      assert actual =~ "TZID:Europe/London"
    end

    test "builds vcalendar with all features" do
      components = [
        """
        BEGIN:VEVENT
        UID:event-1
        SUMMARY:Event 1
        END:VEVENT
        """
        |> String.replace(~r/\r?\n/, "\r\n"),
        """
        BEGIN:VTODO
        UID:todo-1
        SUMMARY:Todo 1
        END:VTODO
        """
        |> String.replace(~r/\r?\n/, "\r\n")
      ]

      vtimezones = %{
        "America/New_York" =>
          """
          BEGIN:VTIMEZONE
          TZID:America/New_York
          END:VTIMEZONE
          """
          |> String.replace(~r/\r?\n/, "\r\n")
      }

      actual =
        Naiveical.Creator.Icalendar.build_aggregated_vcalendar(
          components,
          vtimezones,
          "Work Calendar"
        )

      # Verify structure order
      assert actual =~ ~r/BEGIN:VCALENDAR\r\n.*VERSION:2.0\r\n.*PRODID/s
      assert actual =~ "X-WR-CALNAME:Work Calendar"
      assert actual =~ "TZID:America/New_York"
      assert actual =~ "UID:event-1"
      assert actual =~ "UID:todo-1"
      assert actual =~ "END:VCALENDAR\r\n"

      # Verify proper line endings
      assert String.ends_with?(actual, "\r\n")
    end

    test "handles empty components list" do
      components = []
      vtimezones = %{}

      actual = Naiveical.Creator.Icalendar.build_aggregated_vcalendar(components, vtimezones)

      assert actual =~ "BEGIN:VCALENDAR\r\n"
      assert actual =~ "END:VCALENDAR\r\n"
    end
  end
end
