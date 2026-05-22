// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

/**
 * PromptRadarHook — D3.js radar/spider chart for PROMPT epistemological scores.
 *
 * 6 axes: Provenance, Replicability, Objective, Methodology, Publication, Transparency
 * Supports audience weight overlay (different profiles emphasise different axes).
 */

const DIMENSIONS = [
  "provenance",
  "replicability",
  "objective",
  "methodology",
  "publication",
  "transparency",
];

const DIMENSION_LABELS = {
  provenance: "Provenance",
  replicability: "Replicability",
  objective: "Objective",
  methodology: "Methodology",
  publication: "Publication",
  transparency: "Transparency",
};

const PromptRadarHook = {
  mounted() {
    this.container = this.el;
    this.handleEvent("radar_data", (data) => this.renderRadar(data));
    this.handleEvent("radar_overlay", (data) => this.addOverlay(data));
  },

  destroyed() {
    this.container.innerHTML = "";
  },

  renderRadar(data) {
    const { scores, weights, audience } = data;
    if (!scores) return;

    this.container.innerHTML = "";

    const size = Math.min(this.container.clientWidth || 400, 400);
    const margin = 60;
    const radius = (size - margin * 2) / 2;
    const centerX = size / 2;
    const centerY = size / 2;
    const levels = 5; // Concentric rings (0, 20, 40, 60, 80, 100)

    const svg = d3.select(this.container)
      .append("svg")
      .attr("width", size)
      .attr("height", size)
      .attr("viewBox", [0, 0, size, size]);

    const g = svg.append("g");

    // Draw concentric level rings
    for (let level = 1; level <= levels; level++) {
      const r = (radius / levels) * level;
      const points = DIMENSIONS.map((_, i) => {
        const angle = (Math.PI * 2 * i) / DIMENSIONS.length - Math.PI / 2;
        return [centerX + r * Math.cos(angle), centerY + r * Math.sin(angle)];
      });
      g.append("polygon")
        .attr("points", points.map((p) => p.join(",")).join(" "))
        .attr("fill", "none")
        .attr("stroke", "#e5e7eb")
        .attr("stroke-width", 1);
    }

    // Draw axis lines and labels
    DIMENSIONS.forEach((dim, i) => {
      const angle = (Math.PI * 2 * i) / DIMENSIONS.length - Math.PI / 2;
      const x = centerX + radius * Math.cos(angle);
      const y = centerY + radius * Math.sin(angle);

      g.append("line")
        .attr("x1", centerX)
        .attr("y1", centerY)
        .attr("x2", x)
        .attr("y2", y)
        .attr("stroke", "#d1d5db")
        .attr("stroke-width", 1);

      // Label
      const labelX = centerX + (radius + 25) * Math.cos(angle);
      const labelY = centerY + (radius + 25) * Math.sin(angle);

      g.append("text")
        .attr("x", labelX)
        .attr("y", labelY)
        .attr("text-anchor", "middle")
        .attr("dominant-baseline", "middle")
        .attr("font-size", "11px")
        .attr("fill", "#6b7280")
        .text(DIMENSION_LABELS[dim]);
    });

    // Draw score polygon
    const scorePoints = DIMENSIONS.map((dim, i) => {
      const angle = (Math.PI * 2 * i) / DIMENSIONS.length - Math.PI / 2;
      const value = (scores[dim] || 0) / 100;
      return [
        centerX + radius * value * Math.cos(angle),
        centerY + radius * value * Math.sin(angle),
      ];
    });

    g.append("polygon")
      .attr("points", scorePoints.map((p) => p.join(",")).join(" "))
      .attr("fill", "rgba(33, 150, 243, 0.2)")
      .attr("stroke", "#2196f3")
      .attr("stroke-width", 2);

    // Draw score dots
    scorePoints.forEach((point, i) => {
      g.append("circle")
        .attr("cx", point[0])
        .attr("cy", point[1])
        .attr("r", 4)
        .attr("fill", "#2196f3")
        .attr("stroke", "white")
        .attr("stroke-width", 1.5);

      // Score value label
      g.append("text")
        .attr("x", point[0])
        .attr("y", point[1] - 10)
        .attr("text-anchor", "middle")
        .attr("font-size", "10px")
        .attr("font-weight", "bold")
        .attr("fill", "#1976d2")
        .text(scores[DIMENSIONS[i]] || 0);
    });

    // If weights provided, draw weight indicators
    if (weights) {
      this._drawWeightRing(g, weights, centerX, centerY, radius, audience);
    }

    this._svg = svg;
    this._g = g;
    this._centerX = centerX;
    this._centerY = centerY;
    this._radius = radius;
  },

  addOverlay(data) {
    const { weights, audience, color } = data;
    if (!this._g || !weights) return;

    this._drawWeightRing(
      this._g,
      weights,
      this._centerX,
      this._centerY,
      this._radius,
      audience,
      color
    );
  },

  _drawWeightRing(g, weights, cx, cy, radius, audience, color) {
    const fillColor = color || "rgba(76, 175, 80, 0.15)";
    const strokeColor = color ? color.replace("0.15", "0.8") : "rgba(76, 175, 80, 0.6)";

    // Weight polygon (normalised: max weight maps to outer ring)
    const maxWeight = Math.max(...Object.values(weights));
    const weightPoints = DIMENSIONS.map((dim, i) => {
      const angle = (Math.PI * 2 * i) / DIMENSIONS.length - Math.PI / 2;
      const value = (weights[dim] || 0) / maxWeight;
      return [
        cx + radius * value * Math.cos(angle),
        cy + radius * value * Math.sin(angle),
      ];
    });

    g.append("polygon")
      .attr("points", weightPoints.map((p) => p.join(",")).join(" "))
      .attr("fill", fillColor)
      .attr("stroke", strokeColor)
      .attr("stroke-width", 1.5)
      .attr("stroke-dasharray", "4,2")
      .attr("opacity", 0)
      .transition()
      .duration(400)
      .attr("opacity", 1);
  },
};

export default PromptRadarHook;
