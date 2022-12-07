defmodule Naiveical.ModificatorTest do
  use ExUnit.Case

  describe "Change value" do
    test "simple change" do
      ical =
        """
        BEGIN:VCALENDAR
        SUMMARY:Hello world
          long
        END:VCALENDAR
        """
        |> String.replace("\r?\n", "\r\n")

      updated_ical = Naiveical.Modificator.change_value(ical, "summary", "a new summary")

      actual = Naiveical.Extractor.extract_contentline_by_tag(updated_ical, "SUMMARY")
      expected = {"SUMMARY", "", "a new summary long"}
      assert expected == actual
    end
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

      actual = Naiveical.Modificator.change_value(vtodo, "SUMMARY", "a new summary")

      expected =
        """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:Excalt
        BEGIN:VTODO
        SUMMARY:a new summary
        DTSTART:20221224T1200Z
        DUE:20221224T1200Z
        UUID:123456
        DTSTAMP:20221202T1200Z
        END:VTODO
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")
      assert expected == actual
    end

    test "change a description with lowercase tag" do
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
        |> String.replace("\r?\n", "\r\n")

      updated_vtodo = Naiveical.Modificator.change_value(vtodo, "summary", "a new summary")

      assert Naiveical.Extractor.extract_contentline_by_tag(updated_vtodo, "SUMMARY") ==
               {"SUMMARY", "", "a new summary"}
    end
  end

  describe "insert content" do
    test "pseudo example" do
      ical_text =
        """
        BEGIN:VCALENDAR
        BEGIN:VTODO
        END:VTODO
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      {:ok, actual} = Naiveical.Modificator.insert_into(ical_text, "BE:there", "VTODO")

      expected =
        """
        BEGIN:VCALENDAR
        BEGIN:VTODO
        BE:there
        END:VTODO
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      assert expected == actual
    end

    test "add alarm to event" do
      ical_text =
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

      valarm = Naiveical.Creator.create_valarm("call the ring", "-PT15M")

      {:ok, actual} = Naiveical.Modificator.insert_into(ical_text, valarm, "VTODO")
      expected =
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
        BEGIN:VALARM
        ACTION:DISPLAY
        DESCRIPTION:call the ring
        TRIGGER:-PT15M
        END:VALARM
        END:VTODO
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")
      assert expected == actual
    end
  end
end
