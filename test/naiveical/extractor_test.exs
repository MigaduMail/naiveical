defmodule Naiveical.ExtractorTest do
  use ExUnit.Case
  doctest Naiveical.Extractor

  describe "extract section" do
    test "basic vjournal extraction" do
      ical =
        File.read!(Path.expand(Path.join(__DIR__, "files/multiline.ics")))
        |> String.trim()

      expected = [ical]
      actual = Naiveical.Extractor.extract_sections_by_tag(ical, "VJOURNAL")

      assert actual == expected
    end

    test "simple extraction" do
      ical =
        """
        BEGIN:VEVENT
        BEGIN:VALARM
        UID:7D703933-B970-4163-9AD5-12316C02D2BF-1
        END:VALARM
        BEGIN:VALARM
        UID:7D703933-B970-4163-9AD5-12316C02D2BF-2
        END:VALARM
        END:VEVENT
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      expected = [
        "BEGIN:VALARM\nUID:7D703933-B970-4163-9AD5-12316C02D2BF-1\nEND:VALARM"
        |> String.replace(~r/\r?\n/, "\r\n"),
        "BEGIN:VALARM\nUID:7D703933-B970-4163-9AD5-12316C02D2BF-2\nEND:VALARM"
        |> String.replace(~r/\r?\n/, "\r\n")
      ]

      actual = Naiveical.Extractor.extract_sections_by_tag(ical, "VALARM")

      assert actual == expected
    end

    test "basic valarm extraction" do
      ical =
        """
        BEGIN:VEVENT
        DTSTART;TZID=US/Eastern:20060104T100000
        DURATION:PT1H
        SUMMARY:Event #3
        UID:DC6C50A017428C5216A2F1CD@example.com
        BEGIN:VALARM
        ACTION:DISPLAY
        DESCRIPTION:Reminder
        TRIGGER;VALUE=DATE-TIME:20220815T100000Z
        UID:7D703933-B970-4163-9AD5-12316C02D2BF-1
        END:VALARM
        BEGIN:VALARM
        ACTION:DISPLAY
        DESCRIPTION:Reminder
        TRIGGER;VALUE=DATE-TIME:20220816T100000Z
        UID:7D703933-B970-4163-9AD5-12316C02D2BF-2
        END:VALARM
        END:VEVENT
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      expected = [
        "BEGIN:VALARM\nACTION:DISPLAY\nDESCRIPTION:Reminder\nTRIGGER;VALUE=DATE-TIME:20220815T100000Z\nUID:7D703933-B970-4163-9AD5-12316C02D2BF-1\nEND:VALARM"
        |> String.replace(~r/\r?\n/, "\r\n"),
        "BEGIN:VALARM\nACTION:DISPLAY\nDESCRIPTION:Reminder\nTRIGGER;VALUE=DATE-TIME:20220816T100000Z\nUID:7D703933-B970-4163-9AD5-12316C02D2BF-2\nEND:VALARM"
        |> String.replace(~r/\r?\n/, "\r\n")
      ]

      actual = Naiveical.Extractor.extract_sections_by_tag(ical, "VALARM")

      assert actual == expected
    end
  end

  describe "extract attributes" do
    test "no such attribute" do
      attribute_list_str = "A=B;C=D"
      actual = Naiveical.Extractor.extract_attribute(attribute_list_str, "SOMETHING")
      expected = nil
      assert actual == expected
    end

    test "empty attribute" do
      attribute_list_str = ""
      actual = Naiveical.Extractor.extract_attribute(attribute_list_str, "VALUE")
      expected = nil
      assert actual == expected
    end

    test "single attribute" do
      attribute_list_str = "VALUE=DATE-TIME"
      actual = Naiveical.Extractor.extract_attribute(attribute_list_str, "VALUE")
      expected = "DATE-TIME"
      assert actual == expected
    end

    test "multiple attributes" do
      attribute_list_str = "VALUE=DATE-TIME;OTHER=WHATEVER"
      actual = Naiveical.Extractor.extract_attribute(attribute_list_str, "OTHER")
      expected = "WHATEVER"
      assert actual == expected
    end
  end

  describe "extract datetime contentline" do
    test "simple datetime" do
      ical = """
      TRIGGER;VALUE=DATE-TIME:20220816T100000Z
      """

      actual = Naiveical.Extractor.extract_datetime_contentline_by_tag!(ical, "TRIGGER")
      expected = ~U[2022-08-16 10:00:00Z]
      assert actual == expected
    end

    test "with windows datetime" do
      ical = """
      DTSTART;TZID=W. Europe Standard Time:20231205T103000
      """

      actual = Naiveical.Extractor.extract_datetime_contentline_by_tag!(ical, "DTSTART")
      expected = ~U[2022-08-16 10:00:00Z]
      assert actual == expected
    end
  end

  describe "remove sections" do
    test "remove multiple sections" do
      actual =
        Naiveical.Extractor.remove_sections_by_tag(
          "BEGIN:XX\\nBEGIN:YY\\nA:aa\\nB:bb\\nEND:YY\\naaaa:bbbb\\nBEGIN:YY\\nC:cc\\nD:dd\\nEND:YY\\nEND:XX",
          "YY"
        )

      expected = "BEGIN:XX\\naaaa:bbbb\\nEND:XX"
      assert actual == expected
    end
  end
end
