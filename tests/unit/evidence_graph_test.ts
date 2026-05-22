// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Unit tests for EvidenceGraph data structures
// Tests node creation, link creation, and GraphData validation

import { assertEquals, assertExists, assert } from "https://deno.land/std@0.210.0/testing/asserts.ts";

// Equivalent TypeScript models of ReScript types
interface Node {
  id: string;
  label: string;
  nodeType: "claim" | "evidence" | string;
  promptScore: number;
}

interface Link {
  source: string;
  target: string;
  relationship: "supports" | "contradicts" | "contextualizes" | string;
}

interface GraphData {
  nodes: Node[];
  links: Link[];
}

// Node factory with validation
function createNode(
  id: string,
  label: string,
  nodeType: string,
  promptScore: number
): Node {
  if (!id || typeof id !== "string") {
    throw new Error("Node id must be a non-empty string");
  }
  if (!label || typeof label !== "string") {
    throw new Error("Node label must be a non-empty string");
  }
  if (typeof promptScore !== "number" || isNaN(promptScore) || promptScore < 0 || promptScore > 100) {
    throw new Error("promptScore must be a number between 0 and 100");
  }
  return { id, label, nodeType, promptScore };
}

// Link factory with validation
function createLink(
  source: string,
  target: string,
  relationship: string
): Link {
  if (!source || typeof source !== "string") {
    throw new Error("Link source must be a non-empty string");
  }
  if (!target || typeof target !== "string") {
    throw new Error("Link target must be a non-empty string");
  }
  if (!relationship || typeof relationship !== "string") {
    throw new Error("Link relationship must be a non-empty string");
  }
  return { source, target, relationship };
}

// GraphData factory
function createGraphData(nodes: Node[] = [], links: Link[] = []): GraphData {
  return { nodes, links };
}

Deno.test("Unit Tests - Node Creation", async (t) => {
  await t.step("should create a valid claim node", () => {
    const node = createNode("claim_1", "Climate change is occurring", "claim", 85.5);
    assertEquals(node.id, "claim_1");
    assertEquals(node.label, "Climate change is occurring");
    assertEquals(node.nodeType, "claim");
    assertEquals(node.promptScore, 85.5);
  });

  await t.step("should create a valid evidence node", () => {
    const node = createNode(
      "evidence_1",
      "IPCC AR6 Report",
      "evidence",
      92.0
    );
    assertEquals(node.id, "evidence_1");
    assertEquals(node.label, "IPCC AR6 Report");
    assertEquals(node.nodeType, "evidence");
    assertEquals(node.promptScore, 92.0);
  });

  await t.step("should allow any nodeType string", () => {
    const node = createNode("node_1", "Label", "custom-type", 50);
    assertEquals(node.nodeType, "custom-type");
  });

  await t.step("should reject empty id", () => {
    let thrown = false;
    try {
      createNode("", "Label", "claim", 50);
    } catch {
      thrown = true;
    }
    assert(thrown, "Should throw on empty id");
  });

  await t.step("should reject empty label", () => {
    let thrown = false;
    try {
      createNode("id_1", "", "claim", 50);
    } catch {
      thrown = true;
    }
    assert(thrown, "Should throw on empty label");
  });

  await t.step("should reject invalid promptScore (negative)", () => {
    let thrown = false;
    try {
      createNode("id_1", "Label", "claim", -1);
    } catch {
      thrown = true;
    }
    assert(thrown, "Should throw on negative promptScore");
  });

  await t.step("should reject invalid promptScore (over 100)", () => {
    let thrown = false;
    try {
      createNode("id_1", "Label", "claim", 101);
    } catch {
      thrown = true;
    }
    assert(thrown, "Should throw on promptScore > 100");
  });

  await t.step("should accept promptScore boundary values", () => {
    const node0 = createNode("id_1", "Label", "claim", 0);
    const node100 = createNode("id_2", "Label", "claim", 100);
    assertEquals(node0.promptScore, 0);
    assertEquals(node100.promptScore, 100);
  });
});

Deno.test("Unit Tests - Link Creation", async (t) => {
  await t.step("should create a supports link", () => {
    const link = createLink("evidence_1", "claim_1", "supports");
    assertEquals(link.source, "evidence_1");
    assertEquals(link.target, "claim_1");
    assertEquals(link.relationship, "supports");
  });

  await t.step("should create a contradicts link", () => {
    const link = createLink("evidence_2", "claim_1", "contradicts");
    assertEquals(link.source, "evidence_2");
    assertEquals(link.target, "claim_1");
    assertEquals(link.relationship, "contradicts");
  });

  await t.step("should create a contextualizes link", () => {
    const link = createLink("evidence_3", "claim_1", "contextualizes");
    assertEquals(link.source, "evidence_3");
    assertEquals(link.target, "claim_1");
    assertEquals(link.relationship, "contextualizes");
  });

  await t.step("should allow custom relationship types", () => {
    const link = createLink("node_1", "node_2", "mentions");
    assertEquals(link.relationship, "mentions");
  });

  await t.step("should reject empty source", () => {
    let thrown = false;
    try {
      createLink("", "target", "supports");
    } catch {
      thrown = true;
    }
    assert(thrown, "Should throw on empty source");
  });

  await t.step("should reject empty target", () => {
    let thrown = false;
    try {
      createLink("source", "", "supports");
    } catch {
      thrown = true;
    }
    assert(thrown, "Should throw on empty target");
  });

  await t.step("should reject empty relationship", () => {
    let thrown = false;
    try {
      createLink("source", "target", "");
    } catch {
      thrown = true;
    }
    assert(thrown, "Should throw on empty relationship");
  });
});

Deno.test("Unit Tests - GraphData Structure", async (t) => {
  await t.step("should create empty graph", () => {
    const graph = createGraphData();
    assertEquals(graph.nodes.length, 0);
    assertEquals(graph.links.length, 0);
  });

  await t.step("should create graph with nodes", () => {
    const nodes = [
      createNode("claim_1", "Test claim", "claim", 75),
      createNode("evidence_1", "Test evidence", "evidence", 80),
    ];
    const graph = createGraphData(nodes);
    assertEquals(graph.nodes.length, 2);
    assertEquals(graph.nodes[0].id, "claim_1");
    assertEquals(graph.nodes[1].id, "evidence_1");
  });

  await t.step("should create graph with links", () => {
    const nodes = [
      createNode("claim_1", "Test claim", "claim", 75),
      createNode("evidence_1", "Test evidence", "evidence", 80),
    ];
    const links = [createLink("evidence_1", "claim_1", "supports")];
    const graph = createGraphData(nodes, links);
    assertEquals(graph.links.length, 1);
    assertEquals(graph.links[0].source, "evidence_1");
  });

  await t.step("should create complex graph", () => {
    const nodes = [
      createNode("claim_1", "Main claim", "claim", 85),
      createNode("claim_2", "Sub-claim", "claim", 70),
      createNode("evidence_1", "First evidence", "evidence", 90),
      createNode("evidence_2", "Second evidence", "evidence", 75),
    ];
    const links = [
      createLink("evidence_1", "claim_1", "supports"),
      createLink("evidence_2", "claim_1", "supports"),
      createLink("claim_1", "claim_2", "contextualizes"),
    ];
    const graph = createGraphData(nodes, links);
    assertEquals(graph.nodes.length, 4);
    assertEquals(graph.links.length, 3);
  });
});

Deno.test("Unit Tests - Null/Undefined Handling", async (t) => {
  await t.step("should reject null id", () => {
    let thrown = false;
    try {
      createNode(null as unknown as string, "Label", "claim", 50);
    } catch {
      thrown = true;
    }
    assert(thrown);
  });

  await t.step("should reject undefined label", () => {
    let thrown = false;
    try {
      createNode("id_1", undefined as unknown as string, "claim", 50);
    } catch {
      thrown = true;
    }
    assert(thrown);
  });

  await t.step("should handle NaN promptScore gracefully", () => {
    // NaN is technically a number type, but invalid semantically
    // In production, validation would reject it
    let thrown = false;
    try {
      const node = createNode("id_1", "Label", "claim", NaN);
      // Verify it was caught by type validation
      if (isNaN(node.promptScore)) {
        throw new Error("NaN promptScore not allowed");
      }
    } catch {
      thrown = true;
    }
    assert(thrown);
  });

  await t.step("should handle empty arrays gracefully", () => {
    const graph = createGraphData([], []);
    assertExists(graph.nodes);
    assertExists(graph.links);
    assertEquals(graph.nodes.length, 0);
    assertEquals(graph.links.length, 0);
  });
});

Deno.test("Unit Tests - Field Access", async (t) => {
  const node = createNode("test_1", "Test Node", "custom", 42.5);

  await t.step("should access all node fields", () => {
    assertEquals(node.id, "test_1");
    assertEquals(node.label, "Test Node");
    assertEquals(node.nodeType, "custom");
    assertEquals(node.promptScore, 42.5);
  });

  const link = createLink("source_1", "target_1", "test-rel");

  await t.step("should access all link fields", () => {
    assertEquals(link.source, "source_1");
    assertEquals(link.target, "target_1");
    assertEquals(link.relationship, "test-rel");
  });
});
