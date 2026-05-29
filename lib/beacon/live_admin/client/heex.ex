defmodule Beacon.LiveAdmin.Client.HEEx do
  @moduledoc false

  import Beacon.LiveAdmin.Cluster, only: [call: 4]

  def assigns(site, page) do
    call(site, Beacon.Template, :assigns, [page])
  end

  @doc """
  Render a Beacon template fragment to HTML for the visual editor.

  Sojourner fork: the legacy implementation evaluated HEEx via
  `Beacon.Template.HEEx.render/3`, which has no access to the site's component
  functions — a component reference (`<.name .../>`, the form stored in each
  component's `example`) raised `UndefinedFunctionError: name/1 (undefined
  local)` and the whole drag-and-drop insertion failed; non-component nodes
  rendered but components never did.

  This uses Beacon's post-HEEx runtime pipeline instead:

      parse (new AST)  ->  expand component references (registry)  ->  compile to HTML

  so `<name .../>` references inline their component markup and render in the
  canvas/preview. Falls back to the raw template on any error so a single bad
  node never crashes the editor.
  """
  def render(site, template, assigns \\ %{})

  def render(site, template, assigns) when is_binary(template) do
    registry = component_registry(site)

    template
    |> Beacon.Template.Parser.parse()
    |> Beacon.Template.ComponentExpander.expand(registry)
    |> Beacon.Client.LiveViewCompiler.render_to_iodata(assigns)
    |> IO.iodata_to_binary()
  rescue
    _ -> template
  end

  def render(_site, template, _assigns), do: template

  # Map of `%{"component_name" => [ast_nodes]}` used to inline component
  # references during expansion. Empty map on failure so rendering degrades to
  # leaving references unexpanded rather than crashing.
  defp component_registry(site) do
    Beacon.Content.build_component_registry_for_ast(site)
  rescue
    _ -> %{}
  end
end
