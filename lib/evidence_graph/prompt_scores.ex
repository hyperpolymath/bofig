defmodule EvidenceGraph.PromptScores do
  @moduledoc """
  PROMPT epistemological scoring framework.

  Six dimensions for evaluating evidence quality:
  - Provenance: Source credibility and authority
  - Replicability: Can others verify this?
  - Objective: Clear operational definitions
  - Methodology: Research quality and rigor
  - Publication: Peer review and venue quality
  - Transparency: Open data and methods

  Each dimension scored 0-100.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @weights %{
    provenance: 0.20,
    replicability: 0.15,
    objective: 0.15,
    methodology: 0.20,
    publication: 0.15,
    transparency: 0.15
  }

  @audience_weights %{
    researcher: %{
      methodology: 0.35,
      replicability: 0.30,
      transparency: 0.20,
      provenance: 0.10,
      objective: 0.03,
      publication: 0.02
    },
    policymaker: %{
      provenance: 0.30,
      publication: 0.25,
      objective: 0.25,
      methodology: 0.10,
      transparency: 0.05,
      replicability: 0.05
    },
    skeptic: %{
      transparency: 0.35,
      replicability: 0.30,
      methodology: 0.20,
      provenance: 0.10,
      objective: 0.03,
      publication: 0.02
    },
    activist: %{
      provenance: 0.30,
      objective: 0.25,
      publication: 0.20,
      methodology: 0.15,
      transparency: 0.05,
      replicability: 0.05
    },
    affected_person: %{
      objective: 0.35,
      provenance: 0.30,
      transparency: 0.20,
      methodology: 0.10,
      publication: 0.03,
      replicability: 0.02
    },
    journalist: %{
      provenance: 0.25,
      transparency: 0.25,
      replicability: 0.20,
      methodology: 0.15,
      objective: 0.10,
      publication: 0.05
    }
  }

  @primary_key false
  embedded_schema do
    field :provenance, :integer, default: 50
    field :replicability, :integer, default: 50
    field :objective, :integer, default: 50
    field :methodology, :integer, default: 50
    field :publication, :integer, default: 50
    field :transparency, :integer, default: 50
  end

  def changeset(scores, attrs) do
    scores
    |> cast(attrs, [:provenance, :replicability, :objective, :methodology, :publication, :transparency])
    |> validate_number(:provenance, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:replicability, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:objective, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:methodology, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:publication, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:transparency, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  @doc """
  Calculate overall PROMPT score (weighted average).

  ## Examples

      iex> calculate_overall(%{provenance: 90, replicability: 80, ...})
      85.5
  """
  def calculate_overall(scores) do
    Enum.reduce(@weights, 0.0, fn {dimension, weight}, acc ->
      score = Map.get(scores, dimension, 50)
      acc + score * weight
    end)
  end

  @doc """
  Calculate audience-weighted score.

  ## Examples

      iex> calculate_for_audience(scores, :researcher)
      88.2
  """
  def calculate_for_audience(scores, audience_type) do
    weights = Map.get(@audience_weights, audience_type, @weights)

    Enum.reduce(weights, 0.0, fn {dimension, weight}, acc ->
      score = Map.get(scores, dimension, 50)
      acc + score * weight
    end)
  end

  @doc """
  Get audience-specific weights.
  """
  def audience_weights(audience_type) do
    Map.get(@audience_weights, audience_type, @weights)
  end

  @doc """
  Convert to map for JSON/GraphQL.
  """
  def to_map(%__MODULE__{} = scores) do
    %{
      provenance: scores.provenance,
      replicability: scores.replicability,
      objective: scores.objective,
      methodology: scores.methodology,
      publication: scores.publication,
      transparency: scores.transparency,
      overall: calculate_overall(scores)
    }
  end
end
