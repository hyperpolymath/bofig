||| Foreign Function Interface Declarations for Evidence Graph
|||
||| Declares all C-compatible functions implemented in the Zig FFI layer.
||| Operations: PROMPT scoring, relationship management, path finding,
||| claim/evidence lifecycle.
|||
||| SPDX-License-Identifier: PMPL-1.0-or-later
||| Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

module EvidenceGraph.ABI.Foreign

import EvidenceGraph.ABI.Types
import EvidenceGraph.ABI.Layout

%default total

--------------------------------------------------------------------------------
-- Library Lifecycle
--------------------------------------------------------------------------------

||| Initialize the evidence graph library
export
%foreign "C:evidence_graph_init, libevidence_graph"
prim__init : PrimIO Bits64

||| Safe wrapper for library initialization
export
init : IO (Maybe Handle)
init = do
  ptr <- primIO prim__init
  pure (createHandle ptr)

||| Free library resources
export
%foreign "C:evidence_graph_free, libevidence_graph"
prim__free : Bits64 -> PrimIO ()

||| Safe wrapper for cleanup
export
free : Handle -> IO ()
free h = primIO (prim__free (handlePtr h))

--------------------------------------------------------------------------------
-- PROMPT Score Operations
--------------------------------------------------------------------------------

||| Calculate overall PROMPT score (weighted average)
||| Takes 6 dimension scores, returns weighted result * 100 (as integer)
export
%foreign "C:evidence_graph_prompt_overall, libevidence_graph"
prim__promptOverall : Bits64 -> Bits32 -> Bits32 -> Bits32 -> Bits32 -> Bits32 -> Bits32 -> PrimIO Bits32

||| Safe wrapper for overall PROMPT calculation
export
promptOverall : Handle -> CPromptScores -> IO (Either Result Bits32)
promptOverall h scores = do
  result <- primIO (prim__promptOverall
    (handlePtr h)
    scores.provenance
    scores.replicability
    scores.objective
    scores.methodology
    scores.publication
    scores.transparency)
  if result <= 10000  -- valid score range (0-100 * 100)
    then pure (Right result)
    else pure (Left ScoreOutOfRange)

||| Calculate audience-weighted PROMPT score
||| audience_type: 0=researcher, 1=policymaker, ..., 5=journalist
export
%foreign "C:evidence_graph_prompt_audience, libevidence_graph"
prim__promptAudience : Bits64 -> Bits32 -> Bits32 -> Bits32 -> Bits32 -> Bits32 -> Bits32 -> Bits32 -> PrimIO Bits32

||| Safe wrapper for audience-weighted PROMPT calculation
export
promptAudience : Handle -> AudienceType -> CPromptScores -> IO (Either Result Bits32)
promptAudience h audience scores = do
  result <- primIO (prim__promptAudience
    (handlePtr h)
    (audienceTypeToInt audience)
    scores.provenance
    scores.replicability
    scores.objective
    scores.methodology
    scores.publication
    scores.transparency)
  if result <= 10000
    then pure (Right result)
    else pure (Left ScoreOutOfRange)

--------------------------------------------------------------------------------
-- Relationship Operations
--------------------------------------------------------------------------------

||| Calculate propagated weight through an evidence chain
||| Takes array of weights and length, returns combined weight * 1000
export
%foreign "C:evidence_graph_propagated_weight, libevidence_graph"
prim__propagatedWeight : Bits64 -> Bits64 -> Bits32 -> PrimIO Bits32

||| Check if adding an edge would create a cycle in the graph
||| from_id and to_id are string pointers
export
%foreign "C:evidence_graph_check_cycle, libevidence_graph"
prim__checkCycle : Bits64 -> Bits64 -> Bits64 -> PrimIO Bits32

||| Safe cycle check wrapper
export
checkCycle : Handle -> (fromPtr : Bits64) -> (toPtr : Bits64) -> IO (Either Result Bool)
checkCycle h fromPtr toPtr = do
  result <- primIO (prim__checkCycle (handlePtr h) fromPtr toPtr)
  pure $ case resultFromInt result of
    Just Ok => Right False       -- no cycle
    Just GraphCycle => Right True -- would create cycle
    Just err => Left err
    Nothing => Left Error

--------------------------------------------------------------------------------
-- String Operations
--------------------------------------------------------------------------------

||| Convert C string to Idris String
export
%foreign "support:idris2_getString, libidris2_support"
prim__getString : Bits64 -> String

||| Free C string
export
%foreign "C:evidence_graph_free_string, libevidence_graph"
prim__freeString : Bits64 -> PrimIO ()

||| Get string result from library
export
%foreign "C:evidence_graph_get_string, libevidence_graph"
prim__getResult : Bits64 -> PrimIO Bits64

||| Safe string getter
export
getString : Handle -> IO (Maybe String)
getString h = do
  ptr <- primIO (prim__getResult (handlePtr h))
  if ptr == 0
    then pure Nothing
    else do
      let str = prim__getString ptr
      primIO (prim__freeString ptr)
      pure (Just str)

--------------------------------------------------------------------------------
-- Error Handling
--------------------------------------------------------------------------------

||| Get last error message
export
%foreign "C:evidence_graph_last_error, libevidence_graph"
prim__lastError : PrimIO Bits64

||| Retrieve last error as string
export
lastError : IO (Maybe String)
lastError = do
  ptr <- primIO prim__lastError
  if ptr == 0
    then pure Nothing
    else pure (Just (prim__getString ptr))

||| Error description for result codes
export
errorDescription : Result -> String
errorDescription Ok = "Success"
errorDescription Error = "Generic error"
errorDescription InvalidParam = "Invalid parameter"
errorDescription OutOfMemory = "Out of memory"
errorDescription NullPointer = "Null pointer"
errorDescription NotFound = "Entity not found"
errorDescription Conflict = "Version conflict"
errorDescription GraphCycle = "Operation would create a cycle"
errorDescription ScoreOutOfRange = "PROMPT score out of range (0-100)"

--------------------------------------------------------------------------------
-- Version Information
--------------------------------------------------------------------------------

||| Get library version
export
%foreign "C:evidence_graph_version, libevidence_graph"
prim__version : PrimIO Bits64

||| Get version as string
export
version : IO String
version = do
  ptr <- primIO prim__version
  pure (prim__getString ptr)

||| Get library build info
export
%foreign "C:evidence_graph_build_info, libevidence_graph"
prim__buildInfo : PrimIO Bits64

||| Get build information
export
buildInfo : IO String
buildInfo = do
  ptr <- primIO prim__buildInfo
  pure (prim__getString ptr)

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

||| Check if library is initialized
export
%foreign "C:evidence_graph_is_initialized, libevidence_graph"
prim__isInitialized : Bits64 -> PrimIO Bits32

||| Check initialization status
export
isInitialized : Handle -> IO Bool
isInitialized h = do
  result <- primIO (prim__isInitialized (handlePtr h))
  pure (result /= 0)
