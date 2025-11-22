defmodule EvidenceGraph.Claims.Claim do
  @moduledoc """
  Claim schema for Evidence Graph.

  A claim is an assertion made in an investigation that requires evidence support.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias EvidenceGraph.PromptScores

  @type t :: %__MODULE__{
          id: String.t() | nil,
          investigation_id: String.t(),
          text: String.t(),
          claim_type: atom(),
          confidence_level: float(),
          prompt_scores: PromptScores.t(),
          created_by: String.t() | nil,
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @claim_types [:primary, :supporting, :counter]

  @primary_key {:id, :string, autogenerate: false}
  schema "claims" do
    field :investigation_id, :string
    field :text, :string
    field :claim_type, Ecto.Enum, values: @claim_types
    field :confidence_level, :float, default: 0.5
    field :created_by, :string
    field :metadata, :map, default: %{}

    embeds_one :prompt_scores, PromptScores, on_replace: :update

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(claim, attrs) do
    claim
    |> cast(attrs, [:investigation_id, :text, :claim_type, :confidence_level, :created_by, :metadata])
    |> cast_embed(:prompt_scores)
    |> validate_required([:investigation_id, :text, :claim_type])
    |> validate_inclusion(:claim_type, @claim_types)
    |> validate_number(:confidence_level, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_length(:text, min: 10, max: 5000)
    |> put_id()
  end

  defp put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, "claim_" <> Ecto.UUID.generate())
  end

  defp put_id(changeset), do: changeset

  @doc """
  Convert to ArangoDB document format.
  """
  def to_arango_doc(%__MODULE__{} = claim) do
    %{
      _key: claim.id,
      investigation_id: claim.investigation_id,
      text: claim.text,
      claim_type: to_string(claim.claim_type),
      confidence_level: claim.confidence_level,
      prompt_scores: PromptScores.to_map(claim.prompt_scores),
      created_by: claim.created_by,
      metadata: claim.metadata,
      inserted_at: claim.inserted_at,
      updated_at: claim.updated_at
    }
  end

  @doc """
  Convert from ArangoDB document to Claim struct.
  """
  def from_arango_doc(doc) do
    %__MODULE__{
      id: doc["_key"],
      investigation_id: doc["investigation_id"],
      text: doc["text"],
      claim_type: String.to_existing_atom(doc["claim_type"]),
      confidence_level: doc["confidence_level"],
      prompt_scores: struct(PromptScores, doc["prompt_scores"] || %{}),
      created_by: doc["created_by"],
      metadata: doc["metadata"] || %{},
      inserted_at: parse_datetime(doc["inserted_at"]),
      updated_at: parse_datetime(doc["updated_at"])
    }
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(dt) when is_binary(dt), do: DateTime.from_iso8601(dt) |> elem(1)
  defp parse_datetime(%DateTime{} = dt), do: dt
end
