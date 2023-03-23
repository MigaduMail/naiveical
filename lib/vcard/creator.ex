defmodule Naiveical.Vcard.Creator do
  @moduledoc """
  Module for creating Vcard(vcf) text files.
  """

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

  @doc """
  Create a simple VCard file.
  VERSION and FN property must be included in vcard object.
  NOTE: in our case, which we are using SabreDav as a Cardav server,
  version and product ID will be overwritten by server itself.
  """
  @spec create_vcard(opts :: Keyword.t()) :: String.t()
  def create_vcard(opts \\ []) do
    uid = UUID.uuid4()
    full_name = Keyword.get(opts, :fn)
    emails = extract_additional_properties(opts, :email)
    tel = extract_additional_properties(opts, :tel)
    addresses = extract_additional_properties(opts, :adrs)
    nickname = Keyword.get(opts, :nickname)

    ("""
      BEGIN:VCARD
      VERSION:#{@vcard_version}
      UID:#{uid}
      FN:#{full_name}
     """ <>
       nickname <>
       emails <>
       tel <>
       addresses <>
       """
       END:VCARD
       """)
    |> String.replace(~r/\r?\n/, "\r\n")
  end

  def extract_additional_properties(opts, property, additional_properties \\ "")

  def extract_additional_properties(opts, :email, additional_properties) do
    if Keyword.has_key?(opts, :email) do
      Keyword.get_values(opts, :email)
      |> extract_emails()
    else
      additional_properties
    end
  end

  def extract_additional_properties(opts, :tel, additional_properties) do
    if Keyword.has_key?(opts, :tel) do
      opts
      |> Keyword.get_values(:tel)
      |> extract_telephones()
    else
      additional_properties
    end
  end

  def extract_additional_properties(opts, :adrs, additional_properties) do
    if Keyword.has_key?(opts, :adrs) do
      opts
      |> Keyword.get_values(:adrs)
      |> extract_address()
    else
      additional_properties
    end
  end

  # Expect a list of values, [%{type: "type", value: val}]
  defp extract_emails(emails) do
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

  defp extract_telephones(tel) do
    tel
    |> Enum.map_join(fn %{type: type, value: val} ->
      if is_nil(type) do
        "TEL:#{val}\r\n"
      else
        "TEL;TYPE=#{type}:#{val}\r\n"
      end
    end)
  end

  defp extract_addresses(addresses) do
    addreses
    |> Enum.map_join(fn %{type: type, street: street, locality: locality, region: region, zip_code: zip_code, country: country} = c ->
      comp = make_single_address_comp(c)
      if is_nil(type) do
        "ADR:;;#{comp}"
      else

      end
     end)
  end

# %{type: type, street: street, locality: locality, region: region, zip_code: zip_code, country: country}
  defp make_single_address_comp(c) do
    comp = ""
    comp = if is_nil(c.street), do: ";", else:
   end

  # By rfc first two components in ADR propery are ommited.
 end

defp extract_websites(opts) do
end
