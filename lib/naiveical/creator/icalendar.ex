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
end
