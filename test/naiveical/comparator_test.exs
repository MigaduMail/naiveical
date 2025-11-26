defmodule Naiveical.ComparatorTest do
  use ExUnit.Case

  alias Naiveical.Comparator

  describe "equal?" do
    test "equal? returns true when two identical iCal texts are compared" do
      ical_text = "BEGIN:VEVENT\nSUMMARY:Event 1\nDTSTART:20211001T120000Z\nEND:VEVENT\n"
      assert Comparator.equal?(ical_text, ical_text)
    end

    test "equal? returns false when two different iCal texts are compared" do
      ical_text1 = "BEGIN:VEVENT\nSUMMARY:Event 1\nDTSTART:20211001T120000Z\nEND:VEVENT\n"
      ical_text2 = "BEGIN:VTODO\nSUMMARY:Task 1\nDUE:20211001T120000Z\nEND:VTODO\n"
      refute Comparator.equal?(ical_text1, ical_text2)
    end

    test "two different iCal texts are compared, where the difference is excluded" do
      ical_text1 = "BEGIN:VEVENT\nSUMMARY:Event 1\nDTSTART:20211001T120000Z\nEND:VEVENT\n"

      ical_text2 =
        "BEGIN:VEVENT\nCLASS:PUBLIC\nSUMMARY:Event 1\nDTSTART:20211001T120000Z\nEND:VEVENT\n"

      exclude_tags = ["class"]
      assert Comparator.equal?(ical_text1, ical_text2, exclude_tags)
    end

    test "equal? works correctly with excluded tags" do
      ical_text1 = "BEGIN:VEVENT\nSUMMARY:Event 1\nDTSTART:20211001T120000Z\nEND:VEVENT\n"
      ical_text2 = "BEGIN:VEVENT\nSUMMARY:Event 2\nDTSTART:20211001T120000Z\nEND:VEVENT\n"
      exclude_tags = ["SUMMARY"]
      assert Comparator.equal?(ical_text1, ical_text2, exclude_tags)
    end
  end
end
