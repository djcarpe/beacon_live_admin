defmodule Beacon.LiveAdmin.PreviewController do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    site = String.to_existing_atom(conn.params["site"])
    page_id = conn.params["id"]
    type = conn.params["type"] || "page"

    html = render_preview(site, type, page_id)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> put_resp_header("x-frame-options", "SAMEORIGIN")
    |> put_private(:plug_skip_csrf_protection, true)
    |> send_resp(200, html)
    |> halt()
  end

  defp render_preview(site, "page", page_id) do
    page = Beacon.Content.get_page!(site, page_id)
    layout = if page.layout_id, do: Beacon.Content.get_layout(site, page.layout_id)
    registry = component_registry(site)
    assigns = preview_assigns(site, page)

    page_html = compile_template(page.template || "", assigns, registry)

    if layout do
      layout_assigns = Map.put(assigns, :inner_content, {:safe, page_html})
      layout_html = compile_template(layout.template || "", layout_assigns, registry)
      wrap_html(site, page.title || "Preview", layout_html)
    else
      wrap_html(site, page.title || "Preview", page_html)
    end
  end

  defp render_preview(site, "error_page", status) do
    error_page = Beacon.Content.get_error_page(site, String.to_integer(status))

    if error_page do
      registry = component_registry(site)
      html = compile_template(error_page.template || "", %{}, registry)
      wrap_html(site, "Error #{status}", html)
    else
      wrap_html(site, "Error #{status}", "<p>No error page template for status #{status}</p>")
    end
  end

  defp render_preview(site, "layout", layout_id) do
    layout = Beacon.Content.get_layout(site, layout_id)

    if layout do
      placeholder = """
      <div style="padding: 2rem; margin: 2rem; border: 2px dashed #94a3b8; border-radius: 0.5rem; text-align: center; color: #64748b; font-family: system-ui;">
        <p style="font-size: 1.25rem; font-weight: 600;">Page Content Area</p>
        <p style="font-size: 0.875rem;">This is where the page content will be rendered</p>
      </div>
      """

      registry = component_registry(site)
      assigns = %{inner_content: {:safe, placeholder}}
      html = compile_template(layout.template || "", assigns, registry)
      wrap_html(site, layout.title || "Layout Preview", html)
    else
      wrap_html(site, "Layout Preview", "<p>Layout not found</p>")
    end
  end

  defp render_preview(_site, _type, _id) do
    wrap_html(nil, "Preview", "<p>Unknown preview type</p>")
  end

  # Parse Beacon template syntax → expand components → render to HTML string
  defp compile_template(template, assigns, registry) do
    template
    |> Beacon.Template.Parser.parse()
    |> Beacon.Template.ComponentExpander.expand(registry)
    |> Beacon.Client.LiveViewCompiler.render_to_iodata(assigns)
    |> IO.iodata_to_binary()
  end

  defp component_registry(site) do
    try do
      Beacon.Content.build_component_registry_for_ast(site)
    rescue
      _ -> %{}
    end
  end

  defp preview_assigns(site, page) do
    %{
      beacon: %{
        site: site,
        page: %{
          path: page.path,
          title: page.title,
          description: page.description,
          fields: page.fields || %{}
        },
        private: %{
          page_id: page.id,
          layout_id: page.layout_id
        }
      },
      page_title: page.title || "",
      inner_content: {:safe, ""}
    }
  end

  # Load the site's Tailwind theme JSON for the WASM compiler
  defp load_theme_json(site) do
    try do
      config = Beacon.Config.fetch!(site)

      if config.tailwind_config && File.exists?(config.tailwind_config) do
        config.tailwind_config
        |> Beacon.CSS.ThemeParser.parse_file()
        |> inject_mesa_colors()
      end
    rescue
      _ -> nil
    end
  end

  # Sojourner fork: the site's bundled tailwind config exposes an empty
  # `colors` map and no daisyUI, so the WASM preview compiler has no
  # definition for semantic classes like `bg-success` / `bg-primary` —
  # they render with no color. Merge the mesa palette (dark variant, to
  # match the operational kiosk pages) into the theme `colors` so the
  # compiler emits those utilities with the correct mesa values.
  # Source of truth: assets/css/app.css [data-theme=mesa] in rivianvw/sojourner.
  defp inject_mesa_colors(theme_json) when is_binary(theme_json) do
    case Jason.decode(theme_json) do
      {:ok, %{} = map} ->
        colors = Map.merge(Map.get(map, "colors") || %{}, mesa_colors())
        map |> Map.put("colors", colors) |> Jason.encode!()

      _ ->
        theme_json
    end
  end

  defp inject_mesa_colors(other), do: other

  defp mesa_colors do
    %{
      "primary" => "#2a9c8e",
      "primary-content" => "#d2f5ed",
      "secondary" => "#37ad9e",
      "secondary-content" => "#050505",
      "accent" => "#b8fa65",
      "accent-content" => "#050505",
      "neutral" => "#232323",
      "neutral-content" => "#dfdfdf",
      "base-100" => "#050505",
      "base-200" => "#111111",
      "base-300" => "#1c1c1c",
      "base-content" => "#dfdfdf",
      "info" => "#337cff",
      "info-content" => "#dfdfdf",
      "success" => "#37a754",
      "success-content" => "#050505",
      "warning" => "#f08c2b",
      "warning-content" => "#050505",
      "error" => "#ed5246",
      "error-content" => "#dfdfdf"
    }
  end

  # Load the site's custom stylesheets
  defp load_custom_css(site) do
    try do
      site
      |> Beacon.Content.list_stylesheets()
      |> Enum.map_join("\n", fn s -> s.content end)
      |> case do
        "" -> nil
        css -> css
      end
    rescue
      _ -> nil
    end
  end

  defp wrap_html(site, title, body) do
    wasm_hash = Beacon.LiveAdmin.AssetsController.current_hash(:wasm)
    css_hash = Beacon.LiveAdmin.AssetsController.current_hash(:css)
    escaped_title = Phoenix.HTML.html_escape(title) |> Phoenix.HTML.safe_to_string()
    theme_json = if site, do: load_theme_json(site)
    custom_css = if site, do: load_custom_css(site)
    theme_json_js = if theme_json, do: Jason.encode!(theme_json), else: "null"
    custom_css_js = if custom_css, do: Jason.encode!(custom_css), else: "null"

    """
    <!DOCTYPE html>
    <html lang="en" data-theme="beacon-dark">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{escaped_title}</title>
      <!-- Sojourner fork: load the admin's daisyUI + mesa theme bundle so daisyUI
           component classes (card/badge/btn/alert/table) render in the preview.
           The WASM Tailwind compiler below only generates utility classes; daisyUI
           components and the mesa theme variables come from this stylesheet. -->
      <link rel="stylesheet" href="/__beacon_live_admin__/assets/css-#{css_hash}">
      <style>html[data-theme]{ background-color: oklch(var(--b1)); color: oklch(var(--bc)); }</style>
      <style>
        /* Preview indicator */
        body::before {
          content: "PREVIEW";
          position: fixed;
          top: 8px;
          right: 8px;
          z-index: 99999;
          background: #f59e0b;
          color: #fff;
          font-size: 10px;
          font-weight: 700;
          letter-spacing: 0.1em;
          padding: 2px 8px;
          border-radius: 4px;
          font-family: system-ui;
          pointer-events: none;
        }
      </style>
    </head>
    <body style="opacity: 0;">
      #{body}
      <script>
      (function() {
        var encoder = new TextEncoder();
        var decoder = new TextDecoder();
        var THEME_JSON = #{theme_json_js};
        var CUSTOM_CSS = #{custom_css_js};

        var __revealed = false;
        function revealBody() {
          if (__revealed) return;
          __revealed = true;
          document.body.style.opacity = '1';
        }
        // No-blank guarantee: reveal even if WASM compilation never succeeds.
        setTimeout(revealBody, 1500);

        function writeStr(wasm, s) {
          var bytes = encoder.encode(s);
          var ptr = wasm.alloc(bytes.length);
          if (!ptr) throw new Error('WASM alloc failed for ' + bytes.length + ' bytes');
          new Uint8Array(wasm.memory.buffer, ptr, bytes.length).set(bytes);
          return [ptr, bytes.length];
        }

        function extractCandidates() {
          var classes = new Set();
          document.querySelectorAll('[class]').forEach(function(el) {
            el.classList.forEach(function(c) { if (c) classes.add(c); });
          });
          return Array.from(classes);
        }

        function compile(wasm, pluginCss) {
          if (!wasm.memory || !wasm.alloc || !wasm.compile || !wasm.free) {
            console.error('[Beacon Preview] WASM missing exports:', Object.keys(wasm));
            revealBody();
            return;
          }

          var candidates = extractCandidates();
          if (!candidates.length) {
            console.warn('[Beacon Preview] No CSS class candidates found in page');
            revealBody();
            return;
          }

          var cand = writeStr(wasm, candidates.join('\\n'));
          var theme = THEME_JSON ? writeStr(wasm, THEME_JSON) : [0, 0];
          var custom = CUSTOM_CSS ? writeStr(wasm, CUSTOM_CSS) : [0, 0];
          var plugin = pluginCss ? writeStr(wasm, pluginCss) : [0, 0];

          var result = wasm.compile(
            cand[0], cand[1],
            theme[0], theme[1],
            1,        // preflight
            1,        // minify
            custom[0], custom[1],
            0, 0,     // custom_utilities
            plugin[0], plugin[1]
          );

          wasm.free(cand[0], cand[1]);
          if (theme[0]) wasm.free(theme[0], theme[1]);
          if (custom[0]) wasm.free(custom[0], custom[1]);
          if (plugin[0]) wasm.free(plugin[0], plugin[1]);

          if (result === 0n) {
            console.warn('[Beacon Preview] WASM compile returned empty result');
            revealBody();
            return;
          }

          var ptr = Number(result >> 32n);
          var len = Number(result & 0xFFFFFFFFn);
          var css = decoder.decode(new Uint8Array(wasm.memory.buffer, ptr, len));
          wasm.free(ptr, len);

          var sheet = new CSSStyleSheet();
          sheet.replaceSync(css);
          document.adoptedStyleSheets = [sheet];
          revealBody();
        }

        fetch('/__beacon_live_admin__/assets/wasm-#{wasm_hash}')
          .then(function(r) {
            if (!r.ok) throw new Error('WASM fetch failed: ' + r.status);
            return r.arrayBuffer();
          })
          .then(function(bytes) {
            if (!bytes.byteLength) throw new Error('WASM binary is empty');
            return WebAssembly.instantiate(bytes, {});
          })
          .then(function(result) {
            compile(result.instance.exports, null);
          })
          .catch(function(err) {
            console.error('[Beacon Preview] CSS compilation failed:', err);
            revealBody();
          });
      })();
      </script>
    </body>
    </html>
    """
  end
end
