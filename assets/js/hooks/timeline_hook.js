// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

/**
 * TimelineHook — D3.js horizontal timeline for investigation events.
 *
 * Receives event data via push_event("timeline_data", ...) from TimelineLive.
 * Events are rendered as circles on a horizontal time axis, sized by PROMPT
 * score and colour-coded by type (evidence=blue, claim=green, transaction=red).
 *
 * D3 is loaded as a vendor script via assets/vendor/d3.v7.min.js and available
 * on the global scope as `d3`.
 */

const TimelineHook = {
  mounted() {
    this.svg = null;
    this.container = this.el;

    this.handleEvent("timeline_data", (data) => this.renderTimeline(data));
  },

  destroyed() {
    this.container.innerHTML = "";
  },

  /** Event type colour map */
  getColor(type) {
    const colors = {
      evidence: "#3B82F6",   // Blue-500
      claim: "#22C55E",      // Green-500
      transaction: "#EF4444", // Red-500
    };
    return colors[type] || "#9CA3AF";
  },

  /** PROMPT score to circle radius (4–16px range) */
  getRadius(promptScore) {
    const score = promptScore || 50;
    return 4 + (score / 100) * 12;
  },

  /**
   * Render (or re-render) the horizontal timeline.
   *
   * @param {Object} data — { events: Array, granularity: string }
   */
  renderTimeline(data) {
    const { events, granularity } = data;

    // Clear previous render
    this.container.innerHTML = "";

    if (!events || events.length === 0) {
      const empty = document.createElement("p");
      empty.className = "text-center text-gray-400 py-8";
      empty.textContent = "No events match the current filters.";
      this.container.appendChild(empty);
      return;
    }

    // Parse dates
    const parsedEvents = events.map((e) => ({
      ...e,
      parsedDate: new Date(e.date),
    }));

    // Dimensions
    const margin = { top: 30, right: 40, bottom: 40, left: 40 };
    const width = (this.container.clientWidth || 900) - margin.left - margin.right;
    const height = 260 - margin.top - margin.bottom;

    // Time extent
    const dateExtent = d3.extent(parsedEvents, (d) => d.parsedDate);

    // Add padding to the extent (5% each side)
    const timeSpan = dateExtent[1] - dateExtent[0] || 86400000; // at least one day
    const padMs = timeSpan * 0.05;
    const xMin = new Date(dateExtent[0].getTime() - padMs);
    const xMax = new Date(dateExtent[1].getTime() + padMs);

    // Scales
    const x = d3.scaleTime()
      .domain([xMin, xMax])
      .range([0, width]);

    // Vertical jitter by type to avoid overlap
    const typeOffsets = { evidence: -40, claim: 0, transaction: 40 };
    const centerY = height / 2;

    // SVG
    const svg = d3.select(this.container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom);

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    // Zoom behaviour
    const zoom = d3.zoom()
      .scaleExtent([0.5, 20])
      .translateExtent([[-100, -50], [width + 100, height + 50]])
      .on("zoom", (event) => {
        const newX = event.transform.rescaleX(x);
        xAxis.call(makeXAxis(newX, granularity));
        circles.attr("cx", (d) => newX(d.parsedDate));
      });

    svg.call(zoom);

    // X-axis
    const makeXAxis = (scale, gran) => {
      let tickFormat;
      let ticks;
      switch (gran) {
        case "day":
          tickFormat = d3.timeFormat("%d %b %Y");
          ticks = d3.timeDay.every(1);
          break;
        case "week":
          tickFormat = d3.timeFormat("%d %b %Y");
          ticks = d3.timeWeek.every(1);
          break;
        case "month":
        default:
          tickFormat = d3.timeFormat("%b %Y");
          ticks = d3.timeMonth.every(1);
          break;
      }
      return d3.axisBottom(scale)
        .ticks(ticks)
        .tickFormat(tickFormat);
    };

    const xAxis = g.append("g")
      .attr("class", "x-axis")
      .attr("transform", `translate(0,${height})`)
      .call(makeXAxis(x, granularity));

    xAxis.selectAll("text")
      .attr("font-size", "10px")
      .attr("fill", "#9CA3AF");

    xAxis.selectAll("line, path")
      .attr("stroke", "#4B5563");

    // Centre line
    g.append("line")
      .attr("x1", 0)
      .attr("x2", width)
      .attr("y1", centerY)
      .attr("y2", centerY)
      .attr("stroke", "#374151")
      .attr("stroke-dasharray", "4,4");

    // Type lane labels
    Object.entries(typeOffsets).forEach(([type, offset]) => {
      g.append("text")
        .attr("x", -5)
        .attr("y", centerY + offset)
        .attr("text-anchor", "end")
        .attr("font-size", "9px")
        .attr("fill", this.getColor(type))
        .attr("dominant-baseline", "middle")
        .text(type.charAt(0).toUpperCase() + type.slice(1));
    });

    // Event circles
    const circles = g.selectAll(".timeline-event")
      .data(parsedEvents)
      .join("circle")
      .attr("class", "timeline-event")
      .attr("cx", (d) => x(d.parsedDate))
      .attr("cy", (d) => centerY + (typeOffsets[d.type] || 0) + (Math.random() - 0.5) * 10)
      .attr("r", (d) => this.getRadius(d.prompt_score))
      .attr("fill", (d) => this.getColor(d.type))
      .attr("fill-opacity", 0.75)
      .attr("stroke", (d) => this.getColor(d.type))
      .attr("stroke-width", 1.5)
      .attr("cursor", "pointer");

    // Tooltip
    const tooltip = d3.select(this.container)
      .append("div")
      .attr("class", "timeline-tooltip")
      .style("position", "absolute")
      .style("pointer-events", "none")
      .style("background", "rgba(17, 24, 39, 0.9)")
      .style("color", "#F9FAFB")
      .style("padding", "6px 10px")
      .style("border-radius", "4px")
      .style("font-size", "12px")
      .style("max-width", "250px")
      .style("display", "none")
      .style("z-index", "10");

    circles
      .on("mouseenter", (event, d) => {
        tooltip
          .style("display", "block")
          .html(`
            <strong>${d.type.charAt(0).toUpperCase() + d.type.slice(1)}</strong><br/>
            ${d.label}<br/>
            <span style="color:#9CA3AF">${d.date}</span>
          `);
      })
      .on("mousemove", (event) => {
        const bounds = this.container.getBoundingClientRect();
        tooltip
          .style("left", (event.clientX - bounds.left + 12) + "px")
          .style("top", (event.clientY - bounds.top - 10) + "px");
      })
      .on("mouseleave", () => {
        tooltip.style("display", "none");
      })
      .on("click", (_event, d) => {
        this.pushEvent("event_clicked", { id: d.id, type: d.type });
      });

    this.svg = svg;
  },
};

export default TimelineHook;
