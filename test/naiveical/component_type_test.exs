defmodule Naiveical.ComponentTypeTest do
  use ExUnit.Case

  # Assuming this function will be in Naiveical.Extractor or similar module
  # Update the module name as needed
  alias Naiveical.Extractor

  describe "detect_component_type/1" do
    test "detects VFREEBUSY component" do
      ical_data = """
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:-//Example Corp//NONSGML Event Calendar//EN
      BEGIN:VFREEBUSY
      ORGANIZER:mailto:jane_doe@example.com
      DTSTART:20060103T180000Z
      DTEND:20060104T070000Z
      DTSTAMP:20050530T123421Z
      FREEBUSY:20060103T180000Z/PT3H
      END:VFREEBUSY
      END:VCALENDAR
      """

      assert Extractor.detect_component_type(ical_data) == :vfreebusy
    end

    test "detects VTODO component" do
      ical_data = """
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:-//Example Corp//NONSGML Event Calendar//EN
      BEGIN:VTODO
      UID:20070313T123432Z-456553@example.com
      DTSTAMP:20070313T123432Z
      DUE;VALUE=DATE:20070501
      SUMMARY:Submit Quebec Income Tax Return for 2006
      STATUS:NEEDS-ACTION
      END:VTODO
      END:VCALENDAR
      """

      assert Extractor.detect_component_type(ical_data) == :vtodo
    end

    test "detects VJOURNAL component" do
      ical_data = """
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:-//Example Corp//NONSGML Event Calendar//EN
      BEGIN:VJOURNAL
      UID:19970901T130000Z-123405@example.com
      DTSTAMP:19970901T130000Z
      DTSTART;VALUE=DATE:19970317
      SUMMARY:Staff meeting minutes
      DESCRIPTION:1. Staff meeting: Participants include Joe\\, Lisa\\, and Bob. Aurora project plans were reviewed.
      END:VJOURNAL
      END:VCALENDAR
      """

      assert Extractor.detect_component_type(ical_data) == :vjournal
    end

    test "detects VEVENT component" do
      ical_data = """
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:-//Example Corp//NONSGML Event Calendar//EN
      BEGIN:VEVENT
      UID:19970901T130000Z-123401@example.com
      DTSTAMP:19970901T130000Z
      DTSTART:19970903T163000Z
      DTEND:19970903T190000Z
      SUMMARY:Annual Employee Review
      END:VEVENT
      END:VCALENDAR
      """

      assert Extractor.detect_component_type(ical_data) == :vevent
    end

    test "defaults to VEVENT when no specific component found" do
      ical_data = """
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:-//Example Corp//NONSGML Event Calendar//EN
      END:VCALENDAR
      """

      assert Extractor.detect_component_type(ical_data) == :vevent
    end

    test "prioritizes VFREEBUSY over other components when multiple present" do
      ical_data = """
      BEGIN:VCALENDAR
      VERSION:2.0
      BEGIN:VEVENT
      SUMMARY:Some Event
      END:VEVENT
      BEGIN:VFREEBUSY
      FREEBUSY:20060103T180000Z/PT3H
      END:VFREEBUSY
      END:VCALENDAR
      """

      assert Extractor.detect_component_type(ical_data) == :vfreebusy
    end

    test "prioritizes VTODO over VJOURNAL and VEVENT when VFREEBUSY absent" do
      ical_data = """
      BEGIN:VCALENDAR
      VERSION:2.0
      BEGIN:VJOURNAL
      SUMMARY:Some Journal
      END:VJOURNAL
      BEGIN:VTODO
      SUMMARY:Some Todo
      END:VTODO
      BEGIN:VEVENT
      SUMMARY:Some Event
      END:VEVENT
      END:VCALENDAR
      """

      assert Extractor.detect_component_type(ical_data) == :vtodo
    end

    test "prioritizes VJOURNAL over VEVENT when VFREEBUSY and VTODO absent" do
      ical_data = """
      BEGIN:VCALENDAR
      VERSION:2.0
      BEGIN:VEVENT
      SUMMARY:Some Event
      END:VEVENT
      BEGIN:VJOURNAL
      SUMMARY:Some Journal
      END:VJOURNAL
      END:VCALENDAR
      """

      assert Extractor.detect_component_type(ical_data) == :vjournal
    end

    test "handles minimal VFREEBUSY data" do
      ical_data = "BEGIN:VFREEBUSY"
      assert Extractor.detect_component_type(ical_data) == :vfreebusy
    end

    test "handles minimal VTODO data" do
      ical_data = "BEGIN:VTODO"
      assert Extractor.detect_component_type(ical_data) == :vtodo
    end

    test "handles minimal VJOURNAL data" do
      ical_data = "BEGIN:VJOURNAL"
      assert Extractor.detect_component_type(ical_data) == :vjournal
    end

    test "handles minimal VEVENT data" do
      ical_data = "BEGIN:VEVENT"
      assert Extractor.detect_component_type(ical_data) == :vevent
    end

    test "handles empty string defaults to VEVENT" do
      assert Extractor.detect_component_type("") == :vevent
    end

    test "case sensitive matching - lowercase begin tag defaults to VEVENT" do
      ical_data = "begin:vevent"
      assert Extractor.detect_component_type(ical_data) == :vevent
    end
  end
end
