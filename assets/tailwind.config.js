const defaultTheme = require("tailwindcss/defaultTheme")
const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: ["./js/**/*.js", "../lib/beacon/live_admin/**/*.*ex", "./svelte/**/*.svelte"],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
      },
      fontFamily: {
        sans: ["Plus Jakarta Sans", "sans-serif", ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/container-queries"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Hero Icons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../assets/node_modules/heroicons")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"],
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) }
        })
      })
      matchComponents(
        {
          hero: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\r?\n|\r/g, "")
            let size = theme("spacing.6")
            if (name.endsWith("-mini")) {
              size = theme("spacing.5")
            } else if (name.endsWith("-micro")) {
              size = theme("spacing.4")
            }
            return {
              [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              "-webkit-mask": `var(--hero-${name})`,
              mask: `var(--hero-${name})`,
              "mask-repeat": "no-repeat",
              "background-color": "currentColor",
              "vertical-align": "middle",
              display: "inline-block",
              width: size,
              height: size,
            }
          },
        },
        { values },
      )
    }),

    require("daisyui"),
  ],

  daisyui: {
    themes: [
      {
        beacon: {
          "primary": "#2a9c8e",
          "primary-content": "#ffffff",
          "secondary": "#1c4642",
          "secondary-content": "#ffffff",
          "accent": "#2b8f44",
          "accent-content": "#ffffff",
          "neutral": "#1c1c1c",
          "neutral-content": "#dfdfdf",
          "base-100": "#ffffff",
          "base-200": "#f5f5f5",
          "base-300": "#e5e5e5",
          "base-content": "#1c1c1c",
          "info": "#1b5af5",
          "info-content": "#ffffff",
          "success": "#2b8f44",
          "success-content": "#ffffff",
          "warning": "#e06c16",
          "warning-content": "#ffffff",
          "error": "#da3529",
          "error-content": "#ffffff",
          "--rounded-box": "0.5rem",
          "--rounded-btn": "0.25rem",
          "--rounded-badge": "0.25rem",
          "color-scheme": "light",
        },
      },
      {
        "beacon-dark": {
          "primary": "#2a9c8e",
          "primary-content": "#d2f5ed",
          "secondary": "#37ad9e",
          "secondary-content": "#050505",
          "accent": "#b8fa65",
          "accent-content": "#050505",
          "neutral": "#232323",
          "neutral-content": "#dfdfdf",
          "base-100": "#050505",
          "base-200": "#111111",
          "base-300": "#1c1c1c",
          "base-content": "#dfdfdf",
          "info": "#337cff",
          "info-content": "#dfdfdf",
          "success": "#37a754",
          "success-content": "#050505",
          "warning": "#f08c2b",
          "warning-content": "#050505",
          "error": "#ed5246",
          "error-content": "#dfdfdf",
          "--rounded-box": "0.5rem",
          "--rounded-btn": "0.25rem",
          "--rounded-badge": "0.25rem",
          "color-scheme": "dark",
        },
      },
    ],
    darkTheme: "beacon-dark",
  },
}
