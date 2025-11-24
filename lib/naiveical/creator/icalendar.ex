defmodule Naiveical.Creator.Icalendar do
  @moduledoc """
  Helper functions to create icalender elements.
  """
  @datetime_format_str "{YYYY}{0M}{0D}T{h24}{m}Z"
  @date_format_str "{YYYY}{0M}{0D}"

  @doc """
  Creates a VCALENDAR object.
  """
  def create_vcalendar(
        method \\ "PUBLISH",
        prod_id \\ "Excalt"
      ) do
    ical =
      """
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:#{prod_id}
      METHOD:#{method}
      END:VCALENDAR
      """
      |> String.replace(~r/\r?\n/, "\r\n")
  end

  @doc """
  Creates a new VEVENT object.
  """
  def create_vevent(
        summary,
        dtstart,
        dtend,
        location \\ "",
        description \\ "",
        class \\ "PUBLIC"
      ) do
    ical =
      """
      BEGIN:VEVENT
      UID:#{Uniq.UUID.uuid1()}
      LOCATION:#{location}
      SUMMARY:#{summary}
      DESCRIPTION:#{description}
      CLASS:#{class}
      DTSTART:#{Timex.format!(dtstart, "{ISO:Basic:Z}")}
      DTEND:#{Timex.format!(dtend, "{ISO:Basic:Z}")}
      DTSTAMP:#{Timex.format!(DateTime.utc_now(), "{ISO:Basic:Z}")}
      END:VEVENT
      """
      |> String.replace(~r/\r?\n/, "\r\n")
  end

  @doc """
  Creates a new VTODO object.
  """
  def create_vtodo(
        summary,
        due,
        dtstamp \\ DateTime.utc_now(),
        opts \\ []
      ) do

    other = ""
    other = other <> if opts[:completed], do: "COMPLETED:#{opts[:completed]}\n", else: ""
    other = other <> if opts[:status], do: "STATUS:#{opts[:status]}\n", else: ""
    other = other <> if opts[:description], do: "DESCRIPTION:#{opts[:description]}\n", else: ""
    other = other <> if opts[:priority], do: "PRIORITY:#{opts[:priority]}\n", else: ""
    other = other <> if opts[:uuid], do: "UUID:#{opts[:uuid]}\n", else: "#{Uniq.UUID.uuid1()}\n"

    other =
      other <>
        if opts[:dtstart],
          do: "DTSTART:#{Timex.format!(opts[:dtstart], @datetime_format_str)}\n",
          else: ""

    dtstamp_str =
      case dtstamp do
        %DateTime{} = dt ->
          # do something with a DateTime value
          "DTSTAMP:#{Timex.format!(dt, "{ISO:Basic:Z}")}\n"

        _ ->
          "DTSTAMP:#{dtstamp}\n"
      end

    due_str =
      case due do
        %Date{} = d ->
          "DUE;VALUE=DATE:#{Date.to_iso8601(d, :basic)}\n"

        %DateTime{} = dt ->
          # do something with a DateTime value
          "DUE:#{Timex.format!(dt, @datetime_format_str)}\n"

        _ ->
          "#{due}\n"
      end

    ical =
      ("""
       BEGIN:VTODO
       SUMMARY:#{summary}
       #{dtstamp_str}
       #{due_str}
       """ <>
         other <>
         """
         END:VTODO
         """)
      |> String.replace(~r/(\r?\n)+/, "\r\n")
  end

  def create_valert(description, %Date{} = date) do
    trigger = Timex.format!(date, @date_format_str)

    """
    BEGIN:VALARM
    ACTION:DISPLAY
    DESCRIPTION:#{description}
    TRIGGER;DATE:#{trigger}
    END:VALARM
    """
    |> String.replace(~r/\r?\n/, "\r\n")
  end

  def create_valert(description, %NaiveDateTime{} = datetime) do
    trigger = DateTime.from_naive!(datetime, "Etc/UTC")
    create_valert(description, trigger)
  end

  def create_valert(description, %DateTime{} = datetime) do
    trigger = Timex.format!(datetime, @datetime_format_str)

    """
    BEGIN:VALARM
    ACTION:DISPLAY
    DESCRIPTION:#{description}
    TRIGGER;DATETIME:#{trigger}
    END:VALARM
    """
    |> String.replace(~r/\r?\n/, "\r\n")
  end

  def create_valarm(description, trigger)
      when is_bitstring(trigger) do
    """
    BEGIN:VALARM
    ACTION:DISPLAY
    DESCRIPTION:#{description}
    TRIGGER:#{trigger}
    END:VALARM
    """
    |> String.replace(~r/\r?\n/, "\r\n")
  end

  def create_valarm(description, trigger) do
    # todo: this is probably not correct
    create_valarm(description, to_string(trigger))
  end

  @doc """
  Build complete VCALENDAR with all components and VTIMEZONEs.

  Creates a fully-formed VCALENDAR object containing:
  - Standard VCALENDAR headers (VERSION, PRODID)
  - Optional X-WR-CALNAME for calendar display name (Apple/Mozilla extension)
  - All VTIMEZONE components (deduplicated by timezone ID)
  - All calendar components (VEVENT, VTODO, etc.)

  ## Parameters

    * `components` - List of calendar component strings (VEVENT, VTODO, etc.)
    * `vtimezones` - Map of timezone ID to VTIMEZONE component strings
    * `displayname` - Optional calendar display name (default: nil)

  ## Returns

  A complete VCALENDAR string with proper CRLF line endings.

  ## Examples

      iex> components = ["BEGIN:VEVENT\\nUID:123\\n...\\nEND:VEVENT"]
      iex> vtimezones = %{"America/New_York" => "BEGIN:VTIMEZONE\\n...\\nEND:VTIMEZONE"}
      iex> build_aggregated_vcalendar(components, vtimezones, "My Calendar")
      "BEGIN:VCALENDAR\\r\\n..."

  """
  def build_aggregated_vcalendar(components, vtimezones, displayname \\ nil) do
    # Build the complete VCALENDAR with all VTIMEZONE components and events
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//ExCaldav//CalDAV Server//EN"
    ]

    # Add X-WR-CALNAME if displayname is provided (Apple/Mozilla extension)
    lines =
      if displayname do
        lines ++ ["X-WR-CALNAME:#{displayname}"]
      else
        lines
      end

    # Add all unique VTIMEZONE components
    vtimezone_lines =
      vtimezones
      |> Map.values()
      |> Enum.map(&String.trim/1)

    # Add all event/todo components
    component_lines =
      components
      # Maintain original order
      |> Enum.reverse()
      |> Enum.map(&String.trim/1)

    # Combine all parts
    all_lines = lines ++ vtimezone_lines ++ component_lines ++ ["END:VCALENDAR"]

    Enum.join(all_lines, "\r\n") <> "\r\n"
  end
end
