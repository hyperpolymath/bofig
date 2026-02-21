// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/evidence_graph_web.ex",
    "../lib/evidence_graph_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        // Evidence Graph domain colours
        claim: {
          50: "#e3f2fd",
          100: "#bbdefb",
          200: "#90caf9",
          300: "#64b5f6",
          400: "#42a5f5",
          500: "#2196f3",  // Primary claim blue (33, 150, 243)
          600: "#1e88e5",
          700: "#1976d2",
          800: "#1565c0",
          900: "#0d47a1",
        },
        evidence: {
          50: "#e8f5e9",
          100: "#c8e6c9",
          200: "#a5d6a7",
          300: "#81c784",
          400: "#66bb6a",
          500: "#4caf50",  // Primary evidence green (76, 175, 80)
          600: "#43a047",
          700: "#388e3c",
          800: "#2e7d32",
          900: "#1b5e20",
        },
        supports: "#4CAF50",
        contradicts: "#F44336",
        contextualizes: "#2196F3",
        // Audience type colours
        audience: {
          researcher: "#7c3aed",      // purple
          policymaker: "#2563eb",     // blue
          skeptic: "#ea580c",         // orange
          activist: "#dc2626",        // red
          affected_person: "#0d9488", // teal
          journalist: "#16a34a",      // green
        },
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),

    // Hero Icons Tailwind plugin (inline SVG icons via CSS)
    plugin(function({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
      ]
      icons.forEach(([suffix, dir]) => {
        let fullDir = iconsDir + dir
        if (fs.existsSync(fullDir)) {
          fs.readdirSync(fullDir).forEach((file) => {
            let name = path.basename(file, ".svg") + suffix
            values[name] = { name, fullPath: path.join(fullDir, file) }
          })
        }
      })
      matchComponents(
        {
          hero: ({ name, fullPath }) => {
            let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
            let size = theme("spacing.6", "1.5rem")
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
        { values }
      )
    }),
  ],
}
