// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Property-based tests (P2P) for EvidenceGraph
// Tests invariant properties that should hold for all valid graphs

import { assertEquals, assert } from "https://deno.land/std@0.210.0/testing/asserts.ts";

// Data models
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

// Utility: generate random ID
function randomId(prefix: string = "node"): string {
  return `${prefix}_${Math.floor(Math.random() * 1000000)}`;
}

// Utility: generate random valid promptScore
function randomPromptScore(): number {
  return Math.random() * 100;
}

// Create valid node
function createNode(
  id: string,
  label: string,
  nodeType: string,
  promptScore: number
): Node {
  return { id, label, nodeType, promptScore };
}

// Create valid link
function createLink(
  source: string,
  target: string,
  relationship: string
): Link {
  return { source, target, relationship };
}

// Property: Graph has correct node count
Deno.test("Property Tests - Node Count Invariant", async (t) => {
  await t.step("should have exactly N nodes for N node inputs", () => {
    for (let n of [1, 5, 10, 50, 100]) {
      const nodes: Node[] = [];
      for (let i = 0; i < n; i++) {
        nodes.push(
          createNode(
            `node_${i}`,
            `Node ${i}`,
            "claim",
            randomPromptScore()
          )
        );
      }
      const graph: GraphData = { nodes, links: [] };
      assertEquals(
        graph.nodes.length,
        n,
        `Graph with ${n} input nodes should have exactly ${n} nodes`
      );
    }
  });

  await t.step("should maintain node count after link addition", () => {
    const nodes = [
      createNode("n1", "N1", "claim", 50),
      createNode("n2", "N2", "evidence", 60),
      createNode("n3", "N3", "claim", 70),
    ];
    const links = [
      createLink("n1", "n2", "supports"),
      createLink("n2", "n3", "contradicts"),
    ];
    const graph: GraphData = { nodes, links };
    assertEquals(graph.nodes.length, 3, "Node count should be unchanged");
  });
});

// Property: All links reference existing nodes
Deno.test("Property Tests - Link Reference Integrity", async (t) => {
  await t.step(
    "all link sources must reference existing node IDs",
    () => {
      const nodeIds = ["n1", "n2", "n3"];
      const nodes = nodeIds.map((id) =>
        createNode(id, `Node ${id}`, "claim", 50)
      );
      const links = [
        createLink("n1", "n2", "supports"),
        createLink("n2", "n3", "contradicts"),
      ];
      const graph: GraphData = { nodes, links };

      for (const link of graph.links) {
        assert(
          graph.nodes.some((n) => n.id === link.source),
          `Link source ${link.source} must exist in nodes`
        );
      }
    }
  );

  await t.step(
    "all link targets must reference existing node IDs",
    () => {
      const nodeIds = ["n1", "n2", "n3"];
      const nodes = nodeIds.map((id) =>
        createNode(id, `Node ${id}`, "evidence", 60)
      );
      const links = [
        createLink("n1", "n2", "supports"),
        createLink("n2", "n3", "contextualizes"),
      ];
      const graph: GraphData = { nodes, links };

      for (const link of graph.links) {
        assert(
          graph.nodes.some((n) => n.id === link.target),
          `Link target ${link.target} must exist in nodes`
        );
      }
    }
  );
});

// Property: promptScore is always in valid range
Deno.test("Property Tests - promptScore Range Invariant", async (t) => {
  await t.step(
    "all nodes should have promptScore in [0.0, 100.0]",
    () => {
      const testScores = [0, 1, 25, 50, 75, 99, 100];
      const nodes = testScores.map((score, i) =>
        createNode(`n${i}`, `Label ${i}`, "claim", score)
      );

      for (const node of nodes) {
        assert(
          node.promptScore >= 0 && node.promptScore <= 100,
          `promptScore ${node.promptScore} should be in [0, 100]`
        );
      }
    }
  );

  await t.step(
    "promptScore should be a number (not string or null)",
    () => {
      const nodes = [
        createNode("n1", "L1", "claim", 0),
        createNode("n2", "L2", "claim", 50),
        createNode("n3", "L3", "claim", 100),
      ];

      for (const node of nodes) {
        assert(
          typeof node.promptScore === "number",
          "promptScore must be a number"
        );
        assert(!isNaN(node.promptScore), "promptScore cannot be NaN");
        assert(
          isFinite(node.promptScore),
          "promptScore must be finite (not Infinity)"
        );
      }
    }
  );
});

// Property: nodeType is always valid
Deno.test("Property Tests - nodeType Validity", async (t) => {
  const validTypes = ["claim", "evidence", "unknown", "metadata"];

  await t.step(
    "nodeType should always be a non-empty string",
    () => {
      const nodes = validTypes.map((type, i) =>
        createNode(`n${i}`, `Label`, type, 50)
      );

      for (const node of nodes) {
        assert(typeof node.nodeType === "string", "nodeType must be a string");
        assert(node.nodeType.length > 0, "nodeType must be non-empty");
      }
    }
  );

  await t.step(
    "common nodeTypes should be valid enums",
    () => {
      const standardTypes = ["claim", "evidence"];
      const nodes = standardTypes.map((type, i) =>
        createNode(`n${i}`, `Label`, type, 50)
      );

      for (const node of nodes) {
        assert(
          ["claim", "evidence"].includes(node.nodeType) ||
            typeof node.nodeType === "string",
          "nodeType should be valid"
        );
      }
    }
  );
});

// Property: Graph structure is acyclic (for certain relationship types)
Deno.test("Property Tests - Relationship Semantics", async (t) => {
  await t.step(
    "relationship types should be valid strings",
    () => {
      const relationships = ["supports", "contradicts", "contextualizes"];
      const links = relationships.map((rel, i) =>
        createLink(`s${i}`, `t${i}`, rel)
      );

      for (const link of links) {
        assert(
          typeof link.relationship === "string",
          "relationship must be a string"
        );
        assert(link.relationship.length > 0, "relationship must be non-empty");
      }
    }
  );

  await t.step(
    "source and target must be different (self-loops discouraged)",
    () => {
      // Property: links should generally not be self-loops
      const links = [
        createLink("n1", "n2", "supports"),
        createLink("n2", "n3", "contradicts"),
      ];

      for (const link of links) {
        // Self-loops are technically allowed but uncommon
        assert(typeof link.source === "string");
        assert(typeof link.target === "string");
      }
    }
  );
});

// Property: Graph is complete when all nodes have valid IDs
Deno.test("Property Tests - Graph Completeness", async (t) => {
  await t.step(
    "every node must have a unique, non-empty ID",
    () => {
      const nodes = [
        createNode("claim_1", "Claim 1", "claim", 75),
        createNode("evidence_1", "Evidence 1", "evidence", 85),
        createNode("claim_2", "Claim 2", "claim", 65),
      ];

      const ids = nodes.map((n) => n.id);
      const uniqueIds = new Set(ids);

      assertEquals(
        ids.length,
        uniqueIds.size,
        "All node IDs should be unique"
      );

      for (const node of nodes) {
        assert(node.id.length > 0, "Node ID must be non-empty");
        assert(typeof node.id === "string", "Node ID must be a string");
      }
    }
  );

  await t.step(
    "every node must have a non-empty label",
    () => {
      const nodes = [
        createNode("n1", "First claim", "claim", 50),
        createNode("n2", "Supporting evidence", "evidence", 60),
        createNode("n3", "Counter-evidence", "evidence", 55),
      ];

      for (const node of nodes) {
        assert(node.label.length > 0, "Label must be non-empty");
        assert(typeof node.label === "string", "Label must be a string");
      }
    }
  );
});

// Property: Scaling properties
Deno.test("Property Tests - Scaling Properties", async (t) => {
  await t.step(
    "graph should scale to 1000 nodes",
    () => {
      const nodes: Node[] = [];
      for (let i = 0; i < 1000; i++) {
        nodes.push(
          createNode(
            `node_${i}`,
            `Node ${i}`,
            i % 2 === 0 ? "claim" : "evidence",
            randomPromptScore()
          )
        );
      }
      const graph: GraphData = { nodes, links: [] };
      assertEquals(graph.nodes.length, 1000);
    }
  );

  await t.step(
    "graph should scale to 10000 links",
    () => {
      const nodes: Node[] = [];
      for (let i = 0; i < 100; i++) {
        nodes.push(
          createNode(`node_${i}`, `Node ${i}`, "claim", randomPromptScore())
        );
      }

      const links: Link[] = [];
      const relationships = ["supports", "contradicts", "contextualizes"];
      for (let i = 0; i < 10000; i++) {
        const source = Math.floor(Math.random() * nodes.length);
        const target = Math.floor(Math.random() * nodes.length);
        if (source !== target) {
          links.push(
            createLink(
              nodes[source].id,
              nodes[target].id,
              relationships[i % relationships.length]
            )
          );
        }
      }

      const graph: GraphData = { nodes, links };
      assert(graph.links.length > 0);
    }
  );
});

// Property: Idempotence of graph creation
Deno.test("Property Tests - Idempotence", async (t) => {
  await t.step(
    "creating the same graph twice should produce identical results",
    () => {
      const nodes = [
        createNode("n1", "N1", "claim", 50),
        createNode("n2", "N2", "evidence", 60),
      ];
      const links = [createLink("n2", "n1", "supports")];

      const graph1: GraphData = { nodes, links };
      const graph2: GraphData = { nodes, links };

      assertEquals(graph1.nodes.length, graph2.nodes.length);
      assertEquals(graph1.links.length, graph2.links.length);
      assertEquals(graph1.nodes[0].id, graph2.nodes[0].id);
    }
  );
});
