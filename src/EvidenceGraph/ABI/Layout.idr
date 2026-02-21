||| Memory Layout Documentation for Evidence Graph
|||
||| Documents memory layout for C-compatible Evidence Graph structs.
||| Actual size/alignment verification happens in Zig via comptime assertions
||| (see ffi/zig/src/main.zig).
|||
||| SPDX-License-Identifier: PMPL-1.0-or-later
||| Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

module EvidenceGraph.ABI.Layout

import EvidenceGraph.ABI.Types
import Data.List
import Data.So

%default total

--------------------------------------------------------------------------------
-- Struct Field Layout
--------------------------------------------------------------------------------

||| A field in a C struct with its offset, size, and alignment
public export
record Field where
  constructor MkField
  name : String
  offset : Nat
  size : Nat
  alignment : Nat

||| A struct layout describes fields, total size, and required alignment
public export
record StructLayout where
  constructor MkStructLayout
  layoutName : String
  fields : List Field
  totalSize : Nat
  alignment : Nat

||| Check if a field fits within struct bounds
public export
fieldInBounds : Field -> Nat -> Bool
fieldInBounds f structSize = f.offset + f.size <= structSize

||| Check all fields fit within a struct
public export
allFieldsInBounds : StructLayout -> Bool
allFieldsInBounds layout =
  all (\f => fieldInBounds f layout.totalSize) layout.fields

--------------------------------------------------------------------------------
-- Evidence Graph Struct Layouts
--------------------------------------------------------------------------------

||| CPromptScores: 6 x uint32_t, packed, no internal padding
|||   provenance:    offset 0,  size 4, align 4
|||   replicability: offset 4,  size 4, align 4
|||   objective:     offset 8,  size 4, align 4
|||   methodology:   offset 12, size 4, align 4
|||   publication:   offset 16, size 4, align 4
|||   transparency:  offset 20, size 4, align 4
|||   Total: 24 bytes, alignment 4
public export
promptScoresLayout : StructLayout
promptScoresLayout = MkStructLayout "CPromptScores"
  [ MkField "provenance"    0  4 4
  , MkField "replicability" 4  4 4
  , MkField "objective"     8  4 4
  , MkField "methodology"   12 4 4
  , MkField "publication"   16 4 4
  , MkField "transparency"  20 4 4
  ]
  24 4

||| CClaim layout:
|||   claim_type:    offset 0,  size 4, align 4  (uint32_t enum)
|||   _padding:      offset 4,  size 4           (for double alignment)
|||   confidence:    offset 8,  size 8, align 8  (double, 0.0..1.0)
|||   prompt_scores: offset 16, size 24, align 4 (CPromptScores embedded)
|||   Total: 40 bytes, alignment 8
public export
claimLayout : StructLayout
claimLayout = MkStructLayout "CClaim"
  [ MkField "claim_type"    0  4 4
  , MkField "_pad0"         4  4 4
  , MkField "confidence"    8  8 8
  , MkField "prompt_scores" 16 24 4
  ]
  40 8

||| CRelationship layout:
|||   rel_type:   offset 0,  size 4, align 4  (uint32_t enum)
|||   _padding:   offset 4,  size 4           (for double alignment)
|||   weight:     offset 8,  size 8, align 8  (double, -1.0..1.0)
|||   confidence: offset 16, size 8, align 8  (double, 0.0..1.0)
|||   Total: 24 bytes, alignment 8
public export
relationshipLayout : StructLayout
relationshipLayout = MkStructLayout "CRelationship"
  [ MkField "rel_type"   0  4 4
  , MkField "_pad0"      4  4 4
  , MkField "weight"     8  8 8
  , MkField "confidence" 16 8 8
  ]
  24 8

||| CPathNode layout:
|||   entity_type: offset 0, size 4, align 4  (uint32_t, 0=claim, 1=evidence)
|||   order:       offset 4, size 4, align 4  (uint32_t)
|||   Total: 8 bytes, alignment 4
public export
pathNodeLayout : StructLayout
pathNodeLayout = MkStructLayout "CPathNode"
  [ MkField "entity_type" 0 4 4
  , MkField "order"       4 4 4
  ]
  8 4

--------------------------------------------------------------------------------
-- Field Lookup
--------------------------------------------------------------------------------

||| Look up a field by name in a layout
public export
lookupField : String -> StructLayout -> Maybe Field
lookupField name layout =
  find (\f => f.name == name) layout.fields

||| Get field offset by name
public export
fieldOffsetOf : String -> StructLayout -> Maybe Nat
fieldOffsetOf name layout = map offset (lookupField name layout)

||| Get field size by name
public export
fieldSizeOf : String -> StructLayout -> Maybe Nat
fieldSizeOf name layout = map size (lookupField name layout)

--------------------------------------------------------------------------------
-- Size Constants (cross-referenced with Zig comptime assertions)
--------------------------------------------------------------------------------

||| Expected sizes — MUST match Zig @sizeOf comptime checks in main.zig
public export
promptScoresSizeBytes : Nat
promptScoresSizeBytes = 24

public export
claimSizeBytes : Nat
claimSizeBytes = 40

public export
relationshipSizeBytes : Nat
relationshipSizeBytes = 24

public export
pathNodeSizeBytes : Nat
pathNodeSizeBytes = 8

||| Runtime bounds check for all layouts.
||| Call from a test harness to verify at runtime.
||| (Compile-time size verification is in Zig's comptime blocks.)
export
verifyBounds : List (String, Bool)
verifyBounds =
  [ ("CPromptScores", allFieldsInBounds promptScoresLayout)
  , ("CClaim", allFieldsInBounds claimLayout)
  , ("CRelationship", allFieldsInBounds relationshipLayout)
  , ("CPathNode", allFieldsInBounds pathNodeLayout)
  ]
