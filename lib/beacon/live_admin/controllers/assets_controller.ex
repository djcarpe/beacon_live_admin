defmodule Beacon.LiveAdmin.AssetsController do
  @moduledoc false

  import Plug.Conn

  @dev_mode Code.ensure_loaded?(Mix.Project) and Mix.env() == :dev

  phoenix_js_paths =
    for app <- [:phoenix, :phoenix_html, :phoenix_live_view] do
      path = Application.app_dir(app, ["priv", "static", "#{app}.js"])
      Module.put_attribute(__MODULE__, :external_resource, path)
      path
    end

  @phoenix_js for(path <- phoenix_js_paths, into: "", do: File.read!(path) |> String.replace("//# sourceMappingURL=", "// "))

  # ---------------------------------------------------------------------------
  # CSS: minimal bootstrap — full CSS compiled at runtime via WASM
  # ---------------------------------------------------------------------------

  # Load DaisyUI plugin CSS to be served to the browser for WASM compilation
  daisyui_dir = Path.join([__DIR__, "../../../../assets/node_modules/daisyui/dist"]) |> Path.expand()

  daisyui_plugin_css =
    if File.exists?(daisyui_dir) do
      styled = File.read!(Path.join(daisyui_dir, "styled.css"))
      themes = File.read!(Path.join(daisyui_dir, "themes.css"))

      # Sojourner fork: rebind Beacon Admin's daisyUI themes to the
      # mesa / mesa-light palette so the admin chrome matches the rest
      # of the host app. The theme names stay `beacon` / `beacon-dark`
      # so Beacon's own theme-toggle JS keeps working; only the color
      # values change. Source of truth: assets/css/app.css in
      # rivianvw/sojourner.
      beacon_themes = """
      [data-theme="beacon"] {
        --color-base-100: #ffffff;
        --color-base-200: #f5f5f5;
        --color-base-300: #e5e5e5;
        --color-base-content: #1c1c1c;
        --color-primary: #2a9c8e;
        --color-primary-content: #ffffff;
        --color-secondary: #1c4642;
        --color-secondary-content: #ffffff;
        --color-accent: #2b8f44;
        --color-accent-content: #ffffff;
        --color-neutral: #1c1c1c;
        --color-neutral-content: #dfdfdf;
        --color-info: #1b5af5;
        --color-info-content: #ffffff;
        --color-success: #2b8f44;
        --color-success-content: #ffffff;
        --color-warning: #e06c16;
        --color-warning-content: #ffffff;
        --color-error: #da3529;
        --color-error-content: #ffffff;
        color-scheme: light;
      }
      [data-theme="beacon-dark"] {
        --color-base-100: #050505;
        --color-base-200: #111111;
        --color-base-300: #1c1c1c;
        --color-base-content: #dfdfdf;
        --color-primary: #2a9c8e;
        --color-primary-content: #d2f5ed;
        --color-secondary: #37ad9e;
        --color-secondary-content: #050505;
        --color-accent: #b8fa65;
        --color-accent-content: #050505;
        --color-neutral: #232323;
        --color-neutral-content: #dfdfdf;
        --color-info: #337cff;
        --color-info-content: #dfdfdf;
        --color-success: #37a754;
        --color-success-content: #050505;
        --color-warning: #f08c2b;
        --color-warning-content: #050505;
        --color-error: #ed5246;
        --color-error-content: #dfdfdf;
        color-scheme: dark;
      }
      """

      styled <> "\n" <> themes <> "\n" <> beacon_themes
    else
      ""
    end

  @plugin_css daisyui_plugin_css

  # Fallback CSS served before WASM initializes — just the pre-built file
  css_path = Path.join(__DIR__, "../../../../priv/static/beacon_live_admin.min.css")
  @external_resource css_path

  @css if File.exists?(css_path), do: File.read!(css_path), else: ""

  # WASM binary
  wasm_path = Path.join(__DIR__, "../../../../priv/static/tailwind_compiler.wasm")
  @external_resource wasm_path
  @wasm if File.exists?(wasm_path), do: File.read!(wasm_path), else: ""

  # ---------------------------------------------------------------------------
  # JS
  # ---------------------------------------------------------------------------

  js_path =
    if Code.ensure_loaded?(Mix.Project) and Mix.env() == :dev do
      Path.join(__DIR__, "../../../../priv/static/beacon_live_admin.js")
    else
      Path.join(__DIR__, "../../../../priv/static/beacon_live_admin.min.js")
    end

  @external_resource js_path

  @js """
  #{@phoenix_js}
  #{File.read!(js_path)}
  """

  @hashes %{
    css: Base.encode16(:crypto.hash(:md5, @css), case: :lower),
    js: Base.encode16(:crypto.hash(:md5, @js), case: :lower),
    wasm: Base.encode16(:crypto.hash(:md5, @wasm), case: :lower),
    plugin_css: Base.encode16(:crypto.hash(:md5, @plugin_css), case: :lower)
  }

  def init(asset) when asset in [:css, :js, :wasm, :plugin_css], do: asset

  def call(conn, asset) do
    {contents, content_type} = contents_and_type(asset)

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> put_private(:plug_skip_csrf_protection, true)
    |> send_resp(200, contents)
    |> halt()
  end

  defp contents_and_type(:plugin_css), do: {@plugin_css, "text/css"}

  if @dev_mode do
    @css_path css_path
    @js_path js_path
    @wasm_path wasm_path

    defp contents_and_type(:css) do
      {if(File.exists?(@css_path), do: File.read!(@css_path), else: ""), "text/css"}
    end

    defp contents_and_type(:js) do
      js = if(File.exists?(@js_path), do: File.read!(@js_path), else: "")
      {@phoenix_js <> js, "text/javascript"}
    end

    defp contents_and_type(:wasm) do
      {if(File.exists?(@wasm_path), do: File.read!(@wasm_path), else: ""), "application/wasm"}
    end

    @doc """
    Returns the current hash for the given `asset`.
    """
    def current_hash(:css),
      do: Base.encode16(:crypto.hash(:md5, elem(contents_and_type(:css), 0)), case: :lower)

    def current_hash(:js),
      do: Base.encode16(:crypto.hash(:md5, elem(contents_and_type(:js), 0)), case: :lower)

    def current_hash(:wasm),
      do: Base.encode16(:crypto.hash(:md5, elem(contents_and_type(:wasm), 0)), case: :lower)

    def current_hash(:plugin_css), do: @hashes.plugin_css
  else
    defp contents_and_type(:css), do: {@css, "text/css"}
    defp contents_and_type(:js), do: {@js, "text/javascript"}
    defp contents_and_type(:wasm), do: {@wasm, "application/wasm"}

    @doc """
    Returns the current hash for the given `asset`.
    """
    def current_hash(:css), do: @hashes.css
    def current_hash(:js), do: @hashes.js
    def current_hash(:wasm), do: @hashes.wasm
    def current_hash(:plugin_css), do: @hashes.plugin_css
  end
end
