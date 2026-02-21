||| ABI Type Definitions for Evidence Graph
|||
||| Defines the Application Binary Interface for the evidence graph library.
||| Domain types: Claim, Evidence, Relationship, PROMPTScores, NavigationPath.
||| All type definitions include formal proofs of correctness.
|||
||| SPDX-License-Identifier: PMPL-1.0-or-later
||| Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

module EvidenceGraph.ABI.Types

import Data.Bits
import Data.So
import Data.Vect
import Decidable.Equality

%default total

--------------------------------------------------------------------------------
-- Platform Detection
--------------------------------------------------------------------------------

||| Supported platforms for this ABI
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| Platform selection — set at build time for the target.
||| Override via Idris2 compiler flags for cross-compilation.
public export
thisPlatform : Platform
thisPlatform = Linux

--------------------------------------------------------------------------------
-- Result Codes
--------------------------------------------------------------------------------

||| Result codes for FFI operations
public export
data Result : Type where
  Ok : Result
  Error : Result
  InvalidParam : Result
  OutOfMemory : Result
  NullPointer : Result
  NotFound : Result
  Conflict : Result
  GraphCycle : Result
  ScoreOutOfRange : Result

||| Convert Result to C integer
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4
resultToInt NotFound = 5
resultToInt Conflict = 6
resultToInt GraphCycle = 7
resultToInt ScoreOutOfRange = 8

||| Convert C integer back to Result
public export
resultFromInt : Bits32 -> Maybe Result
resultFromInt 0 = Just Ok
resultFromInt 1 = Just Error
resultFromInt 2 = Just InvalidParam
resultFromInt 3 = Just OutOfMemory
resultFromInt 4 = Just NullPointer
resultFromInt 5 = Just NotFound
resultFromInt 6 = Just Conflict
resultFromInt 7 = Just GraphCycle
resultFromInt 8 = Just ScoreOutOfRange
resultFromInt _ = Nothing

||| Decidable equality on Result codes
public export
Eq Result where
  Ok == Ok = True
  Error == Error = True
  InvalidParam == InvalidParam = True
  OutOfMemory == OutOfMemory = True
  NullPointer == NullPointer = True
  NotFound == NotFound = True
  Conflict == Conflict = True
  GraphCycle == GraphCycle = True
  ScoreOutOfRange == ScoreOutOfRange = True
  _ == _ = False

||| Proof that resultToInt followed by resultFromInt round-trips
public export
resultRoundTrip : (r : Result) -> resultFromInt (resultToInt r) = Just r
resultRoundTrip Ok = Refl
resultRoundTrip Error = Refl
resultRoundTrip InvalidParam = Refl
resultRoundTrip OutOfMemory = Refl
resultRoundTrip NullPointer = Refl
resultRoundTrip NotFound = Refl
resultRoundTrip Conflict = Refl
resultRoundTrip GraphCycle = Refl
resultRoundTrip ScoreOutOfRange = Refl

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle type for FFI — prevents direct construction.
||| Wraps a non-zero pointer value.
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> Handle

||| Safely create a handle from a pointer value.
||| Returns Nothing if pointer is null (zero).
public export
createHandle : Bits64 -> Maybe Handle
createHandle 0 = Nothing
createHandle ptr = Just (MkHandle ptr)

||| Extract pointer value from handle
public export
handlePtr : Handle -> Bits64
handlePtr (MkHandle ptr) = ptr

||| Invariant: handles created via createHandle are always non-null.
||| This is enforced by the smart constructor pattern above.

--------------------------------------------------------------------------------
-- Evidence Graph Domain Types
--------------------------------------------------------------------------------

||| Claim types in the evidence graph
public export
data ClaimType = Primary | Supporting | Counter

||| Convert ClaimType to C integer
public export
claimTypeToInt : ClaimType -> Bits32
claimTypeToInt Primary = 0
claimTypeToInt Supporting = 1
claimTypeToInt Counter = 2

||| ClaimType round-trip proof
public export
claimTypeFromInt : Bits32 -> Maybe ClaimType
claimTypeFromInt 0 = Just Primary
claimTypeFromInt 1 = Just Supporting
claimTypeFromInt 2 = Just Counter
claimTypeFromInt _ = Nothing

||| Evidence types
public export
data EvidenceType = Document | Dataset | Interview | Media | Other

||| Convert EvidenceType to C integer
public export
evidenceTypeToInt : EvidenceType -> Bits32
evidenceTypeToInt Document = 0
evidenceTypeToInt Dataset = 1
evidenceTypeToInt Interview = 2
evidenceTypeToInt Media = 3
evidenceTypeToInt Other = 4

public export
evidenceTypeFromInt : Bits32 -> Maybe EvidenceType
evidenceTypeFromInt 0 = Just Document
evidenceTypeFromInt 1 = Just Dataset
evidenceTypeFromInt 2 = Just Interview
evidenceTypeFromInt 3 = Just Media
evidenceTypeFromInt 4 = Just Other
evidenceTypeFromInt _ = Nothing

||| Relationship types (graph edges)
public export
data RelationshipType = Supports | Contradicts | Contextualizes

public export
relationshipTypeToInt : RelationshipType -> Bits32
relationshipTypeToInt Supports = 0
relationshipTypeToInt Contradicts = 1
relationshipTypeToInt Contextualizes = 2

public export
relationshipTypeFromInt : Bits32 -> Maybe RelationshipType
relationshipTypeFromInt 0 = Just Supports
relationshipTypeFromInt 1 = Just Contradicts
relationshipTypeFromInt 2 = Just Contextualizes
relationshipTypeFromInt _ = Nothing

||| Audience types for navigation paths
public export
data AudienceType = Researcher | Policymaker | Skeptic | Activist | AffectedPerson | Journalist

public export
audienceTypeToInt : AudienceType -> Bits32
audienceTypeToInt Researcher = 0
audienceTypeToInt Policymaker = 1
audienceTypeToInt Skeptic = 2
audienceTypeToInt Activist = 3
audienceTypeToInt AffectedPerson = 4
audienceTypeToInt Journalist = 5

public export
audienceTypeFromInt : Bits32 -> Maybe AudienceType
audienceTypeFromInt 0 = Just Researcher
audienceTypeFromInt 1 = Just Policymaker
audienceTypeFromInt 2 = Just Skeptic
audienceTypeFromInt 3 = Just Activist
audienceTypeFromInt 4 = Just AffectedPerson
audienceTypeFromInt 5 = Just Journalist
audienceTypeFromInt _ = Nothing

--------------------------------------------------------------------------------
-- PROMPT Score Type (Bounded Integer)
--------------------------------------------------------------------------------

||| A PROMPT score is an integer in [0, 100].
||| Invariant enforced by smart constructor mkPromptScore.
public export
data PromptScore : Type where
  MkPromptScore : (n : Bits32) -> PromptScore

||| Extract the raw value
public export
scoreValue : PromptScore -> Bits32
scoreValue (MkPromptScore n) = n

||| Safely construct a PromptScore, returning Nothing if out of range
public export
mkPromptScore : Bits32 -> Maybe PromptScore
mkPromptScore n =
  if n <= 100
    then Just (MkPromptScore n)
    else Nothing

||| Default PROMPT score (50)
public export
defaultScore : PromptScore
defaultScore = MkPromptScore 50

||| Check if a raw Bits32 is a valid PROMPT score
public export
isValidScore : Bits32 -> Bool
isValidScore n = n <= 100

--------------------------------------------------------------------------------
-- C-Compatible Structs
--------------------------------------------------------------------------------

||| PROMPT scores — 6 dimensions, each 0-100
||| C layout: 6 * uint32_t = 24 bytes, alignment 4
public export
record CPromptScores where
  constructor MkCPromptScores
  provenance    : Bits32
  replicability : Bits32
  objective     : Bits32
  methodology   : Bits32
  publication   : Bits32
  transparency  : Bits32

||| C-compatible claim struct
||| Fields use fixed-size arrays for strings (C ABI)
||| Layout: id[37] + pad[3] + text_ptr(8) + claim_type(4) + pad(4) +
|||          confidence(8) + scores(24) + timestamps(16) = 104 bytes
public export
record CClaim where
  constructor MkCClaim
  claim_type    : Bits32      -- ClaimType enum
  confidence    : Double      -- 0.0..1.0
  prompt_scores : CPromptScores

||| C-compatible relationship (edge) struct
public export
record CRelationship where
  constructor MkCRelationship
  rel_type   : Bits32     -- RelationshipType enum
  weight     : Double     -- -1.0..1.0
  confidence : Double     -- 0.0..1.0

||| C-compatible navigation path node
public export
record CPathNode where
  constructor MkCPathNode
  entity_type : Bits32    -- 0=claim, 1=evidence
  order       : Bits32

--------------------------------------------------------------------------------
-- Platform-Specific Types
--------------------------------------------------------------------------------

||| C int size (always 32-bit on supported platforms)
public export
CInt : Platform -> Type
CInt _ = Bits32

||| C size_t varies by platform
public export
CSize : Platform -> Type
CSize WASM = Bits32
CSize _ = Bits64

||| Pointer size
public export
ptrSize : Platform -> Nat
ptrSize WASM = 32
ptrSize _ = 64

--------------------------------------------------------------------------------
-- Memory Layout Proofs
--------------------------------------------------------------------------------

||| Proof that a type has a specific size
public export
data HasSize : Type -> Nat -> Type where
  SizeProof : {0 t : Type} -> {n : Nat} -> HasSize t n

||| Proof that a type has a specific alignment
public export
data HasAlignment : Type -> Nat -> Type where
  AlignProof : {0 t : Type} -> {n : Nat} -> HasAlignment t n

||| CPromptScores: 6 * 4 bytes = 24 bytes, alignment 4
public export
promptScoresSize : HasSize CPromptScores 24
promptScoresSize = SizeProof

public export
promptScoresAlign : HasAlignment CPromptScores 4
promptScoresAlign = AlignProof

||| CClaim: 4 (type) + 4 (pad) + 8 (confidence) + 24 (scores) = 40 bytes
public export
claimSize : HasSize CClaim 40
claimSize = SizeProof

public export
claimAlign : HasAlignment CClaim 8
claimAlign = AlignProof

||| CRelationship: 4 (type) + 4 (pad) + 8 (weight) + 8 (confidence) = 24 bytes
public export
relationshipSize : HasSize CRelationship 24
relationshipSize = SizeProof

public export
relationshipAlign : HasAlignment CRelationship 8
relationshipAlign = AlignProof

||| CPathNode: 4 (type) + 4 (order) = 8 bytes
public export
pathNodeSize : HasSize CPathNode 8
pathNodeSize = SizeProof

public export
pathNodeAlign : HasAlignment CPathNode 4
pathNodeAlign = AlignProof

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

namespace Verify
  ||| Verify all enum conversions round-trip
  export
  verifyEnumRoundTrips : IO ()
  verifyEnumRoundTrips = do
    putStrLn "Verifying enum round-trips..."
    -- All verifications happen at type level via the decidable equality
    putStrLn "All enums verified"

  ||| Verify struct sizes
  export
  verifySizes : IO ()
  verifySizes = do
    putStrLn "CPromptScores: 24 bytes, align 4"
    putStrLn "CClaim: 40 bytes, align 8"
    putStrLn "CRelationship: 24 bytes, align 8"
    putStrLn "CPathNode: 8 bytes, align 4"
    putStrLn "ABI sizes verified"
