# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Lithoglyph.NERExtractorTest do
  use ExUnit.Case, async: true

  alias EvidenceGraph.Lithoglyph.NERExtractor

  describe "extract/1" do
    test "returns empty list for nil" do
      assert NERExtractor.extract(nil) == []
    end

    test "returns empty list for empty string" do
      assert NERExtractor.extract("") == []
    end

    test "extracts capitalised multi-word sequences" do
      content = "The report by Jeffrey Epstein was filed in New York."
      entities = NERExtractor.extract(content)

      assert "Jeffrey Epstein" in entities
      assert "New York" in entities
    end

    test "extracts titled names" do
      content = "Dr. Jane Smith and Prof. Alan Turing discussed the results."
      entities = NERExtractor.extract(content)

      assert Enum.any?(entities, &String.contains?(&1, "Jane Smith"))
      assert Enum.any?(entities, &String.contains?(&1, "Alan Turing"))
    end

    test "extracts organisation names with suffixes" do
      content = "Documents from HSBC Holdings plc showed transfers to Global Fund Ltd."
      entities = NERExtractor.extract(content)

      assert Enum.any?(entities, &String.contains?(&1, "HSBC"))
      assert Enum.any?(entities, &String.contains?(&1, "Global Fund"))
    end

    test "filters out stopwords" do
      content = "The Evidence from the Investigation was clear."
      entities = NERExtractor.extract(content)

      refute "The Evidence" in entities
      refute "Evidence" in entities
      refute "Investigation" in entities
    end

    test "deduplicates entity names" do
      content = "Jeffrey Epstein met with Jeffrey Epstein's lawyer."
      entities = NERExtractor.extract(content)

      epstein_count =
        Enum.count(entities, &(&1 == "Jeffrey Epstein"))

      assert epstein_count <= 1
    end

    test "handles complex investigative journalism content" do
      content = """
      Court documents filed in the Southern District of New York reveal that
      Ghislaine Maxwell facilitated meetings between Jeffrey Epstein and
      Prince Andrew at Buckingham Palace. Deutsche Bank processed multiple
      wire transfers totalling $4.6 million. The Federal Bureau of Investigation
      obtained flight logs from Palm Beach International Airport showing
      frequent travel to Little Saint James.
      """

      entities = NERExtractor.extract(content)

      assert Enum.any?(entities, &String.contains?(&1, "Ghislaine Maxwell"))
      assert Enum.any?(entities, &String.contains?(&1, "Jeffrey Epstein"))
      assert Enum.any?(entities, &String.contains?(&1, "Prince Andrew"))
      assert Enum.any?(entities, &String.contains?(&1, "Deutsche Bank"))
    end

    test "rejects very short names" do
      content = "A B met C D at the conference."
      entities = NERExtractor.extract(content)

      refute Enum.any?(entities, &(String.length(&1) < 2))
    end
  end

  describe "extract_from_evidence/1" do
    test "extracts from metadata.content_text" do
      evidence = %{
        title: "Epstein Flight Logs",
        metadata: %{
          content_text: "Jeffrey Epstein flew to Palm Beach on his private jet."
        }
      }

      entities = NERExtractor.extract_from_evidence(evidence)

      assert Enum.any?(entities, &String.contains?(&1, "Jeffrey Epstein"))
      assert Enum.any?(entities, &String.contains?(&1, "Palm Beach"))
    end

    test "includes title in extraction" do
      evidence = %{
        title: "HSBC Holdings Investigation Report",
        metadata: %{content_text: "The bank was fined for compliance failures."}
      }

      entities = NERExtractor.extract_from_evidence(evidence)

      assert Enum.any?(entities, &String.contains?(&1, "HSBC Holdings"))
    end

    test "handles string keys in metadata" do
      evidence = %{
        "title" => "Maxwell Documents",
        "metadata" => %{"content_text" => "Ghislaine Maxwell attended the event."}
      }

      entities = NERExtractor.extract_from_evidence(evidence)

      assert Enum.any?(entities, &String.contains?(&1, "Ghislaine Maxwell"))
    end

    test "handles missing content gracefully" do
      evidence = %{title: "Empty", metadata: %{}}
      entities = NERExtractor.extract_from_evidence(evidence)

      assert is_list(entities)
    end
  end
end
