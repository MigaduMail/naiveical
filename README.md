# Naiveical

Naiveical lets you create VCALENDAR and VCARD files.
With naiveical you can extract parts of an icalendar or vcard file and update individual
lines. It does not parse files but rather works directly with pure text.
As such it does not prevent you from doing stupid things, such as embedding
elements into each other that have no meaning.

The advantage of this approach is to keep the vcalendar and vcard text as close to the
original as possible, with only modifying the changed parts. 

Creation of those files is handled with Creator.Icalendar and Creator.Vcard
## Installation

The package [available in Hex](https://hex.pm/packages/naiveical) and can be installed
by adding `naiveical` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:naiveical, "~> 0.1.1"}
  ]
end
```

## Documentation

Available at [HexDocs](https://hexdocs.pm/naiveical).

## Example of VCALENDAR CREATION

Create a new vcalendar:

``` elixir
ical = Naiveical.Creator.Icalendar.create_vcalendar()
```

Create a new vtodo:

``` elixir
dtstart = DateTime.now!("Etc/UTC")
due = DateTime.now!("Etc/UTC")
todo = Naiveical.Creator.Icalendar.create_vtodo("vtodo example", dtstart, due)
```

Create a new valert:

``` elixir
alarm = Naiveical.Creator.Icalendar.create_valarm("Ring the bell", "-PT15M")
alarm2 = Naiveical.Creator.Icalendar.create_valarm("Ring the bell", "-PT5M")
```

Assemble all together:

``` elixir
      {:ok, todo} = Naiveical.Modificator.insert_into(todo, alarm, "VTODO")
      {:ok, todo} = Naiveical.Modificator.insert_into(todo, alarm2, "VTODO")
      {:ok, ical} = Naiveical.Modificator.insert_into(ical, todo, "VCALENDAR")
```

Extract the summary content line: 
``` elixir
  Naiveical.Extractor.extract_contentline_by_tag(ical, "SUMMARY")
  {_tag, _attr, due_str} = Naiveical.Extractor.extract_contentline_by_tag(ical, "DUE")
  Naiveical.Helpers.parse_datetime(due_str)
```

Change the summary: 
``` elixir 
  updated_ical = Naiveical.Modificator.change_value(ical, "summary", "my updated summary")
```

Extract the alerts:

``` elixir
      valarms = Naiveical.Extractor.extract_sections_by_tag(ical, "VALARM")
```
## Example of creating VCARD 

### Explanation 
Creation of VCARD is possible passing multiple options for components when calling the function ```Naiveical.Creator.Vcard.create_vcard/2```, or by merging all together with ```Naiveical.Modificator.insert_into/3```
Creating with components options is supported without adding additional params to component. To create with additional component params use dedicated function for each component and pass there additional options.
Each component has [VCARD FORMAT](https://www.rfc-editor.org/rfc/rfc6350) reference for options.
## EXAMPLES

### With options
Create a new vcard 
```elixir 
 Naiveical.Creator.Vcard.create_vcard("uid-12345", display_name: "User Test", email: "user@example.org", tel: "123456") 
```

### With individual component creation
Create empty vcard
```elixir 
vcard = Naiveical.Creator.Vcard.create_vcard("uid-12345") 
```
Create email 
```elixir 
email = Naiveical.Creator.Vcard.create_email("user@example.org", type: "work", pref: 1, label: "some label") 
```
Create telephone 
```elixir 
tel = Naiveical.Creator.Vcard.create_telephone("123456789", type: "work")
```
Create name  
```elixir 
name = Naiveical.Creator.Vcard.create_display_name("User", "Name") 
```

Assemble all together
``` elixir 
  {:ok, vcard} = Naiveical.Modificator.insert_into(vcard, email, "VCARD")
  {:ok, vcard} = Naiveical.Modificator.insert_into(vcard, tel, "VCARD")
  {:ok, vcard} = Naiveical.Modificator.insert_into(vcard, name, "VCARD")
```

You can create multiple same components, and insert it like in the example above.
``` elixir 
  email = Naiveical.Creator.Vcard.create_email("user@example.org", type: "work", pref: 1) 
  email = Naiveical.Creator.Vcard.create_email("user@example1.org", type: "home")
  email = Naiveical.Creator.Vcard.create_email("user@example2.org", type: "home", label: "new")
```
## VTIMEZONE database
The VTIMEZONE database has been compiled by using the [vzic utility](https://github.com/libical/vzic).

## Rationale

The difficulty in parsing the icalendar or vcard format is that it is difficult to write a library that can parse and re-create those  
files without any data loss. As such it is best to keep the original files and work directly on the file. This makes working
with the access of the individual fields more complicated but keeps the original file intact.
