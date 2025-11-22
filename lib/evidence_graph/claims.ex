defmodule EvidenceGraph.Claims do
  @moduledoc """
  Context for managing Claims in the Evidence Graph.
  """

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Claims.Claim

  @doc """
  Get a claim by ID.

  ## Examples

      iex> get_claim("claim_123")
      {:ok, %Claim{}}

      iex> get_claim("nonexistent")
      {:error, :not_found}
  """
  def get_claim(id) do
    case ArangoDB.get("claims", id) do
      {:ok, doc} -> {:ok, Claim.from_arango_doc(doc)}
      error -> error
    end
  end

  @doc """
  Get a claim by ID, raises if not found.
  """
  def get_claim!(id) do
    case get_claim(id) do
      {:ok, claim} -> claim
      {:error, :not_found} -> raise "Claim not found: #{id}"
    end
  end

  @doc """
  List all claims for an investigation.
  """
  def list_claims(investigation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    aql = """
    FOR claim IN claims
      FILTER claim.investigation_id == @investigation_id
      SORT claim.inserted_at DESC
      LIMIT @offset, @limit
      RETURN claim
    """

    case ArangoDB.query_read(aql, %{
           investigation_id: investigation_id,
           limit: limit,
           offset: offset
         }) do
      {:ok, docs} -> {:ok, Enum.map(docs, &Claim.from_arango_doc/1)}
      error -> error
    end
  end

  @doc """
  Create a new claim.

  ## Examples

      iex> create_claim(%{
      ...>   investigation_id: "inv_123",
      ...>   text: "UK inflation reached 11.1%",
      ...>   claim_type: :primary
      ...> })
      {:ok, %Claim{}}
  """
  def create_claim(attrs) do
    changeset = Claim.changeset(%Claim{}, attrs)

    if changeset.valid? do
      claim = Ecto.Changeset.apply_changes(changeset)
      |> Map.put(:inserted_at, DateTime.utc_now())
      |> Map.put(:updated_at, DateTime.utc_now())

      case ArangoDB.insert("claims", Claim.to_arango_doc(claim)) do
        {:ok, doc} -> {:ok, Claim.from_arango_doc(doc)}
        error -> error
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Update a claim.
  """
  def update_claim(id, attrs) do
    with {:ok, claim} <- get_claim(id) do
      changeset = Claim.changeset(claim, attrs)

      if changeset.valid? do
        updates =
          Ecto.Changeset.apply_changes(changeset)
          |> Map.put(:updated_at, DateTime.utc_now())
          |> Claim.to_arango_doc()
          |> Map.drop([:_key, :inserted_at])

        case ArangoDB.update("claims", id, updates) do
          {:ok, doc} -> {:ok, Claim.from_arango_doc(doc)}
          error -> error
        end
      else
        {:error, changeset}
      end
    end
  end

  @doc """
  Delete a claim.
  """
  def delete_claim(id) do
    case ArangoDB.delete("claims", id) do
      {:ok, _doc} -> :ok
      error -> error
    end
  end

  @doc """
  Search claims by text.
  """
  def search_claims(query_text, investigation_id \\ nil) do
    aql =
      if investigation_id do
        """
        FOR claim IN FULLTEXT(claims, "text", @query)
          FILTER claim.investigation_id == @investigation_id
          RETURN claim
        """
      else
        """
        FOR claim IN FULLTEXT(claims, "text", @query)
          RETURN claim
        """
      end

    vars = %{query: query_text, investigation_id: investigation_id}

    case ArangoDB.query_read(aql, vars) do
      {:ok, docs} -> {:ok, Enum.map(docs, &Claim.from_arango_doc/1)}
      error -> error
    end
  end

  @doc """
  Get all evidence supporting a claim.
  """
  def get_supporting_evidence(claim_id) do
    aql = """
    FOR claim IN claims
      FILTER claim._key == @claim_id
      FOR v, e IN 1..1 OUTBOUND claim relationships
        FILTER e.relationship_type == "supports"
        FILTER IS_SAME_COLLECTION("evidence", v)
        RETURN {evidence: v, relationship: e}
    """

    case ArangoDB.query_read(aql, %{claim_id: claim_id}) do
      {:ok, results} ->
        evidence =
          Enum.map(results, fn %{"evidence" => ev, "relationship" => rel} ->
            %{
              evidence: EvidenceGraph.Evidence.Evidence.from_arango_doc(ev),
              weight: rel["weight"],
              confidence: rel["confidence"],
              reasoning: rel["reasoning"]
            }
          end)

        {:ok, evidence}

      error ->
        error
    end
  end

  @doc """
  Get contradicting evidence for a claim.
  """
  def get_contradicting_evidence(claim_id) do
    aql = """
    FOR claim IN claims
      FILTER claim._key == @claim_id
      FOR v, e IN 1..1 OUTBOUND claim relationships
        FILTER e.relationship_type == "contradicts"
        FILTER IS_SAME_COLLECTION("evidence", v)
        RETURN {evidence: v, relationship: e}
    """

    case ArangoDB.query_read(aql, %{claim_id: claim_id}) do
      {:ok, results} ->
        evidence =
          Enum.map(results, fn %{"evidence" => ev, "relationship" => rel} ->
            %{
              evidence: EvidenceGraph.Evidence.Evidence.from_arango_doc(ev),
              weight: rel["weight"],
              confidence: rel["confidence"],
              reasoning: rel["reasoning"]
            }
          end)

        {:ok, evidence}

      error ->
        error
    end
  end
end
