defmodule Naiveical.WindowsIanaConvert do
  @moduledoc """
  Parse https://github.com/unicode-org/cldr/blob/main/common/supplemental/windowsZones.xml
  """

  import SweetXml

  @spec extract_windows_zones() :: [map()]
  def extract_windows_zones() do
    path = Application.app_dir(:naiveical) |> Path.join("priv/windowsZones.xml")
    d = File.read!(path)
    doc = parse(d, namespace_conformant: true)

    xpath(doc, ~x"//mapZone"l)
    |> Enum.map(fn li_node ->
      %{
        zone: xpath(li_node, ~x"//mapZone/@other"l),
        territory: xpath(li_node, ~x"//mapZone/@territory"l),
        type: xpath(li_node, ~x"//mapZone/@type"l)
      }
    end)
  end

  @spec get_iana(String.t()) :: [String.t()]
  def get_iana(windows_tz) do
    extract_windows_zones()
    |> Enum.reduce([], fn %{type: type, zone: zone, territory: _territory}, acc ->
      zone = to_string(zone)

      if zone == windows_tz, do: acc ++ [to_string(type)], else: acc
    end)
  end
end
