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
        |> String.replace(~r/\r?\n/, "\r\n")

      updated_ical = Naiveical.Modificator.change_value(ical, "summary", "a new summary")

      actual = Naiveical.Extractor.extract_contentline_by_tag(updated_ical, "SUMMARY")
      expected = {"SUMMARY", "", "a new summary long"}
      assert expected == actual
    end

    test "add a new value" do
      ical =
        """
        BEGIN:VCALENDAR
        SUMMARY:Hello world
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      actual = Naiveical.Modificator.change_value(ical, "something", "whatever")

      expected =
        """
        BEGIN:VCALENDAR
        SOMETHING:whatever
        SUMMARY:Hello world
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      assert expected == actual
    end

    test "a change with nil" do
      ical =
        """
        BEGIN:VCALENDAR
        SUMMARY:Hello world
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      actual = Naiveical.Modificator.change_value(ical, "something", "")

      expected =
        """
        BEGIN:VCALENDAR
        SUMMARY:Hello world
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

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
        |> String.replace(~r/\r?\n/, "\r\n")

      updated_vtodo = Naiveical.Modificator.change_value(vtodo, "summary", "a new summary")

      assert Naiveical.Extractor.extract_contentline_by_tag(updated_vtodo, "SUMMARY") ==
               {"SUMMARY", "", "a new summary"}
    end
  end

  describe "change multiple values" do
    test "change a list of values" do
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

      tag_values = %{
        summary: "a new summary",
        uuid: "123"
      }

      actual = Naiveical.Modificator.change_values(vtodo, tag_values)

      expected =
        """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:Excalt
        BEGIN:VTODO
        SUMMARY:a new summary
        DTSTART:20221224T1200Z
        DUE:20221224T1200Z
        UUID:123
        DTSTAMP:20221202T1200Z
        END:VTODO
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      assert expected == actual
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

      valarm = Naiveical.Creator.Icalendar.create_valarm("call the ring", "-PT15M")

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

    test "Add todo to calendar" do
      ical_text =
        """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:Excalt
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      todo =
        Naiveical.Creator.Icalendar.create_vtodo("summary", ~D[2023-04-20], "20070313T123432Z",
          uuid: "526b4ae0-df57-11ed-94ec-920434f00633"
        )

      expected =
        """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:Excalt
        BEGIN:VTODO
        SUMMARY:summary
        DTSTAMP:20070313T123432Z
        DUE;VALUE=DATE:20230420
        UUID:526b4ae0-df57-11ed-94ec-920434f00633
        END:VTODO
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      {:ok, actual} = Naiveical.Modificator.insert_into(ical_text, todo, "VCALENDAR")

      assert expected == actual
    end
  end

  describe "Delete" do
    test "simple deletion" do
      ical =
        """
        BEGIN:VCALENDAR
        BEGIN:VTODO
        END:VTODO
        BEGIN:other
        END:other
        BEGIN:VTODO
        END:VTODO
        BEGIN:VTODO
        END:VTODO
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      expected =
        {:ok,
         """
         BEGIN:VCALENDAR
         BEGIN:other
         END:other
         END:VCALENDAR
         """
         |> String.replace(~r/\r?\n/, "\r\n")}

      actual = Naiveical.Modificator.delete_all(ical, "VTODO")

      assert expected == actual
    end
  end

  describe "Add timezone" do
    test "simple timezone" do
      ical =
        """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        DTSTART;TZID=Europe/Berlin:20210422T150000
        END:VEVENT
        BEGIN:VEVENT
        DTSTART;TZID=Europe/Zurich:20221121T114500
        END:VEVENT
        END:VCALENDAR
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      expected =
        {:ok,
         "BEGIN:VCALENDAR\r\nBEGIN:VTIMEZONE\r\nTZID:/citadel.org/20221124_1/Europe/Berlin\r\nLAST-MODIFIED:20221124T144419Z\r\nX-LIC-LOCATION:Europe/Berlin\r\nBEGIN:DAYLIGHT\r\nTZNAME:CEST\r\nTZOFFSETFROM:+0100\r\nTZOFFSETTO:+0200\r\nDTSTART:19700329T020000\r\nRRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\r\nEND:DAYLIGHT\r\nBEGIN:STANDARD\r\nTZNAME:CET\r\nTZOFFSETFROM:+0200\r\nTZOFFSETTO:+0100\r\nDTSTART:19701025T030000\r\nRRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU\r\nEND:STANDARD\r\nEND:VTIMEZONE\r\nBEGIN:VTIMEZONE\r\nTZID:/citadel.org/20221124_1/Europe/Zurich\r\nLAST-MODIFIED:20221124T144419Z\r\nX-LIC-LOCATION:Europe/Zurich\r\nBEGIN:DAYLIGHT\r\nTZNAME:CEST\r\nTZOFFSETFROM:+0100\r\nTZOFFSETTO:+0200\r\nDTSTART:19700329T020000\r\nRRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\r\nEND:DAYLIGHT\r\nBEGIN:STANDARD\r\nTZNAME:CET\r\nTZOFFSETFROM:+0200\r\nTZOFFSETTO:+0100\r\nDTSTART:19701025T030000\r\nRRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU\r\nEND:STANDARD\r\nEND:VTIMEZONEBEGIN:VEVENT\r\nDTSTART;TZID=Europe/Berlin:20210422T150000\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nDTSTART;TZID=Europe/Zurich:20221121T114500\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"}

      actual = Naiveical.Modificator.add_timezone_info(ical)

      assert expected == actual
    end
  end
end
