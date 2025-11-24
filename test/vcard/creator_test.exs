defmodule Vcard.CreatorTest do
  use ExUnit.Case, async: true

  @uuid "123456789"

  alias Naiveical.Creator.Vcard

  describe "Creation of VCARD" do
    test "Display name in VCARD only" do
      expected =
        """
        BEGIN:VCARD
        VERSION:4.0
        PRODID:-//Migadu-Excalt//
        UID:#{@uuid}
        FN:Testing Vcard
        END:VCARD
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      raw = Vcard.create_vcard(@uuid, display_name: "Testing Vcard")

      assert expected == raw
    end

    test "Simple VCARD, email, tel, name" do
      expected =
        """
        BEGIN:VCARD
        VERSION:4.0
        PRODID:-//Migadu-Excalt//
        UID:#{@uuid}
        FN:Username Usersurname
        N:;Username;;Usersurname;
        EMAIL:user@example.org
        TEL:123456789
        END:VCARD
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      raw =
        Vcard.create_vcard(@uuid,
          first_name: "Username",
          last_name: "Usersurname",
          email: "user@example.org",
          tel: "123456789"
        )

      assert expected == raw
    end

    test "Create VCARD with options" do
      expected =
        """
        BEGIN:VCARD
        VERSION:4.0
        PRODID:-//Migadu-Excalt//
        UID:#{@uuid}
        FN:Username Usersurname
        N:Prefix;Username;Middle;Usersurname;Suffix
        EMAIL:user@example.org
        TEL:123456789
        ADR:;;Street 01;;;;
        ORG:Example Company
        TITLE:CEO
        NOTE:Some note
        END:VCARD
        """
        |> String.replace(~r/\r?\n/, "\r\n")

      opts = [
        prefix: "Prefix",
        suffix: "Suffix",
        first_name: "Username",
        last_name: "Usersurname",
        suffix: "Suffix",
        middle_name: "Middle",
        address: "Street 01",
        organization: "Example Company",
        title: "CEO",
        note: "Some note",
        tel: "123456789",
        email: "user@example.org"
      ]

      raw = Vcard.create_vcard(@uuid, opts)

      assert expected == raw
    end
  end

  describe "Creation of single components" do
    test "Create email" do
      expected = "EMAIL;TYPE=work:user@example.org\r\n"
      raw = Vcard.create_email("user@example.org", type: "work")
      assert expected == raw
    end

    test "Create email with multiple options" do
      expected = "EMAIL;TYPE=home;PREF=1;OPTION=10;LABEL=private:user@example.org\r\n"

      raw =
        Vcard.create_email("user@example.org",
          type: "home",
          pref: 1,
          option: 10,
          label: "private"
        )

      assert expected == raw
    end

    test "Create address" do
      expected = "ADR;TYPE=work:;;Street 10;City;Region;;Country\r\n"

      raw =
        Vcard.create_address("Street 10",
          city: "City",
          region: "Region",
          country: "Country",
          type: "work"
        )

      assert expected == raw
    end

    test "Create full name, no options" do
      expected = "N:;User;Middle;Surname;\r\n"
      raw = Vcard.create_full_name("", "User", "Middle", "Surname", "")

      assert expected == raw
    end

    test "Full name creation should be empty with no params" do
      expected = ""
      raw = Vcard.create_full_name("", "", "", "", "", [])
      assert expected == raw
    end

    test "Create full name with options" do
      expected = "N;LABEL=goodman;TYPE=type;PARAM=anyparam:;Name;Middle;Surname;\r\n"

      raw =
        Vcard.create_full_name("", "Name", "Middle", "Surname", "",
          label: "goodman",
          type: "type",
          param: "anyparam"
        )

      assert expected == raw
    end

    test "Create categories" do
      expected = "CATEGORIES:test,testing,example\r\n"
      raw = Vcard.create_categories("test,,,,,testing,,,,,,example       ")
      assert expected == raw
    end
  end

  describe "Merge created components with blank VCARD" do
    test "Create blank vcard and merge with email and tel" do
      vcard = Vcard.create_vcard(@uuid)
      email = Vcard.create_email("user@example.org", type: "work", pref: 1)
      tel = Vcard.create_telephone("1234567890", type: "work")

      expected =
        "BEGIN:VCARD\r\nVERSION:4.0\r\nPRODID:-//Migadu-Excalt//\r\nUID:123456789\r\nFN:\r\nEMAIL;TYPE=work;PREF=1:user@example.org\r\nTEL;TYPE=work:1234567890\r\nEND:VCARD\r\n"

      {:ok, raw} = Naiveical.Modificator.insert_into(vcard, email, "VCARD")
      {:ok, raw} = Naiveical.Modificator.insert_into(raw, tel, "VCARD")
      assert expected == raw
    end
  end
end
