defmodule EvidenceGraph.Relationships do
  @moduledoc """
  Context for managing Relationships (edges) in the Evidence Graph.
  """

  alias EvidenceGraph.ArangoDB
  alias EvidenceGraph.Relationships.Relationship

  @doc """
  Get a relationship by ID.
  """
  def get_relationship(id) do
    case ArangoDB.get("relationships", id) do
      {:ok, doc} -> {:ok, Relationship.from_arango_doc(doc)}
      error -> error
    end
  end

  @doc """
  Create a new relationship.

  ## Examples

      iex> create_relationship(%{
      ...>   from_id: "claim_1",
      ...>   from_type: :claim,
      ...>   to_id: "evidence_1",
      ...>   to_type: :evidence,
      ...>   relationship_type: :supports,
      ...>   weight: 1.0,
      ...>   confidence: 0.95
      ...> })
      {:ok, %Relationship{}}
  """
  def create_relationship(attrs) do
    changeset = Relationship.changeset(%Relationship{}, attrs)

    if changeset.valid? do
      relationship =
        Ecto.Changeset.apply_changes(changeset)
        |> Map.put(:inserted_at, DateTime.utc_now())

      case ArangoDB.insert("relationships", Relationship.to_arango_doc(relationship)) do
        {:ok, doc} -> {:ok, Relationship.from_arango_doc(doc)}
        error -> error
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Update a relationship (typically weight/confidence).
  """
  def update_relationship(id, attrs) do
    with {:ok, relationship} <- get_relationship(id) do
      changeset = Relationship.changeset(relationship, attrs)

      if changeset.valid? do
        updates =
          Ecto.Changeset.apply_changes(changeset)
          |> Relationship.to_arango_doc()
          |> Map.drop([:_key, :_from, :_to, :inserted_at])

        case ArangoDB.update("relationships", id, updates) do
          {:ok, doc} -> {:ok, Relationship.from_arango_doc(doc)}
          error -> error
        end
      else
        {:error, changeset}
      end
    end
  end

  @doc """
  Delete a relationship.
  """
  def delete_relationship(id) do
    case ArangoDB.delete("relationships", id) do
      {:ok, _doc} -> :ok
      error -> error
    end
  end

  @doc """
  Get all relationships for a node (claim or evidence).
  """
  def get_node_relationships(node_id, node_type) do
    collection = if node_type == :claim, do: "claims", else: "evidence"

    aql = """
    FOR node IN #{collection}
      FILTER node._key == @node_id
      FOR v, e IN 1..1 ANY node relationships
        RETURN e
    """

    case ArangoDB.query_read(aql, %{node_id: node_id}) do
      {:ok, docs} -> {:ok, Enum.map(docs, &Relationship.from_arango_doc/1)}
      error -> error
    end
  end

  @doc """
  Find evidence chain from a claim (multi-hop traversal).

  Returns graph of nodes and edges within max_depth hops.
  """
  def evidence_chain(claim_id, max_depth \\ 3) do
    aql = """
    FOR claim IN claims
      FILTER claim._key == @claim_id
      LET graph = (
        FOR v, e, p IN 1..@max_depth ANY claim relationships
          RETURN {
            vertex: v,
            edge: e,
            path: p,
            depth: LENGTH(p.edges)
          }
      )
      RETURN {
        root_claim: claim,
        nodes: graph[*].vertex,
        edges: graph[*].edge,
        max_depth: MAX(graph[*].depth)
      }
    """

    case ArangoDB.query_read(aql, %{claim_id: claim_id, max_depth: max_depth}) do
      {:ok, [result]} ->
        {:ok,
         %{
           root_claim: EvidenceGraph.Claims.Claim.from_arango_doc(result["root_claim"]),
           nodes: parse_nodes(result["nodes"]),
           edges: Enum.map(result["edges"], &Relationship.from_arango_doc/1),
           max_depth: result["max_depth"] || 0
         }}

      {:ok, []} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  defp parse_nodes(nodes) do
    Enum.map(nodes, fn node ->
      cond do
        String.starts_with?(node["_id"], "claims/") ->
          {:claim, EvidenceGraph.Claims.Claim.from_arango_doc(node)}

        String.starts_with?(node["_id"], "evidence/") ->
          {:evidence, EvidenceGraph.Evidence.Evidence.from_arango_doc(node)}

        true ->
          {:unknown, node}
      end
    end)
  end

  @doc """
  Find path between two nodes.

  Uses ArangoDB's shortest path algorithm.
  """
  def find_path(from_id, from_type, to_id, to_type, max_depth \\ 5) do
    from_collection = if from_type == :claim, do: "claims", else: "evidence"
    to_collection = if to_type == :claim, do: "claims", else: "evidence"

    aql = """
    FOR path IN ANY SHORTEST_PATH
      "#{from_collection}/#{from_id}"
      TO "#{to_collection}/#{to_id}"
      relationships
      OPTIONS {weightAttribute: 'weight'}
      LIMIT 1
      RETURN {
        vertices: path.vertices,
        edges: path.edges,
        distance: LENGTH(path.edges)
      }
    """

    case ArangoDB.query_read(aql, %{}) do
      {:ok, [result]} ->
        {:ok,
         %{
           path: parse_nodes(result["vertices"]),
           edges: Enum.map(result["edges"], &Relationship.from_arango_doc/1),
           distance: result["distance"]
         }}

      {:ok, []} ->
        {:error, :no_path_found}

      error ->
        error
    end
  end

  @doc """
  Calculate propagated weight along a path.

  Weights are multiplied, so long chains decay.
  """
  def propagated_weight(relationships) when is_list(relationships) do
    relationships
    |> Enum.map(&Relationship.effective_weight/1)
    |> Enum.reduce(1.0, &*/2)
  end

  @doc """
  Find contradictions in an investigation.

  Returns claims that have both supporting and contradicting evidence.
  """
  def find_contradictions(investigation_id) do
    aql = """
    FOR claim IN claims
      FILTER claim.investigation_id == @investigation_id
      LET supporting = LENGTH(
        FOR v, e IN 1..1 OUTBOUND claim relationships
          FILTER e.relationship_type == "supports"
          RETURN 1
      )
      LET contradicting = LENGTH(
        FOR v, e IN 1..1 OUTBOUND claim relationships
          FILTER e.relationship_type == "contradicts"
          RETURN 1
      )
      FILTER contradicting > 0
      RETURN {
        claim: claim,
        support_count: supporting,
        contradiction_count: contradicting
      }
    """

    case ArangoDB.query_read(aql, %{investigation_id: investigation_id}) do
      {:ok, results} ->
        contradictions =
          Enum.map(results, fn result ->
            %{
              claim: EvidenceGraph.Claims.Claim.from_arango_doc(result["claim"]),
              support_count: result["support_count"],
              contradiction_count: result["contradiction_count"]
            }
          end)

        {:ok, contradictions}

      error ->
        error
    end
  end
end
