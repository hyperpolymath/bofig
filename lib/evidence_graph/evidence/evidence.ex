defmodule EvidenceGraph.Evidence.Evidence do
  @moduledoc """
  Evidence schema for Evidence Graph.

  Evidence represents documents, datasets, interviews, media, and other
  sources that support or contradict claims.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias EvidenceGraph.PromptScores

  @type t :: %__MODULE__{
          id: String.t() | nil,
          investigation_id: String.t(),
          title: String.t(),
          evidence_type: atom(),
          source_url: String.t() | nil,
          local_path: String.t() | nil,
          ipfs_hash: String.t() | nil,
          zotero_key: String.t() | nil,
          zotero_version: integer() | nil,
          dublin_core: map(),
          schema_org: map(),
          prompt_scores: PromptScores.t(),
          tags: list(String.t()),
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @evidence_types [:document, :dataset, :interview, :media, :other]

  @primary_key {:id, :string, autogenerate: false}
  schema "evidence" do
    field :investigation_id, :string
    field :title, :string
    field :evidence_type, Ecto.Enum, values: @evidence_types
    field :source_url, :string
    field :local_path, :string
    field :ipfs_hash, :string
    field :zotero_key, :string
    field :zotero_version, :integer
    field :dublin_core, :map, default: %{}
    field :schema_org, :map, default: %{}
    field :tags, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    embeds_one :prompt_scores, PromptScores, on_replace: :update

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(evidence, attrs) do
    evidence
    |> cast(attrs, [
      :investigation_id,
      :title,
      :evidence_type,
      :source_url,
      :local_path,
      :ipfs_hash,
      :zotero_key,
      :zotero_version,
      :dublin_core,
      :schema_org,
      :tags,
      :metadata
    ])
    |> cast_embed(:prompt_scores)
    |> validate_required([:investigation_id, :title, :evidence_type])
    |> validate_inclusion(:evidence_type, @evidence_types)
    |> validate_length(:title, min: 3, max: 500)
    |> put_id()
  end

  defp put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, "evidence_" <> Ecto.UUID.generate())
  end

  defp put_id(changeset), do: changeset

  @doc """
  Convert to ArangoDB document format.
  """
  def to_arango_doc(%__MODULE__{} = evidence) do
    %{
      _key: evidence.id,
      investigation_id: evidence.investigation_id,
      title: evidence.title,
      evidence_type: to_string(evidence.evidence_type),
      source_url: evidence.source_url,
      local_path: evidence.local_path,
      ipfs_hash: evidence.ipfs_hash,
      zotero_key: evidence.zotero_key,
      zotero_version: evidence.zotero_version,
      dublin_core: evidence.dublin_core,
      schema_org: evidence.schema_org,
      prompt_scores: PromptScores.to_map(evidence.prompt_scores),
      tags: evidence.tags,
      metadata: evidence.metadata,
      inserted_at: evidence.inserted_at,
      updated_at: evidence.updated_at
    }
  end

  @doc """
  Convert from ArangoDB document to Evidence struct.
  """
  def from_arango_doc(doc) do
    %__MODULE__{
      id: doc["_key"],
      investigation_id: doc["investigation_id"],
      title: doc["title"],
      evidence_type: String.to_existing_atom(doc["evidence_type"]),
      source_url: doc["source_url"],
      local_path: doc["local_path"],
      ipfs_hash: doc["ipfs_hash"],
      zotero_key: doc["zotero_key"],
      zotero_version: doc["zotero_version"],
      dublin_core: doc["dublin_core"] || %{},
      schema_org: doc["schema_org"] || %{},
      prompt_scores: struct(PromptScores, doc["prompt_scores"] || %{}),
      tags: doc["tags"] || [],
      metadata: doc["metadata"] || %{},
      inserted_at: parse_datetime(doc["inserted_at"]),
      updated_at: parse_datetime(doc["updated_at"])
    }
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(dt) when is_binary(dt), do: DateTime.from_iso8601(dt) |> elem(1)
  defp parse_datetime(%DateTime{} = dt), do: dt

  @doc """
  Convert to Zotero JSON format for export.
  """
  def to_zotero_json(%__MODULE__{} = evidence) do
    %{
      key: evidence.zotero_key || evidence.id,
      version: evidence.zotero_version || 0,
      itemType: zotero_item_type(evidence.evidence_type),
      title: evidence.title,
      url: evidence.source_url,
      tags: Enum.map(evidence.tags, &%{tag: &1}),
      # Dublin Core mappings
      creators: parse_creators(evidence.dublin_core["creator"]),
      date: evidence.dublin_core["date"],
      publisher: evidence.dublin_core["publisher"],
      abstractNote: evidence.dublin_core["description"],
      language: evidence.dublin_core["language"],
      rights: evidence.dublin_core["rights"],
      # Custom field with PROMPT scores
      extra: build_extra_field(evidence)
    }
  end

  defp zotero_item_type(:document), do: "journalArticle"
  defp zotero_item_type(:dataset), do: "dataset"
  defp zotero_item_type(:interview), do: "interview"
  defp zotero_item_type(:media), do: "audioRecording"
  defp zotero_item_type(_), do: "webpage"

  defp parse_creators(nil), do: []

  defp parse_creators(creator) when is_binary(creator) do
    creator
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&%{name: &1})
  end

  defp parse_creators(_), do: []

  defp build_extra_field(evidence) do
    scores = evidence.prompt_scores

    """
    evidence_graph_id: #{evidence.id}
    PROMPT Scores:
    - Provenance: #{scores.provenance}/100
    - Replicability: #{scores.replicability}/100
    - Objective: #{scores.objective}/100
    - Methodology: #{scores.methodology}/100
    - Publication: #{scores.publication}/100
    - Transparency: #{scores.transparency}/100
    Overall: #{Float.round(PromptScores.calculate_overall(scores), 1)}/100
    """
  end
end
