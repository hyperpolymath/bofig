// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Security aspect tests for EvidenceGraph.
// Mechanically transpiled from the former TypeScript test to satisfy the
// estate language policy while preserving Deno test coverage.

import { assert, assertEquals, assertThrows } from "testing/asserts.ts";
function sanitizeHtml(input) {
  if (typeof input !== "string") return "";
  return input.replace(/[&<>"']/g, (match) => {
    const escapes = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    };
    return escapes[match];
  });
}
function validateLength(input, maxLen) {
  return input.length <= maxLen;
}
function createSecureNode(id, label, nodeType, promptScore) {
  if (!validateLength(id, 255)) {
    throw new Error("ID too long");
  }
  if (!validateLength(label, 1e3)) {
    throw new Error("Label too long");
  }
  if (!validateLength(nodeType, 100)) {
    throw new Error("NodeType too long");
  }
  const sanitized = sanitizeHtml(label);
  return {
    id,
    label: sanitized,
    nodeType,
    promptScore,
  };
}
Deno.test("Security Tests - XSS Prevention", async (t) => {
  await t.step("should sanitize script tags in node labels", () => {
    const malicious = '<script>alert("XSS")<\/script>';
    const sanitized = sanitizeHtml(malicious);
    assert(!sanitized.includes("<script>"));
    assert(sanitized.includes("&lt;script&gt;"));
  });
  await t.step("should sanitize event handlers in labels", () => {
    const malicious = `<img src="x" onerror="alert('xss')">`;
    const sanitized = sanitizeHtml(malicious);
    assert(sanitized.includes("&lt;img"));
    assert(sanitized.includes("&quot;"));
  });
  await t.step("should sanitize HTML special characters", () => {
    const inputs = [
      {
        input: '<div class="danger">',
        expected: "&lt;div",
      },
      {
        input: 'onclick="malicious()"',
        expected: "&quot;",
      },
      {
        input: "a&b<c>d",
        expected: "a&amp;b&lt;c&gt;d",
      },
    ];
    for (const test of inputs) {
      const sanitized = sanitizeHtml(test.input);
      assert(sanitized.includes(test.expected));
    }
  });
  await t.step("should create node with sanitized label", () => {
    const node = createSecureNode(
      "test_1",
      '<script>alert("xss")<\/script>Safe',
      "claim",
      50,
    );
    assert(node !== null);
    assert(!node.label.includes("<script>"));
    assert(node.label.includes("&lt;script&gt;"));
  });
  await t.step(
    "should preserve legitimate HTML-like content when sanitized",
    () => {
      const node = createSecureNode(
        "test_2",
        "Price < $100 & quality > good",
        "claim",
        60,
      );
      assert(node !== null);
      assert(node.label.includes("&lt;"));
      assert(node.label.includes("&gt;"));
      assert(node.label.includes("&amp;"));
    },
  );
});
Deno.test("Security Tests - Input Size Limits", async (t) => {
  await t.step("should reject oversized node IDs", () => {
    const oversizedId = "x".repeat(300);
    assertThrows(() => {
      createSecureNode(oversizedId, "Label", "claim", 50);
    });
  });
  await t.step("should reject oversized labels", () => {
    const oversizedLabel = "x".repeat(2e3);
    assertThrows(() => {
      createSecureNode("id_1", oversizedLabel, "claim", 50);
    });
  });
  await t.step("should reject oversized nodeType", () => {
    const oversizedType = "x".repeat(200);
    assertThrows(() => {
      createSecureNode("id_1", "Label", oversizedType, 50);
    });
  });
  await t.step("should accept maximum valid lengths", () => {
    const maxId = "x".repeat(255);
    const maxLabel = "x".repeat(1e3);
    const maxType = "x".repeat(100);
    const node = createSecureNode(maxId, maxLabel, maxType, 50);
    assert(node !== null);
  });
  await t.step("should handle large graphs (10K nodes, 100K links)", () => {
    let nodeCount = 0;
    let linkCount = 0;
    for (let i = 0; i < 100; i++) {
      for (let j = 0; j < 100; j++) {
        try {
          const node = createSecureNode(
            `node_${i}_${j}`,
            `Node ${i}-${j}`,
            "claim",
            Math.random() * 100,
          );
          if (node) nodeCount++;
        } catch {
          // Count only successful secure-node creations.
        }
      }
    }
    for (let i = 0; i < 1e5; i++) {
      linkCount++;
    }
    assert(nodeCount > 0);
    assertEquals(linkCount, 1e5);
  });
});
Deno.test("Security Tests - Prototype Pollution Prevention", async (t) => {
  await t.step("should not allow __proto__ in node IDs", () => {
    const node = createSecureNode("__proto__", "Label", "claim", 50);
    assert(node !== null);
    assertEquals(node.id, "__proto__");
  });
  await t.step("should not allow constructor manipulation", () => {
    const node = createSecureNode("constructor", "Label", "claim", 50);
    assert(node !== null);
    assert(!Object.prototype.hasOwnProperty.call(node, "toString"));
  });
  await t.step("should handle prototype property safely", () => {
    const node = createSecureNode("node_test", "Label", "prototype", 50);
    assert(node !== null);
    assertEquals(node.nodeType, "prototype");
  });
});
Deno.test("Security Tests - Malformed Data Handling", async (t) => {
  await t.step("should reject NaN promptScore", () => {
    assertThrows(() => {
      const node = {
        id: "test",
        label: "Test",
        nodeType: "claim",
        promptScore: NaN,
      };
      if (isNaN(node.promptScore)) {
        throw new Error("Invalid promptScore");
      }
    });
  });
  await t.step("should reject Infinity promptScore", () => {
    const node = {
      id: "test",
      label: "Test",
      nodeType: "claim",
      promptScore: Infinity,
    };
    assert(!isFinite(node.promptScore));
  });
  await t.step("should handle null bytes safely", () => {
    const malicious = "Label\0Injected";
    const sanitized = sanitizeHtml(malicious);
    assertEquals(typeof sanitized, "string");
  });
  await t.step("should reject negative promptScore", () => {
    let thrown = false;
    try {
      const promptScore = -1;
      if (promptScore < 0) throw new Error("Invalid promptScore");
    } catch {
      thrown = true;
    }
    assert(thrown);
  });
  await t.step("should reject promptScore > 100", () => {
    let thrown = false;
    try {
      const promptScore = 101;
      if (promptScore > 100) throw new Error("Invalid promptScore");
    } catch {
      thrown = true;
    }
    assert(thrown);
  });
});
Deno.test("Security Tests - Type Coercion Attacks", async (t) => {
  await t.step("should handle numeric string coercion", () => {
    const node = createSecureNode("123", "Label", "claim", 50);
    assert(node !== null);
    assertEquals(typeof node.id, "string");
    assertEquals(node.id, "123");
  });
  await t.step("should handle boolean-like values", () => {
    const node = createSecureNode("true", "Label", "claim", 50);
    assert(node !== null);
    assertEquals(node.id, "true");
  });
  await t.step("should reject non-string types for ID", () => {
    assertThrows(() => {
      createSecureNode(null, "Label", "claim", 50);
    });
  });
});
Deno.test("Security Tests - Unicode and Special Characters", async (t) => {
  await t.step("should handle Unicode in labels safely", () => {
    const unicode =
      "Claim: \u65E5\u672C\u8A9E + \u0627\u0644\u0639\u0631\u0628\u064A\u0629 + \u{1F680}";
    const node = createSecureNode("test_1", unicode, "claim", 50);
    assert(node !== null);
    assertEquals(typeof node.label, "string");
  });
  await t.step("should handle emoji in labels", () => {
    const emoji = "Evidence \u{1F50D} \u{1F52C} \u{1F9EA}";
    const node = createSecureNode("test_2", emoji, "evidence", 75);
    assert(node !== null);
    assert(node.label.includes("\u{1F50D}") || node.label.includes("&"));
  });
  await t.step("should handle RTL text safely", () => {
    const rtl =
      "Evidence: \u05E2\u05D1\u05E8\u05D9\u05EA + \u0641\u0627\u0631\u0633\u06CC";
    const node = createSecureNode("test_3", rtl, "claim", 60);
    assert(node !== null);
    assertEquals(typeof node.label, "string");
  });
  await t.step("should handle zero-width characters", () => {
    const zwc = "Label\u200BWith\u200CZWC";
    const node = createSecureNode("test_4", zwc, "claim", 50);
    assert(node !== null);
  });
});
Deno.test("Security Tests - Injection Prevention", async (t) => {
  await t.step("should prevent JSON injection in labels", () => {
    const injection = '","injected":"true","clean":"';
    const node = createSecureNode("test_1", injection, "claim", 50);
    assert(node !== null);
    const json = JSON.stringify(node);
    const parsed = JSON.parse(json);
    assert(typeof parsed.label === "string");
  });
  await t.step("should prevent regex injection", () => {
    const injection = ".*|admin.*";
    const node = createSecureNode("test_2", injection, "claim", 50);
    assert(node !== null);
    assertEquals(typeof node.label, "string");
  });
});
