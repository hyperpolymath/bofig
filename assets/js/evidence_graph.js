/**
 * Evidence Graph Visualization with D3.js
 *
 * Interactive force-directed graph for Claims and Evidence
 * Color-coded by PROMPT scores and relationship types
 */

export class EvidenceGraphViz {
  constructor(containerId, options = {}) {
    this.container = document.getElementById(containerId);
    this.width = options.width || this.container.clientWidth;
    this.height = options.height || 600;
    this.data = null;

    this.svg = null;
    this.simulation = null;
    this.nodeGroup = null;
    this.linkGroup = null;

    this.initSVG();
  }

  initSVG() {
    this.svg = d3.select(`#${this.container.id}`)
      .append('svg')
      .attr('width', this.width)
      .attr('height', this.height)
      .attr('viewBox', [0, 0, this.width, this.height]);

    // Add zoom behavior
    const zoom = d3.zoom()
      .scaleExtent([0.5, 5])
      .on('zoom', (event) => {
        this.svg.select('g').attr('transform', event.transform);
      });

    this.svg.call(zoom);

    // Container for graph elements
    this.svg.append('g');

    // Add arrow markers for directed edges
    this.svg.append('defs').selectAll('marker')
      .data(['supports', 'contradicts', 'contextualizes'])
      .join('marker')
      .attr('id', d => `arrow-${d}`)
      .attr('viewBox', '0 -5 10 10')
      .attr('refX', 20)
      .attr('refY', 0)
      .attr('markerWidth', 6)
      .attr('markerHeight', 6)
      .attr('orient', 'auto')
      .append('path')
      .attr('d', 'M0,-5L10,0L0,5')
      .attr('fill', d => this.getRelationshipColor(d));
  }

  /**
   * Load data from GraphQL API
   */
  async loadData(investigationId) {
    const query = `
      query {
        claims(investigationId: "${investigationId}") {
          id
          text
          claimType
          promptScores {
            overall
            provenance
            methodology
          }
        }
        evidenceList(investigationId: "${investigationId}") {
          id
          title
          evidenceType
          promptScores {
            overall
            provenance
            methodology
          }
        }
      }
    `;

    const response = await fetch('/api/graphql', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query })
    });

    const { data } = await response.json();

    // Transform to D3 format
    this.data = {
      nodes: [
        ...data.claims.map(c => ({
          id: c.id,
          label: c.text.substring(0, 50) + '...',
          type: 'claim',
          promptScore: c.promptScores.overall,
          ...c
        })),
        ...data.evidenceList.map(e => ({
          id: e.id,
          label: e.title.substring(0, 50) + '...',
          type: 'evidence',
          promptScore: e.promptScores.overall,
          ...e
        }))
      ],
      links: [] // Populate from relationships query
    };

    await this.loadRelationships(investigationId);
    this.render();
  }

  async loadRelationships(investigationId) {
    // Query all claims and get their relationships
    const claimIds = this.data.nodes
      .filter(n => n.type === 'claim')
      .map(n => n.id);

    // This is simplified - in production, batch query all relationships
    // For now, we'll create some demo links
    this.data.links = [
      // Add your relationship loading logic here
    ];
  }

  /**
   * Render the graph
   */
  render() {
    if (!this.data) {
      console.error('No data to render');
      return;
    }

    // Initialize force simulation
    this.simulation = d3.forceSimulation(this.data.nodes)
      .force('link', d3.forceLink(this.data.links)
        .id(d => d.id)
        .distance(100))
      .force('charge', d3.forceManyBody().strength(-300))
      .force('center', d3.forceCenter(this.width / 2, this.height / 2))
      .force('collision', d3.forceCollide().radius(40));

    const g = this.svg.select('g');

    // Links
    const link = g.append('g')
      .attr('class', 'links')
      .selectAll('line')
      .data(this.data.links)
      .join('line')
      .attr('stroke', d => this.getRelationshipColor(d.relationshipType))
      .attr('stroke-width', d => Math.abs(d.weight) * 3)
      .attr('stroke-opacity', d => d.confidence)
      .attr('marker-end', d => `url(#arrow-${d.relationshipType})`);

    // Nodes
    const node = g.append('g')
      .attr('class', 'nodes')
      .selectAll('g')
      .data(this.data.nodes)
      .join('g')
      .call(this.drag(this.simulation));

    // Node circles
    node.append('circle')
      .attr('r', d => d.type === 'claim' ? 20 : 15)
      .attr('fill', d => this.getNodeColor(d))
      .attr('stroke', '#fff')
      .attr('stroke-width', 2);

    // Node labels
    node.append('text')
      .text(d => d.label)
      .attr('x', 0)
      .attr('y', -25)
      .attr('text-anchor', 'middle')
      .attr('font-size', '10px')
      .attr('fill', '#333');

    // PROMPT score badge
    node.append('circle')
      .attr('r', 8)
      .attr('cx', 15)
      .attr('cy', -15)
      .attr('fill', d => this.getPromptScoreColor(d.promptScore))
      .attr('stroke', '#fff')
      .attr('stroke-width', 1);

    node.append('text')
      .text(d => Math.round(d.promptScore))
      .attr('x', 15)
      .attr('y', -12)
      .attr('text-anchor', 'middle')
      .attr('font-size', '8px')
      .attr('fill', '#fff');

    // Tooltips
    node.on('mouseover', (event, d) => {
      this.showTooltip(event, d);
    }).on('mouseout', () => {
      this.hideTooltip();
    });

    // Update positions on tick
    this.simulation.on('tick', () => {
      link
        .attr('x1', d => d.source.x)
        .attr('y1', d => d.source.y)
        .attr('x2', d => d.target.x)
        .attr('y2', d => d.target.y);

      node.attr('transform', d => `translate(${d.x},${d.y})`);
    });
  }

  /**
   * Node color based on type and PROMPT score
   */
  getNodeColor(node) {
    if (node.type === 'claim') {
      return this.getPromptScoreColor(node.promptScore);
    } else {
      return this.getPromptScoreColor(node.promptScore, 0.7); // Lighter for evidence
    }
  }

  /**
   * Color scale for PROMPT scores (0-100)
   * Red (low) → Yellow (medium) → Green (high)
   */
  getPromptScoreColor(score, opacity = 1.0) {
    const colorScale = d3.scaleSequential()
      .domain([0, 100])
      .interpolator(d3.interpolateRdYlGn);

    const color = d3.color(colorScale(score));
    color.opacity = opacity;
    return color;
  }

  /**
   * Relationship type colors
   */
  getRelationshipColor(type) {
    const colors = {
      supports: '#28a745',      // Green
      contradicts: '#dc3545',   // Red
      contextualizes: '#6c757d' // Gray
    };
    return colors[type] || '#999';
  }

  /**
   * Drag behavior
   */
  drag(simulation) {
    function dragstarted(event) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      event.subject.fx = event.subject.x;
      event.subject.fy = event.subject.y;
    }

    function dragged(event) {
      event.subject.fx = event.x;
      event.subject.fy = event.y;
    }

    function dragended(event) {
      if (!event.active) simulation.alphaTarget(0);
      event.subject.fx = null;
      event.subject.fy = null;
    }

    return d3.drag()
      .on('start', dragstarted)
      .on('drag', dragged)
      .on('end', dragended);
  }

  /**
   * Show tooltip
   */
  showTooltip(event, node) {
    const tooltip = d3.select('body').append('div')
      .attr('class', 'graph-tooltip')
      .style('position', 'absolute')
      .style('background', 'rgba(0,0,0,0.8)')
      .style('color', '#fff')
      .style('padding', '10px')
      .style('border-radius', '5px')
      .style('pointer-events', 'none')
      .style('z-index', '1000');

    if (node.type === 'claim') {
      tooltip.html(`
        <strong>Claim</strong><br/>
        ${node.text}<br/>
        <br/>
        <strong>PROMPT Score:</strong> ${Math.round(node.promptScore)}/100<br/>
        Provenance: ${node.promptScores.provenance}<br/>
        Methodology: ${node.promptScores.methodology}
      `);
    } else {
      tooltip.html(`
        <strong>Evidence:</strong> ${node.evidenceType}<br/>
        ${node.title}<br/>
        <br/>
        <strong>PROMPT Score:</strong> ${Math.round(node.promptScore)}/100
      `);
    }

    tooltip
      .style('left', (event.pageX + 10) + 'px')
      .style('top', (event.pageY - 10) + 'px');
  }

  /**
   * Hide tooltip
   */
  hideTooltip() {
    d3.selectAll('.graph-tooltip').remove();
  }

  /**
   * Filter by audience type (applies PROMPT weighting)
   */
  filterByAudience(audienceType) {
    // Re-calculate node sizes based on audience weights
    // Highlight evidence that scores well for this audience
    // This is Phase 2 functionality
  }

  /**
   * Highlight path
   */
  highlightPath(pathNodes) {
    // Highlight nodes and links in a navigation path
    // Fade out non-path elements
    // This is Phase 2 functionality
  }
}

// Export for use in Phoenix LiveView
export default EvidenceGraphViz;
