defmodule Naiveical.Creator.Vcard do
  @moduledoc """
  Module for creating Vcard(vcf) text files.
  """

  ### This VCARD is generated trought the Thunderbird UI
  ### Which I took as an inspiration for the fields.
  # VCARD Example
  # BEGIN:VCARD
  # VERSION:3.0
  # PRODID:-//Sabre//Sabre VObject 4.3.0//EN
  # N:Name;Surname ;;;
  # FN:Surname  Name
  # NICKNAME:Nickkontakt
  # EMAIL;TYPE=PREF,work;PREF=1:work@klasik.com
  # TEL;TYPE=work:060111111111
  # NOTE:Some notes
  # URL;TYPE=home:https://klasik.com
  # TITLE:Ceo
  # ROLE:Ceo
  # ORG:Company;Department
  # BDAY;VALUE=DATE:19950324
  # UID:688819b9-75ca-42ea-a517-b6ba205274d8
  # URL;TYPE=work:https://klasik.com
  # URL;TYPE=work:https://klasik.com
  # URL;TYPE=work:https://klasik.com
  # ADR;TYPE=work:;;Address 1;City;State/Province;11000;Serbia
  # ADR:;;Address 2;City 2;State 2;159999;Serbia
  # END:VCARD

  ### SOME BASIC FIELDS TO SUPPORT FOR START ###

  # FN consist of PREFIX, FIRSTNAME, MIDDLE NAME, SURNAME, SUFFIX

  # N consist of 4 list-components, e.g. N: PREFIX;Firstname;surname,someval;Middlename;suffix

  # EMAIL: can have more than one on single vcard object, TYPE param can be defined as EMAIL;TYPE=WORK;TYPE=PERSONAL, or as a csv list TYPE="work,personal"
  # if there are more than one email set, PREF paramater can be used to indicate a preffered email address.

  # TEL: TYPE parameters [text, voice, cell, fax, video, pager, textphone]

  # BDAY: Birtday in simple date format 19930101

  # NOTE: TExt value, if the text is longer than 75 octets, should be folded

  # NICKNAME: Some text value for nickname

  # KIND: Basically the identifier of contact(org, individual, group, location)
  # E.g if the KIND value is location, VCARD object must contain informations only for that location
  # it can contain some name, for e.g Zurich, if GEO property is not present, this will be considered as
  # "abstract" location
  # For more info https://www.rfc-editor.org/rfc/rfc6350.html#section-6.1.4

  # CATEGORIES: Specify application category information about VCARD (CSV tags)

  # UID: We are responsible for giving the new vcard object UID
  #
  # URL: TYPE [work, home], for websites
  #
  # ADR: Special notes:  The structured type value consists of a sequence of
  #    address components.  The component values MUST be specified in
  #    their corresponding position.  The structured type value
  #    corresponds, in sequence, to
  #       the post office box;
  #       the extended address (e.g., apartment or suite number);
  #       the street address;
  #       the locality (e.g., city);
  #       the region (e.g., state or province);
  #       the postal code;
  #       the country name (full name in the language specified in
  #       Section 5.1).

  #    When a component value is missing, the associated component
  #    separator MUST still be specified.

  #    Experience with vCard 3 has shown that the first two components
  #    (post office box and extended address) are plagued with many
  #    interoperability issues.  To ensure maximal interoperability,
  #    their values SHOULD be empty.

  #    The text components are separated by the SEMICOLON character
  #    (U+003B).  Where it makes semantic sense, individual text
  #    components can include multiple text values (e.g., a "street"
  #    component with multiple lines) separated by the COMMA character
  #   (U+002C).

  #

  @date_format "{YYYY}{0M}{0D}"
  @vcard_version "3.0"
  @prod_id "-//Migadu-Excalt//"
  @doc """
  Create a simple VCard file.
  VERSION and FN property must be included in vcard object.
  NOTE: in our case, which we are using SabreDav as a Cardav server,
  version and product ID will be overwritten by server itself.
  """
  @spec create_vcard(opts :: Keyword.t()) :: String.t()
  def create_vcard(opts \\ []) do
    uid = UUID.uuid4()
    full_name = Keyword.get(opts, :fn, "")
    emails = get_additional_properties(opts, :email)
    tel = get_additional_properties(opts, :tel)
    addresses = get_additional_properties(opts, :addrs)
    nickname = Keyword.get(opts, :nickname, "")
    title = Keyword.get(opts, :title, "")
    role = Keyword.get(opts, :role, "")
    org = Keyword.get(opts, :org, "")
    websites = get_additional_properties(opts, :websites)
    bday = get_bday(opts)
    kind = Keyword.get(opts, :kind, "")

    ("""
     BEGIN:VCARD
     VERSION:#{@vcard_version}
     PRODID:#{@prod_id}
     UID:#{uid}
     FN:#{full_name}
     """ <>
       nickname <>
       emails <>
       tel <>
       addresses <>
       title <>
       role <>
       org <>
       websites <>
       bday <>
       kind <>
       """
       END:VCARD
       """)
    |> String.replace(~r/\r?\n/, "\r\n")
  end

  def get_additional_properties(opts, property, default \\ "")

  def get_additional_properties(opts, :email, default) do
    if Keyword.has_key?(opts, :email) do
      Keyword.get_values(opts, :email)
      |> get_emails()
    else
      default
    end
  end

  def get_additional_properties(opts, :tel, default) do
    if Keyword.has_key?(opts, :tel) do
      opts
      |> Keyword.get_values(:tel)
      |> get_telephones()
    else
      default
    end
  end

  def get_additional_properties(opts, :addrs, default) do
    if Keyword.has_key?(opts, :addrs) do
      opts
      |> Keyword.get_values(:addrs)
      |> get_addresses
    else
      default
    end
  end

  def get_additional_properties(opts, :websites, default) do
    if Keyword.has_key?(opts, :websites) do
      opts
      |> Keyword.get_values(:websites)
      |> get_websites
    else
      default
    end
  end

  # Expect a list of values, [%{type: "type", value: val}]
  defp get_emails(emails) do
    emails
    |> Enum.map_join(fn %{type: type, value: val} ->
      # responsibility for validations of the user input should be on the client side.
      if is_nil(type) do
        "EMAIL:#{val}\r\n"
      else
        "EMAIL;TYPE=#{type}:#{val}\r\n"
      end
    end)
  end

  defp get_telephones(tel) do
    tel
    |> Enum.map_join(fn %{type: type, value: val} ->
      if is_nil(type) do
        "TEL:#{val}\r\n"
      else
        "TEL;TYPE=#{type}:#{val}\r\n"
      end
    end)
  end

  defp get_websites(websites) do
    websites
    |> Enum.map_join(fn %{type: type, value: val} ->
      if is_nil(type) do
        "URL:#{val}"
      else
        "URL;TYPE=#{type}:#{val}"
      end
    end)
  end

  defp get_bday(opts) do
    value = Keyword.get(opts, :bday, nil)

    if is_nil(value) do
      ""
    else
      value = Timex.format!(value, @date_format)
      "BDAY;VALUE=DATE:#{value}"
    end
  end

  defp get_addresses(addresses) do
    addresses
    |> Enum.map_join(fn %{
                          type: type
                        } = c ->
      comp = make_single_address_comp(c)

      if is_nil(type) do
        "ADR:;;#{comp}"
      else
        "ADR;TYPE=#{type};;#{comp}"
      end
    end)
  end

  #  %{type: type, street: street, city: city, region: region, zip_code: zip_code, country: country}
  defp make_single_address_comp(c) do
    street = Map.get(c, :street, nil)
    city = Map.get(c, :city, nil)
    region = Map.get(c, :region, nil)
    zip_code = Map.get(c, :zip_code, nil)
    country = Map.get(c, :country, nil)

    [street, city, region, zip_code, country]
    |> Enum.map_join(fn c ->
      if is_nil(c) do
        ";"
      else
        "#{c};"
      end
    end)
  end

  # By rfc first two components in ADR propery are ommited.
end
