// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

/**
 * EvidenceGraphHook — D3.js force-directed graph for claims and evidence.
 *
 * Ported from the retired ReScript D3 bindings.
 * Receives graph data via push_event("graph_data", ...) from GraphLive.
 */

// D3 is loaded as a vendor script via assets/vendor/d3.v7.min.js
// and available on the global scope as `d3`.

const EvidenceGraphHook = {
  mounted() {
    this.svg = null;
    this.simulation = null;
    this.container = this.el;

    this.handleEvent("graph_data", (data) => this.renderGraph(data));
    this.handleEvent("update_audience", (data) => this.updateAudience(data));
  },

  destroyed() {
    if (this.simulation) {
      this.simulation.stop();
    }
  },

  /** Colour scheme matching ReScript source */
  getNodeColor(nodeType, promptScore) {
    const colors = {
      claim: [33, 150, 243], // Blue
      evidence: [76, 175, 80], // Green
    };
    const [r, g, b] = colors[nodeType] || [158, 158, 158];
    const alpha = Math.max(0.3, (promptScore || 50) / 100.0);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  },

  getEdgeColor(relationship) {
    const colors = {
      supports: "#4CAF50",
      contradicts: "#F44336",
      contextualizes: "#2196F3",
    };
    return colors[relationship] || "#9E9E9E";
  },

  renderGraph(data) {
    const { nodes, links } = data;
    if (!nodes || nodes.length === 0) return;

    // Clear previous graph
    if (this.simulation) this.simulation.stop();
    this.container.replaceChildren();

    const width = this.container.clientWidth || 800;
    const height = this.container.clientHeight || 500;

    const svg = d3.select(this.container)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("viewBox", [0, 0, width, height]);

    // Arrow marker definitions
    const defs = svg.append("defs");
    ["supports", "contradicts", "contextualizes"].forEach((rel) => {
      defs.append("marker")
        .attr("id", `arrow-${rel}`)
        .attr("viewBox", "0 -5 10 10")
        .attr("refX", 25)
        .attr("refY", 0)
        .attr("markerWidth", 6)
        .attr("markerHeight", 6)
        .attr("orient", "auto")
        .append("path")
        .attr("d", "M0,-5L10,0L0,5")
        .attr("fill", this.getEdgeColor(rel));
    });

    // Zoom behaviour
    const g = svg.append("g");
    svg.call(
      d3.zoom()
        .scaleExtent([0.3, 5])
        .on("zoom", (event) => g.attr("transform", event.transform)),
    );

    // Force simulation
    const simulation = d3.forceSimulation(nodes)
      .force(
        "link",
        d3.forceLink(links)
          .id((d) => d.id)
          .distance(120),
      )
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(40));

    // Render edges
    const link = g.append("g")
      .attr("class", "edges")
      .selectAll("line")
      .data(links)
      .join("line")
      .attr("class", (d) => `graph-edge ${d.relationship}`)
      .attr("stroke", (d) => this.getEdgeColor(d.relationship))
      .attr("stroke-width", (d) => Math.max(1, (d.weight || 0.5) * 3))
      .attr("marker-end", (d) => `url(#arrow-${d.relationship})`);

    // Render nodes
    const node = g.append("g")
      .attr("class", "nodes")
      .selectAll("g")
      .data(nodes)
      .join("g")
      .attr("class", "graph-node")
      .call(
        d3.drag()
          .on("start", (event, d) => {
            if (!event.active) simulation.alphaTarget(0.3).restart();
            d.fx = d.x;
            d.fy = d.y;
          })
          .on("drag", (event, d) => {
            d.fx = event.x;
            d.fy = event.y;
          })
          .on("end", (event, d) => {
            if (!event.active) simulation.alphaTarget(0);
            d.fx = null;
            d.fy = null;
          }),
      );

    // Node circles
    node.append("circle")
      .attr("r", (d) => d.nodeType === "claim" ? 18 : 14)
      .attr("fill", (d) => this.getNodeColor(d.nodeType, d.promptScore))
      .attr("stroke", (d) => d.nodeType === "claim" ? "#1976d2" : "#388e3c")
      .attr("stroke-width", 2);

    // Node labels
    node.append("text")
      .attr("dy", (d) => d.nodeType === "claim" ? 30 : 26)
      .attr("text-anchor", "middle")
      .attr("font-size", "10px")
      .text((d) => {
        const label = d.label || d.id;
        return label.length > 25 ? label.substring(0, 22) + "..." : label;
      });

    // Click handler
    node.on("click", (_event, d) => {
      this.pushEvent("node_clicked", {
        id: d.id,
        node_type: d.nodeType,
      });
    });

    // Tick update
    simulation.on("tick", () => {
      link
        .attr("x1", (d) => d.source.x)
        .attr("y1", (d) => d.source.y)
        .attr("x2", (d) => d.target.x)
        .attr("y2", (d) => d.target.y);

      node.attr("transform", (d) => `translate(${d.x},${d.y})`);
    });

    this.svg = svg;
    this.simulation = simulation;
  },

  updateAudience(data) {
    const { nodes } = data;
    if (!this.svg || !nodes) return;

    // Update node opacity based on new audience-weighted PROMPT scores
    const nodeMap = new Map(nodes.map((n) => [n.id, n]));

    this.svg.selectAll(".graph-node circle")
      .transition()
      .duration(500)
      .attr("fill", function () {
        const d = d3.select(this.parentNode).datum();
        const updated = nodeMap.get(d.id);
        if (updated) {
          d.promptScore = updated.promptScore;
        }
        const colors = {
          claim: [33, 150, 243],
          evidence: [76, 175, 80],
        };
        const [r, g, b] = colors[d.nodeType] || [158, 158, 158];
        const alpha = Math.max(0.3, (d.promptScore || 50) / 100.0);
        return `rgba(${r}, ${g}, ${b}, ${alpha})`;
      });
  },
};

export default EvidenceGraphHook;
