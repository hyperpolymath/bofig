// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Benchmarks for EvidenceGraph performance
// Tests performance of core operations: node creation, traversal, serialization

interface Node {
  id: string;
  label: string;
  nodeType: string;
  promptScore: number;
}

interface Link {
  source: string;
  target: string;
  relationship: string;
}

interface GraphData {
  nodes: Node[];
  links: Link[];
}

// Helper: create node
function createNode(
  id: string,
  label: string,
  nodeType: string,
  promptScore: number
): Node {
  return { id, label, nodeType, promptScore };
}

// Helper: create link
function createLink(
  source: string,
  target: string,
  relationship: string
): Link {
  return { source, target, relationship };
}

// Helper: create graph with N nodes
function createGraphWithNodes(n: number): GraphData {
  const nodes: Node[] = [];
  for (let i = 0; i < n; i++) {
    nodes.push(
      createNode(
        `node_${i}`,
        `Node ${i}`,
        i % 2 === 0 ? "claim" : "evidence",
        Math.random() * 100
      )
    );
  }
  return { nodes, links: [] };
}

// Helper: create graph with links
function createGraphWithLinks(nodeCount: number, linkCount: number): GraphData {
  const nodes: Node[] = [];
  for (let i = 0; i < nodeCount; i++) {
    nodes.push(
      createNode(`node_${i}`, `Node ${i}`, "claim", Math.random() * 100)
    );
  }

  const links: Link[] = [];
  for (let i = 0; i < linkCount && i < nodeCount * nodeCount; i++) {
    const source = Math.floor(Math.random() * nodeCount);
    const target = Math.floor(Math.random() * nodeCount);
    if (source !== target) {
      links.push(createLink(nodes[source].id, nodes[target].id, "supports"));
    }
  }

  return { nodes, links };
}

// Benchmark: Node array creation
Deno.bench("Benchmark: Create 100 nodes", () => {
  createGraphWithNodes(100);
});

Deno.bench("Benchmark: Create 1,000 nodes", () => {
  createGraphWithNodes(1000);
});

Deno.bench("Benchmark: Create 10,000 nodes", () => {
  createGraphWithNodes(10000);
});

// Benchmark: Link traversal on populated graph
Deno.bench("Benchmark: Traverse 100 nodes with 500 links", () => {
  const graph = createGraphWithLinks(100, 500);
  let count = 0;
  for (const link of graph.links) {
    count++;
  }
});

Deno.bench("Benchmark: Traverse 1,000 nodes with 5,000 links", () => {
  const graph = createGraphWithLinks(1000, 5000);
  let count = 0;
  for (const link of graph.links) {
    count++;
  }
});

Deno.bench("Benchmark: Traverse 5,000 nodes with 50,000 links", () => {
  const graph = createGraphWithLinks(5000, 50000);
  let count = 0;
  for (const link of graph.links) {
    count++;
  }
});

// Benchmark: GraphData serialization
Deno.bench("Benchmark: Serialize 100-node graph", () => {
  const graph = createGraphWithNodes(100);
  JSON.stringify(graph);
});

Deno.bench("Benchmark: Serialize 1,000-node graph", () => {
  const graph = createGraphWithNodes(1000);
  JSON.stringify(graph);
});

Deno.bench("Benchmark: Serialize 10,000-node graph", () => {
  const graph = createGraphWithNodes(10000);
  JSON.stringify(graph);
});

// Benchmark: GraphData deserialization
Deno.bench("Benchmark: Deserialize 100-node graph", () => {
  const graph = createGraphWithNodes(100);
  const json = JSON.stringify(graph);
  JSON.parse(json);
});

Deno.bench("Benchmark: Deserialize 1,000-node graph", () => {
  const graph = createGraphWithNodes(1000);
  const json = JSON.stringify(graph);
  JSON.parse(json);
});

Deno.bench("Benchmark: Deserialize 10,000-node graph", () => {
  const graph = createGraphWithNodes(10000);
  const json = JSON.stringify(graph);
  JSON.parse(json);
});

// Benchmark: Filter operations
Deno.bench("Benchmark: Filter 1,000 nodes by type", () => {
  const graph = createGraphWithNodes(1000);
  const filtered = graph.nodes.filter((n) => n.nodeType === "claim");
  filtered.length;
});

Deno.bench("Benchmark: Filter 10,000 nodes by type", () => {
  const graph = createGraphWithNodes(10000);
  const filtered = graph.nodes.filter((n) => n.nodeType === "claim");
  filtered.length;
});

// Benchmark: Search by ID
Deno.bench("Benchmark: Find node in 1,000-node graph", () => {
  const graph = createGraphWithNodes(1000);
  const found = graph.nodes.find((n) => n.id === "node_500");
  found;
});

Deno.bench("Benchmark: Find node in 10,000-node graph", () => {
  const graph = createGraphWithNodes(10000);
  const found = graph.nodes.find((n) => n.id === "node_5000");
  found;
});

// Benchmark: promptScore aggregation
Deno.bench("Benchmark: Calculate average promptScore (1,000 nodes)", () => {
  const graph = createGraphWithNodes(1000);
  const sum = graph.nodes.reduce((acc, n) => acc + n.promptScore, 0);
  const avg = sum / graph.nodes.length;
  avg;
});

Deno.bench("Benchmark: Calculate average promptScore (10,000 nodes)", () => {
  const graph = createGraphWithNodes(10000);
  const sum = graph.nodes.reduce((acc, n) => acc + n.promptScore, 0);
  const avg = sum / graph.nodes.length;
  avg;
});

// Benchmark: Node deduplication
Deno.bench("Benchmark: Deduplicate 1,000 nodes by ID", () => {
  const graph = createGraphWithNodes(1000);
  const unique = new Set(graph.nodes.map((n) => n.id));
  unique.size;
});

Deno.bench("Benchmark: Deduplicate 10,000 nodes by ID", () => {
  const graph = createGraphWithNodes(10000);
  const unique = new Set(graph.nodes.map((n) => n.id));
  unique.size;
});

// Benchmark: Link lookup by source
Deno.bench("Benchmark: Find links by source (5,000 links)", () => {
  const graph = createGraphWithLinks(100, 5000);
  const sourceLinks = graph.links.filter((l) => l.source === "node_0");
  sourceLinks.length;
});

Deno.bench("Benchmark: Find links by source (50,000 links)", () => {
  const graph = createGraphWithLinks(500, 50000);
  const sourceLinks = graph.links.filter((l) => l.source === "node_0");
  sourceLinks.length;
});

// Benchmark: Round-trip serialization
Deno.bench("Benchmark: Serialize/deserialize 1,000-node graph", () => {
  const graph = createGraphWithNodes(1000);
  const json = JSON.stringify(graph);
  JSON.parse(json);
});

Deno.bench("Benchmark: Serialize/deserialize 5,000-node graph", () => {
  const graph = createGraphWithNodes(5000);
  const json = JSON.stringify(graph);
  JSON.parse(json);
});

// Benchmark: Node property access
Deno.bench("Benchmark: Access all fields in 10,000 nodes", () => {
  const graph = createGraphWithNodes(10000);
  let sum = 0;
  for (const node of graph.nodes) {
    sum += node.id.length + node.label.length + node.promptScore;
  }
  sum;
});

// Benchmark: Bulk operations
Deno.bench("Benchmark: Create and serialize 10K-node graph", () => {
  const graph = createGraphWithNodes(10000);
  JSON.stringify(graph);
});

Deno.bench("Benchmark: Create 10K-node graph with 100K links", () => {
  createGraphWithLinks(10000, 100000);
});
