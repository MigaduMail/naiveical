defmodule Naiveical do
  @moduledoc """
  Public façade of the core Naiveical helpers so users can stay at `Naiveical` instead of digging
  through nested namespaces.

  ## Calendar builders
  - `create_vcalendar/0-2`
  - `create_vevent/6`
  - `create_vtodo/3-4`
  - `create_valert/2`
  - `create_valarm/2`
  - `build_aggregated_vcalendar/3`

  ## VCARD builders
  - `create_vcard/2`
  - `create_categories/2`
  - `create_note/2`
  - `create_nickname/2`
  - `create_title/2`
  - `create_role/2`
  - `create_organization/2`
  - `create_special_date/3`
  - `create_kind/2`
  - `create_email/2`
  - `create_display_name/3`
  - `create_address/2`
  - `create_website/2`
  - `create_full_name/6`
  - `create_telephone/2`

  ## Mutation helpers
  - `insert_into/3-4`
  - `change_value/3`
  - `change_values/2`
  - `delete_all/2`
  - `delete_all!/2`
  - `add_timezone_info/1`

  ## Extraction helpers
  - `extract_sections_by_tag/2`
  - `remove_sections_by_tag/2`
  - `extract_contentline_by_tag/2`
  - `extract_raw_contentline_by_tag/2`
  - `extract_datetime_contentline_by_tag/2`
  - `extract_datetime_contentline_by_tag!/2`
  - `extract_date_contentline_by_tag/2`
  - `extract_date_contentline_by_tag!/2`
  - `extract_attribute/2`
  - `detect_component_type/1`

  ## Text and date helpers
  - `unfold/1`
  - `fold/1-2`
  - `parse_datetime/1-2`
  - `parse_datetime!/1-2`
  - `parse_date/1`
  - `parse_date!/1`
  - `is_fullday/2`
  - `parse_icalendar_datetime/1`
  - `parse_icalendar_datetime!/1`
  - `format_icalendar_datetime/1`
  - `format_icalendar_date/1`
  - `parse_icalendar_date/1`
  - `parse_icalendar_date!/1`
  """

  alias Naiveical.Creator.{Icalendar, Vcard}
  alias Naiveical.{Extractor, Helpers, Modificator}

  ## Calendar builders
  defdelegate create_vcalendar(method \\ "PUBLISH", prod_id \\ "Excalt"), to: Icalendar

  defdelegate create_vevent(
                summary,
                dtstart,
                dtend,
                location \\ "",
                description \\ "",
                class \\ "PUBLIC"
              ),
              to: Icalendar

  defdelegate create_vtodo(summary, due, dtstamp \\ DateTime.utc_now(), opts \\ []), to: Icalendar
  defdelegate create_valert(description, trigger), to: Icalendar
  defdelegate create_valarm(description, trigger), to: Icalendar

  defdelegate build_aggregated_vcalendar(components, vtimezones, displayname \\ nil),
    to: Icalendar

  ## VCARD builders
  defdelegate create_vcard(uuid, opts \\ []), to: Vcard
  defdelegate create_categories(categories, opts \\ []), to: Vcard
  defdelegate create_note(note, opts \\ []), to: Vcard
  defdelegate create_nickname(nickname, opts \\ []), to: Vcard
  defdelegate create_title(title, opts \\ []), to: Vcard
  defdelegate create_role(role, opts \\ []), to: Vcard
  defdelegate create_organization(org, opts \\ []), to: Vcard
  defdelegate create_special_date(date, type, opts \\ []), to: Vcard
  defdelegate create_kind(kind, opts \\ []), to: Vcard
  defdelegate create_email(address, opts \\ []), to: Vcard

  defdelegate create_display_name(display_name \\ "", first_name \\ "", last_name \\ ""),
    to: Vcard

  defdelegate create_address(address, opts \\ []), to: Vcard
  defdelegate create_website(url, opts \\ []), to: Vcard

  defdelegate create_full_name(prefix, first_name, middle_name, last_name, suffix, opts \\ []),
    to: Vcard

  defdelegate create_telephone(tel, opts \\ []), to: Vcard

  ## Mutation helpers
  defdelegate insert_into(ical_text, new_content, element, opts \\ []), to: Modificator
  defdelegate change_value(ical_text, tag, new_value), to: Modificator
  defdelegate change_values(ical_text, tag_values), to: Modificator
  defdelegate delete_all(ical_text, tag), to: Modificator
  defdelegate delete_all!(ical_text, tag), to: Modificator
  defdelegate add_timezone_info(ical_text), to: Modificator

  ## Extraction helpers
  defdelegate extract_sections_by_tag(ical_text, tag), to: Extractor
  defdelegate remove_sections_by_tag(ical_text, tag), to: Extractor
  defdelegate extract_contentline_by_tag(ical_text, tag), to: Extractor
  defdelegate extract_raw_contentline_by_tag(ical_text, tag), to: Extractor
  defdelegate extract_datetime_contentline_by_tag(ical_text, tag), to: Extractor
  defdelegate extract_datetime_contentline_by_tag!(ical_text, tag), to: Extractor
  defdelegate extract_date_contentline_by_tag(ical_text, tag), to: Extractor
  defdelegate extract_date_contentline_by_tag!(ical_text, tag), to: Extractor
  defdelegate extract_attribute(attribute_list_str, attr), to: Extractor
  defdelegate detect_component_type(ical_data), to: Extractor

  ## Text and date helpers
  defdelegate unfold(ical_text), to: Helpers
  defdelegate fold(line, max_size \\ 75), to: Helpers
  defdelegate parse_datetime(datetime_str), to: Helpers
  defdelegate parse_datetime!(datetime_str), to: Helpers
  defdelegate parse_datetime(datetime_str, timezone), to: Helpers
  defdelegate parse_datetime!(datetime_str, timezone), to: Helpers
  defdelegate parse_date(date_str), to: Helpers
  defdelegate parse_date!(date_str), to: Helpers
  defdelegate is_fullday(attributes, datetime_str), to: Helpers
  defdelegate parse_icalendar_datetime(datetime_str), to: Helpers
  defdelegate parse_icalendar_datetime!(datetime_str), to: Helpers
  defdelegate format_icalendar_datetime(datetime), to: Helpers
  defdelegate format_icalendar_date(date), to: Helpers
  defdelegate parse_icalendar_date(date_str), to: Helpers
  defdelegate parse_icalendar_date!(date_str), to: Helpers
end
