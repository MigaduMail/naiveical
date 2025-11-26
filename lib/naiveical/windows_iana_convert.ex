defmodule Naiveical.WindowsIanaConvert do
  @moduledoc """
  Parse https://github.com/unicode-org/cldr/blob/main/common/supplemental/windowsZones.xml
  """

  import SweetXml

  @windows_zone_file Application.app_dir(:naiveical) |> Path.join("priv/windowsZones.xml")

  @windows_zones (
                   @windows_zone_file
                   |> File.read!()
                   |> parse(namespace_conformant: true)
                   |> xpath(~x"//mapZone"l)
                   |> Enum.map(fn node ->
                     %{
                       zone: xpath(node, ~x"./@other"s),
                       territory: xpath(node, ~x"./@territory"s),
                       type: xpath(node, ~x"./@type"s)
                     }
                   end)
                 )

  @windows_zone_map Enum.reduce(@windows_zones, %{}, fn %{zone: zone, type: type}, acc ->
                        Map.update(acc, zone, [type], fn existing -> existing ++ [type] end)
                      end)

  @spec extract_windows_zones() :: [map()]
  def extract_windows_zones, do: @windows_zones

  @spec get_iana(String.t()) :: [String.t()]
  def get_iana(windows_tz) do
    Map.get(@windows_zone_map, windows_tz, [])
  end
end
