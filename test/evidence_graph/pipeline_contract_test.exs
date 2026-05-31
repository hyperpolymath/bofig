# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Cross-repo static contract validation for the Docudactyl -> Lithoglyph -> Bofig
# pipeline. Reads actual source files from the filesystem and verifies that field
# names, entity types, and evidence types are consistent across all three repos.
#
# This test does NOT require running services -- it parses source files with regex.
#
# Run with:
#   mix test test/evidence_graph/pipeline_contract_test.exs

defmodule EvidenceGraph.PipelineContractTest do
  use ExUnit.Case, async: true
  @moduletag :external_repo_contract

  @moduledoc """
  Static contract validation for the Docudactyl -> Lithoglyph -> Bofig pipeline.

  The pipeline flow is:
    1. Docudactyl (Zig FFI) extracts documents and outputs JSON with promptScores
    2. Lithoglyph accepts via REST/GraphQL/gRPC with PromptScoresInput / PromptScores
    3. Bofig imports via EvidenceGraph.Lithoglyph.Importer reading both formats

  This test reads the actual source files and asserts field-level consistency.
  """

  # ---------------------------------------------------------------------------
  # Source file paths (relative to a workspace containing the pipeline repos)
  # ---------------------------------------------------------------------------

  @bofig_root Path.expand("../..", __DIR__)

  @repos_root System.get_env("PIPELINE_REPOS_ROOT") ||
                System.get_env("REPOS_DIR") ||
                Path.expand("..", @bofig_root)

  @docudactyl_lith_adapter Path.join(
                             @repos_root,
                             "docudactyl/ffi/zig/src/lith_adapter.zig"
                           )

  @lithoglyph_openapi Path.join(
                        @repos_root,
                        "nextgen-databases/lithoglyph/api/spec/openapi.yaml"
                      )

  @lithoglyph_graphql Path.join(
                        @repos_root,
                        "nextgen-databases/lithoglyph/api/graphql/bofig_ingest.graphql"
                      )

  @lithoglyph_proto Path.join(
                      @repos_root,
                      "nextgen-databases/lithoglyph/api/proto/bofig_ingest.proto"
                    )

  @bofig_importer Path.join(@bofig_root, "lib/evidence_graph/lithoglyph/importer.ex")

  # ---------------------------------------------------------------------------
  # Canonical contract definitions
  # ---------------------------------------------------------------------------

  # The 6 PROMPT score dimensions, in canonical order.
  @prompt_score_fields MapSet.new([
                         "provenance",
                         "replicability",
                         "objective",
                         "methodology",
                         "publication",
                         "transparency"
                       ])

  # The 6 entity types supported across the pipeline.
  @entity_types MapSet.new([
                  "person",
                  "organization",
                  "location",
                  "account",
                  "vessel",
                  "aircraft"
                ])

  # The 16 evidence types (15 named + "other").
  @evidence_types MapSet.new([
                    "court_filing",
                    "deposition",
                    "testimony",
                    "flight_log",
                    "financial_record",
                    "communication",
                    "photograph",
                    "video",
                    "official_statistics",
                    "news_report",
                    "document",
                    "dataset",
                    "interview",
                    "affidavit",
                    "subpoena",
                    "other"
                  ])

  # =========================================================================
  # Helper: file reading with descriptive error
  # =========================================================================

  defp read_source!(path) do
    case File.read(path) do
      {:ok, content} ->
        content

      {:error, reason} ->
        flunk(
          "Cannot read source file #{path}: #{inspect(reason)}. " <>
            "Ensure all three repos (docudactyl, lithoglyph, bofig) are " <>
            "present under #{@repos_root}, or set PIPELINE_REPOS_ROOT."
        )
    end
  end

  # =========================================================================
  # 1. PROMPT Score Field Consistency
  # =========================================================================

  describe "PROMPT score fields" do
    test "Docudactyl lith_adapter.zig outputs all 6 promptScores fields" do
      source = read_source!(@docudactyl_lith_adapter)

      # The Zig code writes JSON keys like: "provenance":{d}
      # inside the "promptScores":{...} block.
      # Extract field names from the PromptScores struct definition.
      struct_fields =
        Regex.scan(~r/^\s*\.(\w+):\s*u8,/m, source)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      # Also verify the JSON output writes "promptScores" as the wrapper key.
      assert source =~ ~s("promptScores":{),
             "Docudactyl must output nested promptScores JSON object"

      # Verify each PROMPT dimension appears in the struct.
      missing = MapSet.difference(@prompt_score_fields, struct_fields)

      assert MapSet.size(missing) == 0,
             "Docudactyl PromptScores struct is missing fields: #{inspect(MapSet.to_list(missing))}"

      extra = MapSet.difference(struct_fields, @prompt_score_fields)

      assert MapSet.size(extra) == 0,
             "Docudactyl PromptScores struct has unexpected fields: #{inspect(MapSet.to_list(extra))}"
    end

    test "Lithoglyph OpenAPI PromptScoresInput has all 6 fields" do
      source = read_source!(@lithoglyph_openapi)

      # Extract properties under PromptScoresInput.
      # The YAML structure is:
      #   PromptScoresInput:
      #     ...
      #     properties:
      #       provenance:
      #       replicability:
      #       ...
      openapi_fields = extract_openapi_prompt_fields(source)

      missing = MapSet.difference(@prompt_score_fields, openapi_fields)

      assert MapSet.size(missing) == 0,
             "Lithoglyph OpenAPI PromptScoresInput is missing fields: #{inspect(MapSet.to_list(missing))}"

      extra = MapSet.difference(openapi_fields, @prompt_score_fields)

      assert MapSet.size(extra) == 0,
             "Lithoglyph OpenAPI PromptScoresInput has unexpected fields: #{inspect(MapSet.to_list(extra))}"
    end

    test "Lithoglyph GraphQL PromptScoresInput has all 6 fields" do
      source = read_source!(@lithoglyph_graphql)

      # Extract fields from:
      #   input PromptScoresInput {
      #     provenance: Int!
      #     ...
      #   }
      graphql_fields = extract_graphql_prompt_fields(source)

      missing = MapSet.difference(@prompt_score_fields, graphql_fields)

      assert MapSet.size(missing) == 0,
             "Lithoglyph GraphQL PromptScoresInput is missing fields: #{inspect(MapSet.to_list(missing))}"

      extra = MapSet.difference(graphql_fields, @prompt_score_fields)

      assert MapSet.size(extra) == 0,
             "Lithoglyph GraphQL PromptScoresInput has unexpected fields: #{inspect(MapSet.to_list(extra))}"
    end

    test "Lithoglyph gRPC PromptScores message has all 6 fields" do
      source = read_source!(@lithoglyph_proto)

      # Extract fields from:
      #   message PromptScores {
      #     int32 provenance = 1;
      #     ...
      #   }
      proto_fields = extract_proto_prompt_fields(source)

      missing = MapSet.difference(@prompt_score_fields, proto_fields)

      assert MapSet.size(missing) == 0,
             "Lithoglyph gRPC PromptScores is missing fields: #{inspect(MapSet.to_list(missing))}"

      extra = MapSet.difference(proto_fields, @prompt_score_fields)

      assert MapSet.size(extra) == 0,
             "Lithoglyph gRPC PromptScores has unexpected fields: #{inspect(MapSet.to_list(extra))}"
    end

    test "Bofig Importer extract_prompt_scores reads all 6 fields from nested format" do
      source = read_source!(@bofig_importer)

      # The importer reads scores["provenance"], scores["replicability"], etc.
      nested_fields =
        Regex.scan(~r/scores\["(\w+)"\]/, source)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      missing = MapSet.difference(@prompt_score_fields, nested_fields)

      assert MapSet.size(missing) == 0,
             "Bofig Importer is missing nested promptScores reads for: #{inspect(MapSet.to_list(missing))}"
    end

    test "Bofig Importer extract_prompt_scores reads all 6 fields from flat format" do
      source = read_source!(@bofig_importer)

      # The importer also reads record["prompt_provenance"], record["prompt_replicability"], etc.
      flat_fields =
        Regex.scan(~r/record\["prompt_(\w+)"\]/, source)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      missing = MapSet.difference(@prompt_score_fields, flat_fields)

      assert MapSet.size(missing) == 0,
             "Bofig Importer is missing flat prompt_* reads for: #{inspect(MapSet.to_list(missing))}"
    end

    test "all three repos agree on the exact same PROMPT field set" do
      docudactyl_source = read_source!(@docudactyl_lith_adapter)
      openapi_source = read_source!(@lithoglyph_openapi)
      importer_source = read_source!(@bofig_importer)

      docudactyl_fields =
        Regex.scan(~r/^\s*\.(\w+):\s*u8,/m, docudactyl_source)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      openapi_fields = extract_openapi_prompt_fields(openapi_source)

      bofig_nested_fields =
        Regex.scan(~r/scores\["(\w+)"\]/, importer_source)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      assert docudactyl_fields == openapi_fields,
             "Docudactyl and Lithoglyph OpenAPI PROMPT fields differ.\n" <>
               "  Docudactyl: #{inspect(MapSet.to_list(docudactyl_fields))}\n" <>
               "  Lithoglyph: #{inspect(MapSet.to_list(openapi_fields))}"

      assert openapi_fields == bofig_nested_fields,
             "Lithoglyph OpenAPI and Bofig Importer PROMPT fields differ.\n" <>
               "  Lithoglyph: #{inspect(MapSet.to_list(openapi_fields))}\n" <>
               "  Bofig:      #{inspect(MapSet.to_list(bofig_nested_fields))}"
    end
  end

  # =========================================================================
  # 2. Entity Type Consistency
  # =========================================================================

  describe "entity types" do
    test "Lithoglyph OpenAPI IngestEntityInput entityType enum has all 6 types" do
      source = read_source!(@lithoglyph_openapi)

      # Extract from: enum: [person, organization, location, account, vessel, aircraft]
      # under IngestEntityInput > properties > entityType
      entity_enum =
        Regex.scan(~r/enum:\s*\[([^\]]+)\]/, source)
        |> Enum.flat_map(fn [_, values] ->
          String.split(values, ~r/,\s*/)
          |> Enum.map(&String.trim/1)
        end)
        |> MapSet.new()

      # Check that our canonical entity types are all present in at least one enum
      missing = MapSet.difference(@entity_types, entity_enum)

      assert MapSet.size(missing) == 0,
             "Lithoglyph OpenAPI is missing entity types: #{inspect(MapSet.to_list(missing))}"
    end

    test "Lithoglyph GraphQL EntityTypeEnum has all 6 types" do
      source = read_source!(@lithoglyph_graphql)

      # Extract values from:
      #   enum EntityTypeEnum {
      #     PERSON
      #     ORGANIZATION
      #     ...
      #   }
      graphql_entity_types = extract_graphql_enum(source, "EntityTypeEnum")

      # GraphQL uses UPPER_CASE; normalise to lowercase for comparison
      normalised =
        graphql_entity_types
        |> Enum.map(&String.downcase/1)
        |> MapSet.new()

      missing = MapSet.difference(@entity_types, normalised)

      assert MapSet.size(missing) == 0,
             "Lithoglyph GraphQL EntityTypeEnum is missing: #{inspect(MapSet.to_list(missing))}"
    end

    test "Lithoglyph gRPC EntityType enum has all 6 types" do
      source = read_source!(@lithoglyph_proto)

      # Extract from:
      #   enum EntityType {
      #     ENTITY_TYPE_UNSPECIFIED = 0;
      #     ENTITY_TYPE_PERSON = 1;
      #     ...
      #   }
      proto_entity_types = extract_proto_enum(source, "EntityType")

      # Proto uses ENTITY_TYPE_PERSON format; strip prefix and lowercase
      normalised =
        proto_entity_types
        |> Enum.reject(&(&1 == "UNSPECIFIED"))
        |> Enum.map(&String.downcase/1)
        |> MapSet.new()

      missing = MapSet.difference(@entity_types, normalised)

      assert MapSet.size(missing) == 0,
             "Lithoglyph gRPC EntityType is missing: #{inspect(MapSet.to_list(missing))}"
    end
  end

  # =========================================================================
  # 3. Evidence Type Consistency
  # =========================================================================

  describe "evidence types" do
    test "Docudactyl detectEvidenceType covers all evidence types it can produce" do
      source = read_source!(@docudactyl_lith_adapter)

      # Extract all string literals returned by detectEvidenceType.
      # Pattern: return "evidence_type_name";
      docudactyl_evidence_types =
        Regex.scan(~r/return\s+"(\w+)";/, source)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      # Docudactyl doesn't produce ALL 16 types (only what MIME detection can
      # distinguish), but every type it produces must be in the canonical set.
      extra = MapSet.difference(docudactyl_evidence_types, @evidence_types)

      assert MapSet.size(extra) == 0,
             "Docudactyl produces evidence types not in the canonical set: #{inspect(MapSet.to_list(extra))}"

      # Verify it produces a reasonable number of distinct types (at least 5).
      assert MapSet.size(docudactyl_evidence_types) >= 5,
             "Docudactyl only produces #{MapSet.size(docudactyl_evidence_types)} evidence types -- " <>
               "expected at least 5 from MIME detection"
    end

    test "Lithoglyph OpenAPI EvidenceType enum has all 16 types" do
      source = read_source!(@lithoglyph_openapi)

      # Find the evidenceType enum (under IngestEvidenceRequest or standalone).
      # Pattern: enum: [court_filing, deposition, ...]
      # We need the one with evidence-specific values.
      all_enums =
        Regex.scan(~r/enum:\s*\[([^\]]+)\]/, source)
        |> Enum.flat_map(fn [_, values] ->
          String.split(values, ~r/,\s*/)
          |> Enum.map(&String.trim/1)
        end)
        |> MapSet.new()

      missing = MapSet.difference(@evidence_types, all_enums)

      assert MapSet.size(missing) == 0,
             "Lithoglyph OpenAPI is missing evidence types: #{inspect(MapSet.to_list(missing))}"
    end

    test "Lithoglyph GraphQL EvidenceType enum has all 16 types" do
      source = read_source!(@lithoglyph_graphql)

      graphql_evidence_types = extract_graphql_enum(source, "EvidenceType")

      normalised =
        graphql_evidence_types
        |> Enum.map(&String.downcase/1)
        |> MapSet.new()

      missing = MapSet.difference(@evidence_types, normalised)

      assert MapSet.size(missing) == 0,
             "Lithoglyph GraphQL EvidenceType is missing: #{inspect(MapSet.to_list(missing))}"
    end

    test "Lithoglyph gRPC EvidenceType enum has all 16 types" do
      source = read_source!(@lithoglyph_proto)

      proto_evidence_types = extract_proto_enum(source, "EvidenceType")

      normalised =
        proto_evidence_types
        |> Enum.reject(&(&1 == "UNSPECIFIED"))
        |> Enum.map(&String.downcase/1)
        |> MapSet.new()

      missing = MapSet.difference(@evidence_types, normalised)

      assert MapSet.size(missing) == 0,
             "Lithoglyph gRPC EvidenceType is missing: #{inspect(MapSet.to_list(missing))}"
    end

    test "Bofig Importer map_evidence_type handles all Docudactyl output types" do
      docudactyl_source = read_source!(@docudactyl_lith_adapter)
      bofig_source = read_source!(@bofig_importer)

      # Types that Docudactyl can produce via detectEvidenceType.
      docudactyl_types =
        Regex.scan(~r/return\s+"(\w+)";/, docudactyl_source)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      # Types that Bofig map_evidence_type has explicit clauses for.
      # Pattern: defp map_evidence_type("court_filing"), do: :document
      bofig_mapped_types =
        Regex.scan(~r/defp\s+map_evidence_type\("(\w+)"\)/, bofig_source)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      # Every type Docudactyl produces must have an explicit mapping in Bofig.
      missing = MapSet.difference(docudactyl_types, bofig_mapped_types)

      assert MapSet.size(missing) == 0,
             "Bofig Importer is missing map_evidence_type clauses for types Docudactyl produces: " <>
               "#{inspect(MapSet.to_list(missing))}"
    end

    test "Bofig Importer map_evidence_type covers all Lithoglyph evidence types" do
      bofig_source = read_source!(@bofig_importer)

      bofig_mapped_types =
        Regex.scan(~r/defp\s+map_evidence_type\("(\w+)"\)/, bofig_source)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      # The catch-all clause handles "other" and any unmapped type, so we only
      # check the 15 named types (excluding "other").
      named_types = MapSet.delete(@evidence_types, "other")
      missing = MapSet.difference(named_types, bofig_mapped_types)

      assert MapSet.size(missing) == 0,
             "Bofig Importer is missing map_evidence_type clauses for Lithoglyph types: " <>
               "#{inspect(MapSet.to_list(missing))}"
    end
  end

  # =========================================================================
  # 4. Structural Contract: Docudactyl JSON wrapper key
  # =========================================================================

  describe "JSON structure contract" do
    test "Docudactyl outputs promptScores as a nested JSON object (camelCase)" do
      source = read_source!(@docudactyl_lith_adapter)

      # The Zig code must write "promptScores":{ to produce the nested object.
      assert source =~ ~s("promptScores":{),
             "Docudactyl must use camelCase 'promptScores' as the nested JSON key"
    end

    test "Bofig Importer reads the camelCase promptScores key" do
      source = read_source!(@bofig_importer)

      assert source =~ ~s(record["promptScores"]),
             "Bofig Importer must read the camelCase 'promptScores' key from Lithoglyph records"
    end

    test "Docudactyl outputs evidence_type as a JSON field" do
      source = read_source!(@docudactyl_lith_adapter)

      assert source =~ ~s("evidence_type"),
             "Docudactyl must output 'evidence_type' as a JSON field"
    end

    test "Bofig Importer reads evidence_type field" do
      source = read_source!(@bofig_importer)

      assert source =~ ~s(record["evidence_type"]),
             "Bofig Importer must read 'evidence_type' from Lithoglyph records"
    end
  end

  # =========================================================================
  # 5. Source File Existence (precondition check)
  # =========================================================================

  describe "source file existence" do
    test "all pipeline source files exist" do
      for {label, path} <- [
            {"Docudactyl lith_adapter.zig", @docudactyl_lith_adapter},
            {"Lithoglyph OpenAPI spec", @lithoglyph_openapi},
            {"Lithoglyph GraphQL schema", @lithoglyph_graphql},
            {"Lithoglyph gRPC proto", @lithoglyph_proto},
            {"Bofig Importer", @bofig_importer}
          ] do
        assert File.exists?(path),
               "#{label} not found at #{path}. " <>
                 "Cross-repo contract tests require all three repos to be present."
      end
    end
  end

  # =========================================================================
  # Private Helpers: Field Extraction
  # =========================================================================

  # Extract field names from the OpenAPI PromptScoresInput schema section.
  # Parses the YAML block between "PromptScoresInput:" and the next schema.
  defp extract_openapi_prompt_fields(source) do
    # Find the PromptScoresInput block and extract property names.
    case Regex.run(~r/PromptScoresInput:\s*\n(.*?)(?=\n\s{4}\w+:|\z)/s, source) do
      [_, block] ->
        # Properties are indented lines like "        provenance:" (8 spaces, no value)
        Regex.scan(~r/^\s{8}(\w+):\s*$/m, block)
        |> Enum.map(fn [_, name] -> name end)
        |> Enum.reject(&(&1 in ["type", "required", "properties", "minimum", "maximum"]))
        |> MapSet.new()

      nil ->
        flunk("Could not find PromptScoresInput in Lithoglyph OpenAPI spec")
    end
  end

  # Extract field names from GraphQL PromptScoresInput definition.
  defp extract_graphql_prompt_fields(source) do
    case Regex.run(~r/input\s+PromptScoresInput\s*\{([^}]+)\}/s, source) do
      [_, body] ->
        Regex.scan(~r/^\s*(\w+)\s*:/m, body)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      nil ->
        flunk("Could not find PromptScoresInput in Lithoglyph GraphQL schema")
    end
  end

  # Extract field names from protobuf PromptScores message definition.
  defp extract_proto_prompt_fields(source) do
    case Regex.run(~r/message\s+PromptScores\s*\{([^}]+)\}/s, source) do
      [_, body] ->
        Regex.scan(~r/\w+\s+(\w+)\s*=\s*\d+;/, body)
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      nil ->
        flunk("Could not find PromptScores message in Lithoglyph proto file")
    end
  end

  # Extract enum values from a GraphQL enum definition.
  # Returns a list of value strings (in original case, e.g., "PERSON").
  defp extract_graphql_enum(source, enum_name) do
    case Regex.run(~r/enum\s+#{Regex.escape(enum_name)}\s*\{([^}]+)\}/s, source) do
      [_, body] ->
        String.split(body, "\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(
          &(&1 == "" or String.starts_with?(&1, "#") or String.starts_with?(&1, "\""))
        )
        |> MapSet.new()

      nil ->
        flunk("Could not find enum #{enum_name} in GraphQL schema")
    end
  end

  # Extract enum values from a protobuf enum definition, stripping the prefix.
  # E.g., "ENTITY_TYPE_PERSON" -> "PERSON", "ENTITY_TYPE_UNSPECIFIED" -> "UNSPECIFIED".
  defp extract_proto_enum(source, enum_name) do
    case Regex.run(~r/enum\s+#{Regex.escape(enum_name)}\s*\{([^}]+)\}/s, source) do
      [_, body] ->
        # Extract lines like: ENTITY_TYPE_PERSON = 1;
        Regex.scan(~r/^\s*(\w+)\s*=\s*\d+;/m, body)
        |> Enum.map(fn [_, full_name] ->
          # Strip the common prefix (e.g., ENTITY_TYPE_ or EVIDENCE_TYPE_).
          # Convert CamelCase enum_name to UPPER_SNAKE prefix:
          # "EntityType" -> "ENTITY_TYPE", "EvidenceType" -> "EVIDENCE_TYPE"
          prefix = camel_to_upper_snake(enum_name)
          String.replace_prefix(full_name, prefix <> "_", "")
        end)
        |> MapSet.new()

      nil ->
        flunk("Could not find enum #{enum_name} in proto file")
    end
  end

  # Convert CamelCase to UPPER_SNAKE_CASE.
  # E.g., "EntityType" -> "ENTITY_TYPE", "EvidenceType" -> "EVIDENCE_TYPE"
  defp camel_to_upper_snake(name) do
    name
    |> String.graphemes()
    |> Enum.reduce("", fn char, acc ->
      if acc != "" and char == String.upcase(char) and char != "_" and
           char >= "A" and char <= "Z" do
        acc <> "_" <> char
      else
        acc <> String.upcase(char)
      end
    end)
  end
end
