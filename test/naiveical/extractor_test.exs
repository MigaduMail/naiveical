defmodule Naiveical.ExtractorTest do
  use ExUnit.Case
  doctest Naiveical.Extractor

  describe "extract section" do
    test "basic vjournal extraction" do
      ical = File.read!(Path.expand(Path.join(__DIR__, "files/multiline.ics")))
      expected = [ical]
      actual = Naiveical.Extractor.extract_sections_by_tag(ical, "VJOURNAL")

      assert actual == expected
    end

    test "basic valarm extraction" do
      ical = """
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

      expected = [
        "BEGIN:VALARM\nACTION:DISPLAY\nDESCRIPTION:Reminder\nTRIGGER;VALUE=DATE-TIME:20220815T100000Z\nUID:7D703933-B970-4163-9AD5-12316C02D2BF-1\nEND:VALARM",
        "BEGIN:VALARM\nACTION:DISPLAY\nDESCRIPTION:Reminder\nTRIGGER;VALUE=DATE-TIME:20220816T100000Z\nUID:7D703933-B970-4163-9AD5-12316C02D2BF-2\nEND:VALARM"
      ]

      actual = Naiveical.Extractor.extract_sections_by_tag(ical, "VALARM")

      assert actual == expected
    end
  end
end
