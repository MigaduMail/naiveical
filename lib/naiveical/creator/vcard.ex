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

  @date_format "{YYYY}{0M}{0D}"
  @vcard_version "4.0"
  @prod_id "-//Migadu-Excalt//"
  @doc """
  Create a simple VCard file.
  VERSION and FN property must be included in vcard object.
  NOTE: in our case, which we are using SabreDav as a Cardav server,
  version and product ID will be overwritten by server itself.
  """
  @spec create_vcard(opts :: Keyword.t()) :: String.t()
  def create_vcard(uuid, opts \\ []) do
    vcard_version = Keyword.get(opts, :vcard_version, @vcard_version)

    first_name = Keyword.get(opts, :first_name, "")
    last_name = Keyword.get(opts, :last_name, "")
    middle_name = Keyword.get(opts, :middle_name, "")
    prefix = Keyword.get(opts, :prefix, "")
    suffix = Keyword.get(opts, :suffix, "")
    email = Keyword.get(opts, :email, "") |> create_email([])
    note = Keyword.get(opts, :note, "") |> create_note([])

    display_name =
      Keyword.get(opts, :display_name, "") |> create_display_name(first_name, last_name)

    tel = Keyword.get(opts, :tel, "") |> create_telephone([])
    addresses = Keyword.get(opts, :address, "") |> create_address([])
    nickname = Keyword.get(opts, :nickname, "") |> create_nickname([])
    title = Keyword.get(opts, :title, "") |> create_title([])
    role = Keyword.get(opts, :role, "") |> create_role([])
    organization = Keyword.get(opts, :organization, "") |> create_organization([])
    website = Keyword.get(opts, :website, "") |> create_website([])
    birthday = Keyword.get(opts, :birthday, "") |> create_special_date(:bday, [])
    anniversary = Keyword.get(opts, :anniversary, "") |> create_special_date(:anniversary, [])
    kind = Keyword.get(opts, :kind, "") |> create_kind([])
    categories = Keyword.get(opts, :categories, "") |> create_categories([])
    name = create_full_name(prefix, first_name, middle_name, last_name, suffix)

    ("""
     BEGIN:VCARD
     VERSION:#{vcard_version}
     PRODID:#{@prod_id}
     UID:#{uuid}
     FN:#{display_name}
     """ <>
       name <>
       email <>
       tel <>
       addresses <>
       nickname <>
       organization <>
       title <>
       role <>
       website <>
       anniversary <>
       birthday <>
       note <>
       categories <>
       kind <>
       """
       END:VCARD
       """)
    |> String.replace(~r/\r?\n/, "\r\n")
  end

  @doc """
  Creates catagories, also know as tags. Categories are comma separated like CSV.
  Can be used to group vcards.
  Reference [RFC 6350 Section 6.7.1](https://www.rfc-editor.org/rfc/rfc6350#section-6.7.1)
  """
  @spec create_categories(categories :: String.t(), opts :: List.t()) :: String.t()
  def create_categories(categories, opts \\ [])
  def create_categories("", _), do: ""

  def create_categories(categories, []),
    do: "CATEGORIES:" <> trim_categories(categories) <> "\r\n"

  def create_categories(categories, opts) do
    categories = trim_categories(categories)

    params =
      Enum.reduce(opts, "CATEGORIES", fn {key, value}, acc ->
        key = upcase_key(key)
        acc <> ";#{key}=#{value}"
      end)

    params <> ":#{categories}\r\n"
  end

  @doc """
  Simple note to add more information about the VCARD.
  Reference [RFC 6350 Section 6.7.2](https://www.rfc-editor.org/rfc/rfc6350#section-6.7.2)
  """
  def create_note(note, opts \\ [])
  def create_note("", _), do: ""

  def create_note(note, []) do
    note = Naiveical.Helpers.fold(note)
    "NOTE:#{note}\r\n"
  end

  def create_note(note, opts) do
    note = Naiveical.Helpers.fold(note)

    params =
      Enum.reduce(opts, "NOTE", fn {key, value}, acc ->
        key = upcase_key(key)
        acc <> ";#{key}=#{value}"
      end)

    params <> ":#{note}\r\n"
  end

  @doc """
  Creates NICKNAME, can be random text.
  """
  @spec create_nickname(nickname :: String.t(), opts :: List.t()) :: String.t()
  def create_nickname(nickname, opts \\ [])
  def create_nickname("", _), do: ""
  def create_nickname(nickname, _), do: "NICKNAME:#{nickname}\r\n"

  @doc """
  Creates TITLE, it is most often associated with organization.
  """
  @spec create_title(nickname :: String.t(), opts :: List.t()) :: String.t()
  def create_title(title, opts \\ [])
  def create_title("", _), do: ""
  def create_title(title, _), do: "TITLE:#{title}\r\n"

  @doc """
  Creates ROLE, it is most often associated with organization.
  """
  @spec create_role(nickname :: String.t(), opts :: List.t()) :: String.t()
  def create_role(role, opts \\ [])
  def create_role("", _), do: ""
  def create_role(role, _), do: "ROLE:#{role}\r\n"

  @doc """
  Creates organization.
  """
  @spec create_organization(nickname :: String.t(), opts :: List.t()) :: String.t()
  def create_organization(org, opts \\ [])
  def create_organization("", _), do: ""
  def create_organization(org, _), do: "ORG:#{org}\r\n"

  @doc """
  Creates special dates such as birthdays or anniversary.
  """
  @spec create_special_date(nickname :: String.t(), opts :: List.t()) :: String.t()
  def create_special_date(date, type, opts \\ [])
  def create_special_date("", _, _), do: ""

  def create_special_date(%Date{} = date, type, []) when not is_nil(date) do
    date = Timex.format!(date, @date_format)
    type = upcase_key(type)
    "#{type}:#{date}"
  end

  @doc """
  Creates a KIND for vcard.
  Please refer to [RFC Section 6.1.4](https://www.rfc-editor.org/rfc/rfc6350#section-6.1.4)
  """
  @spec create_kind(nickname :: String.t(), opts :: List.t()) :: String.t()
  def create_kind(kind, opts \\ [])
  def create_kind("", _), do: ""

  def create_kind(kind, opts) do
    params =
      Enum.reduce(opts, "KIND", fn {key, value}, acc ->
        key = upcase_key(key)
        acc <> ";#{key}=#{value}"
      end)

    params <> ":#{kind}\r\n"
  end

  @doc """
  Creates an email to put in VCARD file.
  Pass a keyword list of params(options) to add params to email address you are creating.
  Please refer the [RFC 6350 Section 6.4.2](https://www.rfc-editor.org/rfc/rfc6350#section-6.4.2) for more details about the supported params.

  ## Example
      iex> Naiveical.Creator.Vcard.create_email("email@domain.tld", type: "work", pref: 1, label: "good")
      EMAIL;TYPE=work;PREF=1;LABEL=good:email@domain.tld
  """
  @spec create_email(address :: String.t(), opts :: List.t()) :: String.t()
  def create_email(address, opts \\ [])
  def create_email("", []), do: ""
  def create_email(address, []), do: "EMAIL:#{address}\r\n"

  def create_email(address, opts) do
    params =
      Enum.reduce(opts, "EMAIL", fn {key, val}, acc ->
        key = upcase_key(key)
        acc <> ";#{key}=#{val}"
      end)

    params <> ":#{address}\r\n"
  end

  @doc """
  Creates display name, which is FN property defined by [RFC 6350 Section 6.2.1](https://www.rfc-editor.org/rfc/rfc6350#section-6.2.1)

  ## Example
      iex> Naiveical.Creator.Vcard.create_display_name("Display Name")
      "Display Name"
  """
  def create_display_name(display_name \\ "", first_name \\ "", last_name \\ "") do
    if display_name != "" do
      display_name
    else
      "#{first_name} #{last_name}"
    end
    |> String.trim()
  end

  @doc """
  Creates address property. Address property has 7 list-components, where first two are ommited.
  Please refer to [RFC 6350 Section 6.3.1](https://www.rfc-editor.org/rfc/rfc6350#section-6.3.1)
  """
  @spec create_address(address :: String.t(), opts :: List.t()) :: String.t()
  def create_address(address, opts \\ [])
  def create_address("", []), do: ""
  def create_address(address, []), do: "ADR:;;#{address};;;;\r\n"

  def create_address(address, opts) do
    Enum.reduce(opts, "ADR", fn {key, val}, acc ->
      # this is check whether the key is not an address component
      if key not in [:street, :city, :region, :postal_code, :country] do
        key = upcase_key(key)
        acc <> ";#{key}=#{val}"
      else
        acc
      end
    end)
    |> add_addresses(address, opts)
  end

  @doc """
  Creates URL property.
  Reference [RFC 6350 Section 6.7.8](https://www.rfc-editor.org/rfc/rfc6350#section-6.7.8)
  ## Example
      iex> Naiveical.Creator.Vcard.create_website("https://example.org", type: "work")
      URL;TYPE=work:https://example.org\r\n
  """
  @spec create_website(url :: String.t(), opts :: List.t()) :: String.t()
  def create_website(url, opts \\ [])
  def create_website("", []), do: ""
  def create_website(url, []), do: "URL:#{url}\r\n"

  def create_website(url, opts) do
    params =
      Enum.reduce(opts, "URL", fn {key, value}, acc ->
        key = upcase_key(key)
        acc <> ";#{key}=#{value}"
      end)

    params <> ":#{url}\r\n"
  end

  @doc """
  Creates a full name for VCARD.
  N property consist of 5 list-components.
  N:PREFIX;FIRSTNAME;MIDDLENAME;LASTNAME;SUFFIX
  Reference[RFC Idenitification Properties N SECTION 6.2.2](https://www.rfc-editor.org/rfc/rfc6350#section-6.2.2)
  ## Example
      iex> Naiveical.Creator.Vcard.create_full_name("", "User", "Middle", "Surname", "", value: "text")
      N;VALUE=text:;User;Middle;Surname;;
  """
  @spec create_full_name(
          prefix :: String.t(),
          first_name :: String.t(),
          middle_name :: String.t(),
          last_name :: String.t(),
          suffix :: String.t(),
          opts :: List.t()
        ) :: String.t()
  def create_full_name(prefix, first_name, middle_name, last_name, suffix, opts \\ [])

  def create_full_name(prefix, first_name, middle_name, last_name, suffix, []) do
    if should_construct_full_name?([prefix, first_name, middle_name, last_name, suffix]) do
      "N" <> construct_full_name(prefix, first_name, middle_name, last_name, suffix)
    else
      ""
    end
  end

  def create_full_name(prefix, first_name, middle_name, last_name, suffix, opts) do
    params =
      Enum.reduce(opts, "N", fn {key, value}, acc ->
        key = upcase_key(key)
        acc <> ";#{key}=#{value}"
      end)

    if should_construct_full_name?([prefix, first_name, middle_name, last_name, suffix]) do
      params <> construct_full_name(prefix, first_name, middle_name, last_name, suffix)
    else
      ""
    end
  end

  @doc """
  Creates telephone property for VCARD.
  Reference [RFC Section 6.4.1](https://www.rfc-editor.org/rfc/rfc6350#section-6.4.1)
  ## Example
      iex> Naiveical.Creator.Vcard.create_telephone("1234567890", type: "work", pref: 1)
      TEL;TYPE=work;PREF=1:1234567890
  """
  @spec create_telephone(tel :: String.t(), opts :: List.t()) :: String.t()
  def create_telephone(tel, opts \\ [])
  def create_telephone("", _), do: ""
  def create_telephone(tel, []), do: "TEL:#{tel}\r\n"

  def create_telephone(tel, opts) do
    params =
      Enum.reduce(opts, "TEL", fn {key, value}, acc ->
        key = upcase_key(key)
        acc <> ";#{key}=#{value}"
      end)

    params <> ":#{tel}\r\n"
  end

  ### Helpers for creation functions. ###

  defp add_addresses(address_comp, address, opts) do
    # We need to take care of the places for the address component
    # street;city;region;code;country
    city = Keyword.get(opts, :city, "")
    region = Keyword.get(opts, :region, "")
    postal_code = Keyword.get(opts, :postal_code, "")
    country = Keyword.get(opts, :country, "")

    "#{address_comp}:;;#{address};#{city};#{region};#{postal_code};#{country}\r\n"
  end

  defp should_construct_full_name?(name_comps) do
    Enum.any?(name_comps, fn x -> x != "" end)
  end

  defp construct_full_name(prefix, first_name, middle_name, last_name, suffix) do
    if should_construct_full_name?([prefix, first_name, middle_name, last_name, suffix]) do
      ":#{prefix};#{first_name};#{middle_name};#{last_name};#{suffix}\r\n"
    else
      ""
    end
  end

  defp trim_categories(categories) do
    categories
    |> String.split(",")
    |> Enum.reject(&(&1 == "" or is_nil(&1)))
    |> Enum.map_join(",", &String.trim/1)
  end

  defp upcase_key(key) do
    key
    |> to_string()
    |> String.upcase()
  end
end
