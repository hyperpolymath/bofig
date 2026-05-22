// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// End-to-end tests for EvidenceGraph
// Tests complete lifecycle: create → add nodes → add links → serialize → deserialize

import {
  assertEquals,
  assert,
  assertExists,
} from "https://deno.land/std@0.210.0/testing/asserts.ts";

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

// Graph class for E2E tests
class EvidenceGraph {
  nodes: Node[] = [];
  links: Link[] = [];

  addNode(
    id: string,
    label: string,
    nodeType: string,
    promptScore: number
  ): Node {
    if (!id || !label) throw new Error("ID and label required");
    if (this.nodes.some((n) => n.id === id)) {
      throw new Error(`Node ${id} already exists`);
    }
    const node: Node = { id, label, nodeType, promptScore };
    this.nodes.push(node);
    return node;
  }

  addLink(source: string, target: string, relationship: string): Link {
    if (!this.nodes.some((n) => n.id === source)) {
      throw new Error(`Source node ${source} not found`);
    }
    if (!this.nodes.some((n) => n.id === target)) {
      throw new Error(`Target node ${target} not found`);
    }

    const link: Link = { source, target, relationship };
    this.links.push(link);
    return link;
  }

  getData(): GraphData {
    return {
      nodes: [...this.nodes],
      links: [...this.links],
    };
  }

  serialize(): string {
    return JSON.stringify(this.getData());
  }

  static deserialize(json: string): EvidenceGraph {
    const data = JSON.parse(json) as GraphData;
    const graph = new EvidenceGraph();
    graph.nodes = data.nodes;
    graph.links = data.links;
    return graph;
  }

  getNode(id: string): Node | undefined {
    return this.nodes.find((n) => n.id === id);
  }

  getLinksForNode(id: string): Link[] {
    return this.links.filter((l) => l.source === id || l.target === id);
  }

  filterByNodeType(nodeType: string): Node[] {
    return this.nodes.filter((n) => n.nodeType === nodeType);
  }

  isEmpty(): boolean {
    return this.nodes.length === 0 && this.links.length === 0;
  }
}

// E2E Tests
Deno.test("E2E Tests - Basic Lifecycle", async (t) => {
  await t.step(
    "should create empty graph and verify empty state",
    () => {
      const graph = new EvidenceGraph();
      assert(graph.isEmpty());
      assertEquals(graph.nodes.length, 0);
      assertEquals(graph.links.length, 0);
    }
  );

  await t.step(
    "should add single node and verify it exists",
    () => {
      const graph = new EvidenceGraph();
      const node = graph.addNode("claim_1", "Test claim", "claim", 75);

      assertEquals(graph.nodes.length, 1);
      assertEquals(graph.getNode("claim_1"), node);
      assert(!graph.isEmpty());
    }
  );

  await t.step(
    "should add multiple nodes and verify all exist",
    () => {
      const graph = new EvidenceGraph();
      const claim = graph.addNode(
        "claim_1",
        "Climate change is real",
        "claim",
        85
      );
      const evidence = graph.addNode(
        "evidence_1",
        "IPCC Report",
        "evidence",
        92
      );

      assertEquals(graph.nodes.length, 2);
      assertEquals(graph.getNode("claim_1"), claim);
      assertEquals(graph.getNode("evidence_1"), evidence);
    }
  );
});

Deno.test("E2E Tests - Link Management", async (t) => {
  await t.step(
    "should add link between two nodes",
    () => {
      const graph = new EvidenceGraph();
      graph.addNode("claim_1", "Claim", "claim", 75);
      graph.addNode("evidence_1", "Evidence", "evidence", 90);

      const link = graph.addLink("evidence_1", "claim_1", "supports");
      assertEquals(graph.links.length, 1);
      assertEquals(link.source, "evidence_1");
      assertEquals(link.target, "claim_1");
      assertEquals(link.relationship, "supports");
    }
  );

  await t.step(
    "should reject link with non-existent source node",
    () => {
      const graph = new EvidenceGraph();
      graph.addNode("claim_1", "Claim", "claim", 75);

      let thrown = false;
      try {
        graph.addLink("nonexistent", "claim_1", "supports");
      } catch {
        thrown = true;
      }
      assert(thrown);
    }
  );

  await t.step(
    "should reject link with non-existent target node",
    () => {
      const graph = new EvidenceGraph();
      graph.addNode("evidence_1", "Evidence", "evidence", 90);

      let thrown = false;
      try {
        graph.addLink("evidence_1", "nonexistent", "supports");
      } catch {
        thrown = true;
      }
      assert(thrown);
    }
  );

  await t.step(
    "should allow multiple links to same node",
    () => {
      const graph = new EvidenceGraph();
      graph.addNode("claim_1", "Claim", "claim", 75);
      graph.addNode("evidence_1", "E1", "evidence", 90);
      graph.addNode("evidence_2", "E2", "evidence", 85);

      graph.addLink("evidence_1", "claim_1", "supports");
      graph.addLink("evidence_2", "claim_1", "supports");

      assertEquals(graph.links.length, 2);
    }
  );
});

Deno.test("E2E Tests - Serialization & Deserialization", async (t) => {
  await t.step(
    "should serialize empty graph to JSON",
    () => {
      const graph = new EvidenceGraph();
      const json = graph.serialize();
      const parsed = JSON.parse(json) as GraphData;

      assertEquals(parsed.nodes.length, 0);
      assertEquals(parsed.links.length, 0);
    }
  );

  await t.step(
    "should serialize graph with nodes to JSON",
    () => {
      const graph = new EvidenceGraph();
      graph.addNode("claim_1", "Test claim", "claim", 75);
      graph.addNode("evidence_1", "Test evidence", "evidence", 85);

      const json = graph.serialize();
      const parsed = JSON.parse(json) as GraphData;

      assertEquals(parsed.nodes.length, 2);
      assertEquals(parsed.nodes[0].id, "claim_1");
      assertEquals(parsed.nodes[1].id, "evidence_1");
    }
  );

  await t.step(
    "should serialize graph with links to JSON",
    () => {
      const graph = new EvidenceGraph();
      graph.addNode("claim_1", "Claim", "claim", 75);
      graph.addNode("evidence_1", "Evidence", "evidence", 85);
      graph.addLink("evidence_1", "claim_1", "supports");

      const json = graph.serialize();
      const parsed = JSON.parse(json) as GraphData;

      assertEquals(parsed.links.length, 1);
      assertEquals(parsed.links[0].source, "evidence_1");
      assertEquals(parsed.links[0].relationship, "supports");
    }
  );

  await t.step(
    "should deserialize JSON back to EvidenceGraph",
    () => {
      const original = new EvidenceGraph();
      original.addNode("claim_1", "Test claim", "claim", 75);
      original.addNode("evidence_1", "Test evidence", "evidence", 85);
      original.addLink("evidence_1", "claim_1", "supports");

      const json = original.serialize();
      const restored = EvidenceGraph.deserialize(json);

      assertEquals(restored.nodes.length, 2);
      assertEquals(restored.links.length, 1);
      assertEquals(restored.getNode("claim_1")?.label, "Test claim");
    }
  );

  await t.step(
    "should maintain data integrity through serialize/deserialize cycle",
    () => {
      const original = new EvidenceGraph();
      const node1 = original.addNode("n1", "Node 1", "claim", 50);
      const node2 = original.addNode("n2", "Node 2", "evidence", 75);
      const node3 = original.addNode("n3", "Node 3", "claim", 90);

      original.addLink("n2", "n1", "supports");
      original.addLink("n3", "n1", "contextualizes");

      const json = original.serialize();
      const restored = EvidenceGraph.deserialize(json);

      assertEquals(restored.nodes.length, 3);
      assertEquals(restored.links.length, 2);

      const restored2 = restored.getNode("n2");
      assertExists(restored2);
      assertEquals(restored2.id, node2.id);
      assertEquals(restored2.label, node2.label);
      assertEquals(restored2.promptScore, node2.promptScore);
    }
  );
});

Deno.test("E2E Tests - Complete Workflow", async (t) => {
  await t.step(
    "should complete full investigation workflow",
    () => {
      // Create investigation
      const investigation = new EvidenceGraph();

      // Add claims
      investigation.addNode(
        "claim_climate_change",
        "Global temperatures rising",
        "claim",
        88
      );
      investigation.addNode(
        "claim_human_caused",
        "Caused by human activity",
        "claim",
        82
      );

      // Add evidence
      investigation.addNode(
        "evidence_ipcc",
        "IPCC AR6 Report",
        "evidence",
        95
      );
      investigation.addNode(
        "evidence_nasa",
        "NASA temperature data",
        "evidence",
        93
      );
      investigation.addNode(
        "evidence_skeptic",
        "Solar cycle hypothesis",
        "evidence",
        40
      );

      // Add relationships
      investigation.addLink(
        "evidence_ipcc",
        "claim_climate_change",
        "supports"
      );
      investigation.addLink(
        "evidence_nasa",
        "claim_climate_change",
        "supports"
      );
      investigation.addLink(
        "evidence_skeptic",
        "claim_climate_change",
        "contradicts"
      );
      investigation.addLink(
        "evidence_ipcc",
        "claim_human_caused",
        "supports"
      );

      const data = investigation.getData();
      assertEquals(data.nodes.length, 5);
      assertEquals(data.links.length, 4);

      // Verify claims
      const claims = investigation.filterByNodeType("claim");
      assertEquals(claims.length, 2);

      // Verify evidence
      const evidence = investigation.filterByNodeType("evidence");
      assertEquals(evidence.length, 3);
    }
  );

  await t.step(
    "should handle graph update and re-serialization",
    () => {
      const graph = new EvidenceGraph();
      graph.addNode("n1", "Initial", "claim", 50);

      const v1 = graph.serialize();

      graph.addNode("n2", "Added later", "evidence", 75);
      graph.addLink("n2", "n1", "supports");

      const v2 = graph.serialize();

      // Verify changes
      const data1 = JSON.parse(v1) as GraphData;
      const data2 = JSON.parse(v2) as GraphData;

      assertEquals(data1.nodes.length, 1);
      assertEquals(data2.nodes.length, 2);
      assertEquals(data2.links.length, 1);
    }
  );
});

Deno.test("E2E Tests - Query Operations", async (t) => {
  const setupGraph = (): EvidenceGraph => {
    const g = new EvidenceGraph();
    g.addNode("claim_1", "Main claim", "claim", 80);
    g.addNode("evidence_1", "E1", "evidence", 90);
    g.addNode("evidence_2", "E2", "evidence", 85);
    g.addNode("counterevid", "Counter evidence", "evidence", 30);
    g.addLink("evidence_1", "claim_1", "supports");
    g.addLink("evidence_2", "claim_1", "supports");
    g.addLink("counterevid", "claim_1", "contradicts");
    return g;
  };

  await t.step("should find node by ID", () => {
    const graph = setupGraph();
    const node = graph.getNode("claim_1");
    assertExists(node);
    assertEquals(node.label, "Main claim");
  });

  await t.step(
    "should return undefined for non-existent node",
    () => {
      const graph = setupGraph();
      const node = graph.getNode("nonexistent");
      assert(node === undefined);
    }
  );

  await t.step("should get links for a node", () => {
    const graph = setupGraph();
    const links = graph.getLinksForNode("claim_1");
    assertEquals(links.length, 3);
  });

  await t.step("should filter nodes by type", () => {
    const graph = setupGraph();
    const claims = graph.filterByNodeType("claim");
    const evidence = graph.filterByNodeType("evidence");
    assertEquals(claims.length, 1);
    assertEquals(evidence.length, 3);
  });
});
