# Naiveical

With naiveical you can extract parts of an icalendar file and update individual
lines. It does not parse the icalendar but rather works directly with pure text. 
As such it does not prevent you from doing stupid things, such as embedding 
elements into each other that have no meaning.

The advantage of this approach is to keep the icalendar text as close to the
original as possible, with only modifying the changed parts. 

## Installation

The package [available in Hex](https://hex.pm/packages/naiveical) and can be installed
by adding `naiveical` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:naiveical, "~> 0.1.0"}
  ]
end
```

## Documentation

Available at [HexDocs](https://hexdocs.pm/naiveical).

## Example

Create a new vcalendar:

``` elixir
ical = Naiveical.Creator.create_vcalendar()
```

Create a new vtodo:

``` elixir
dtstart = DateTime.now!("Etc/UTC")
due = DateTime.now!("Etc/UTC")
todo = Naiveical.Creator.create_vtodo("vtodo example", dtstart, due)
```

Create a new valert:

``` elixir
alarm = Naiveical.Creator.create_valarm("Ring the bell", "-PT15M")
```

Assemble the tree together:

``` elixir
      {:ok, todo} = Naiveical.Modificator.insert_into(todo, alarm, "VTODO")
      {:ok, ical} = Naiveical.Modificator.insert_into(ical, todo, "VCALENDAR")
```

Change the summary

``` elixir
      updated_ical = Naiveical.Modificator.change_value(ical, "summary", "my updated summary")
```

## VTIMEZONE database
The VTIMEZONE database has been compiled by using the [vzic utility](https://github.com/libical/vzic).

## Rationale

The difficulty in parsing the icalendar format is that it is difficult to write a library that can parse and re-create the icalendar
file without any data loss. As such it is best to keep the original icalendar file and work directly on the file. This makes working
with the access of the individual fields more complicated but keeps the original file intact.
