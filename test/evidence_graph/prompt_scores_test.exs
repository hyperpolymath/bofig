# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraph.PromptScoresTest do
  use ExUnit.Case, async: true

  alias EvidenceGraph.PromptScores
  import EvidenceGraph.Fixtures

  describe "changeset/2" do
    test "valid scores pass validation" do
      changeset =
        PromptScores.changeset(%PromptScores{}, %{
          provenance: 80,
          replicability: 70,
          objective: 75,
          methodology: 90,
          publication: 85,
          transparency: 60
        })

      assert changeset.valid?
    end

    test "all defaults are 50" do
      scores = %PromptScores{}
      assert scores.provenance == 50
      assert scores.replicability == 50
      assert scores.objective == 50
      assert scores.methodology == 50
      assert scores.publication == 50
      assert scores.transparency == 50
    end

    test "rejects score above 100" do
      changeset = PromptScores.changeset(%PromptScores{}, %{provenance: 101})
      refute changeset.valid?
      assert {"must be less than or equal to %{number}", _} = changeset.errors[:provenance]
    end

    test "rejects negative score" do
      changeset = PromptScores.changeset(%PromptScores{}, %{methodology: -1})
      refute changeset.valid?
      assert {"must be greater than or equal to %{number}", _} = changeset.errors[:methodology]
    end

    test "accepts boundary values 0 and 100" do
      changeset = PromptScores.changeset(%PromptScores{}, %{provenance: 0, methodology: 100})
      assert changeset.valid?
    end
  end

  describe "calculate_overall/1" do
    test "balanced scores at 50 give overall 50.0" do
      result = PromptScores.calculate_overall(balanced_scores())
      assert_in_delta result, 50.0, 0.01
    end

    test "max scores give overall 100.0" do
      result = PromptScores.calculate_overall(max_scores())
      assert_in_delta result, 100.0, 0.01
    end

    test "zero scores give overall 0.0" do
      result = PromptScores.calculate_overall(zero_scores())
      assert_in_delta result, 0.0, 0.01
    end

    test "weights sum to 1.0" do
      # Base weights: P=0.20, R=0.15, O=0.15, M=0.20, Pub=0.15, T=0.15
      scores = high_methodology_scores()
      expected = 60 * 0.20 + 80 * 0.15 + 70 * 0.15 + 95 * 0.20 + 85 * 0.15 + 90 * 0.15
      result = PromptScores.calculate_overall(scores)
      assert_in_delta result, expected, 0.01
    end

    test "uses default 50 for missing dimensions" do
      result = PromptScores.calculate_overall(%{provenance: 100})
      # provenance=100*0.20 + (rest at 50*0.80) = 20 + 40 = 60
      assert_in_delta result, 60.0, 0.01
    end
  end

  describe "calculate_for_audience/2" do
    test "researcher weights prioritise methodology and replicability" do
      scores = high_methodology_scores()
      researcher = PromptScores.calculate_for_audience(scores, :researcher)
      policymaker = PromptScores.calculate_for_audience(scores, :policymaker)

      # High methodology (95) should boost researcher score more than policymaker
      assert researcher > policymaker
    end

    test "skeptic weights prioritise transparency and replicability" do
      scores = %PromptScores{
        provenance: 50,
        replicability: 90,
        objective: 50,
        methodology: 50,
        publication: 50,
        transparency: 95
      }

      skeptic = PromptScores.calculate_for_audience(scores, :skeptic)
      activist = PromptScores.calculate_for_audience(scores, :activist)

      # High transparency (95) and replicability (90) should boost skeptic more
      assert skeptic > activist
    end

    test "balanced scores give same result for all audiences" do
      scores = balanced_scores()

      results =
        [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist]
        |> Enum.map(&PromptScores.calculate_for_audience(scores, &1))

      # All should be 50.0 since all dimensions are 50
      for result <- results do
        assert_in_delta result, 50.0, 0.01
      end
    end

    test "researcher calculation matches expected formula" do
      scores = high_methodology_scores()
      # methodology=0.35, replicability=0.30, transparency=0.20,
      # provenance=0.10, objective=0.03, publication=0.02
      expected = 95 * 0.35 + 80 * 0.30 + 90 * 0.20 + 60 * 0.10 + 70 * 0.03 + 85 * 0.02

      result = PromptScores.calculate_for_audience(scores, :researcher)
      assert_in_delta result, expected, 0.01
    end

    test "policymaker calculation matches expected formula" do
      scores = high_methodology_scores()
      # provenance=0.30, publication=0.25, objective=0.25,
      # methodology=0.10, transparency=0.05, replicability=0.05
      expected = 60 * 0.30 + 85 * 0.25 + 70 * 0.25 + 95 * 0.10 + 90 * 0.05 + 80 * 0.05

      result = PromptScores.calculate_for_audience(scores, :policymaker)
      assert_in_delta result, expected, 0.01
    end

    test "falls back to base weights for unknown audience" do
      scores = balanced_scores()
      result = PromptScores.calculate_for_audience(scores, :unknown_audience)
      assert_in_delta result, 50.0, 0.01
    end
  end

  describe "audience_weights/1" do
    test "all audience weight sets sum to 1.0" do
      audiences = [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist]

      for audience <- audiences do
        weights = PromptScores.audience_weights(audience)
        sum = weights |> Map.values() |> Enum.sum()
        assert_in_delta sum, 1.0, 0.001, "#{audience} weights sum to #{sum}, expected 1.0"
      end
    end

    test "all audience weight sets cover all 6 dimensions" do
      dimensions = [:provenance, :replicability, :objective, :methodology, :publication, :transparency]
      audiences = [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist]

      for audience <- audiences do
        weights = PromptScores.audience_weights(audience)

        for dim <- dimensions do
          assert Map.has_key?(weights, dim),
                 "#{audience} missing weight for #{dim}"
        end
      end
    end

    test "all weights are positive" do
      audiences = [:researcher, :policymaker, :skeptic, :activist, :affected_person, :journalist]

      for audience <- audiences do
        weights = PromptScores.audience_weights(audience)

        for {dim, weight} <- weights do
          assert weight > 0, "#{audience}.#{dim} weight #{weight} is not positive"
        end
      end
    end
  end

  describe "to_map/1" do
    test "includes all 6 dimensions plus overall" do
      scores = high_methodology_scores()
      map = PromptScores.to_map(scores)

      assert map.provenance == 60
      assert map.replicability == 80
      assert map.objective == 70
      assert map.methodology == 95
      assert map.publication == 85
      assert map.transparency == 90
      assert is_float(map.overall)
    end

    test "overall in map matches calculate_overall" do
      scores = high_methodology_scores()
      map = PromptScores.to_map(scores)
      expected = PromptScores.calculate_overall(scores)
      assert_in_delta map.overall, expected, 0.01
    end
  end
end
