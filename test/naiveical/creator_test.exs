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
end
