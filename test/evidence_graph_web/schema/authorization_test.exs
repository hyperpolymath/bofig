# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.AuthorizationTest do
  @moduledoc """
  Integration tests verifying RBAC authorization on all GraphQL resolvers.

  Tests exercise the Absinthe schema directly (via `Absinthe.run/3`) with
  controlled context maps, against the live ArangoDB test database. Each test
  block seeds the required access grants and domain objects (investigations,
  claims, evidence) and removes them on exit.
  """

  use EvidenceGraphWeb.ConnCase

  alias EvidenceGraph.{ArangoDB, Authorization}
  alias EvidenceGraphWeb.Schema, as: GQLSchema

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @investigation_id "inv_auth_test"
  @other_investigation_id "inv_auth_other"

  @owner_id "user_owner_auth_test"
  @editor_id "user_editor_auth_test"
  @reviewer_id "user_reviewer_auth_test"
  @viewer_id "user_viewer_auth_test"
  @outsider_id "user_outsider_auth_test"

  defp run_query(document, variables \\ %{}, context \\ %{}) do
    Absinthe.run(document, GQLSchema, variables: variables, context: context)
  end

  defp authed_context(user_id), do: %{current_user_id: user_id}

  defp seed_investigation(id, title \\ "Auth Test Investigation") do
    now = DateTime.to_iso8601(DateTime.utc_now())

    aql = """
    UPSERT {_key: @key}
    INSERT {
      _key: @key,
      title: @title,
      description: "Seeded for authorization tests",
      status: "active",
      created_by: @owner,
      metadata: {},
      inserted_at: @now,
      updated_at: @now
    }
    UPDATE {}
    IN investigations
    RETURN NEW
    """

    ArangoDB.query(aql, %{key: id, title: title, owner: @owner_id, now: now})
  end

  defp seed_claim(id, investigation_id) do
    now = DateTime.to_iso8601(DateTime.utc_now())

    aql = """
    UPSERT {_key: @key}
    INSERT {
      _key: @key,
      investigation_id: @inv_id,
      text: "Authorization test claim seeded for integration testing",
      claim_type: "primary",
      confidence_level: 0.8,
      prompt_scores: {provenance: 70, replicability: 60, objective: 65, methodology: 80, publication: 75, transparency: 70},
      created_by: "auth_test",
      metadata: {},
      inserted_at: @now,
      updated_at: @now
    }
    UPDATE {}
    IN claims
    RETURN NEW
    """

    ArangoDB.query(aql, %{key: id, inv_id: investigation_id, now: now})
  end

  defp seed_evidence(id, investigation_id) do
    now = DateTime.to_iso8601(DateTime.utc_now())

    aql = """
    UPSERT {_key: @key}
    INSERT {
      _key: @key,
      investigation_id: @inv_id,
      title: "Authorization test evidence",
      evidence_type: "document",
      source_url: "https://example.org/auth-test",
      tags: ["auth-test"],
      dublin_core: {},
      schema_org: {},
      prompt_scores: {provenance: 80, replicability: 75, objective: 70, methodology: 85, publication: 80, transparency: 75},
      metadata: {},
      zotero_key: null,
      zotero_version: null,
      local_path: null,
      ipfs_hash: null,
      inserted_at: @now,
      updated_at: @now
    }
    UPDATE {}
    IN evidence
    RETURN NEW
    """

    ArangoDB.query(aql, %{key: id, inv_id: investigation_id, now: now})
  end

  defp cleanup_arango_docs(collection, keys) when is_list(keys) do
    aql = """
    FOR key IN @keys
      REMOVE {_key: key} IN #{collection}
      OPTIONS {ignoreErrors: true}
    """

    ArangoDB.query(aql, %{keys: keys})
  end

  defp cleanup_access_grants(investigation_ids) when is_list(investigation_ids) do
    aql = """
    FOR grant IN access_grants
      FILTER grant.investigation_id IN @ids
      REMOVE grant IN access_grants
      OPTIONS {ignoreErrors: true}
    """

    ArangoDB.query(aql, %{ids: investigation_ids})
  end

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    # Seed investigations
    seed_investigation(@investigation_id)
    seed_investigation(@other_investigation_id, "Other Investigation")

    # Seed domain objects
    seed_claim("claim_auth_test_1", @investigation_id)
    seed_evidence("ev_auth_test_1", @investigation_id)

    # Seed access grants at various permission levels
    Authorization.grant_access(@investigation_id, @owner_id, :owner)
    Authorization.grant_access(@investigation_id, @editor_id, :editor)
    Authorization.grant_access(@investigation_id, @reviewer_id, :reviewer)
    Authorization.grant_access(@investigation_id, @viewer_id, :viewer)

    # Owner of the other investigation (outsider has no access to @investigation_id)
    Authorization.grant_access(@other_investigation_id, @outsider_id, :owner)

    on_exit(fn ->
      cleanup_access_grants([@investigation_id, @other_investigation_id])
      cleanup_arango_docs("claims", ["claim_auth_test_1"])
      cleanup_arango_docs("evidence", ["ev_auth_test_1"])
      cleanup_arango_docs("investigations", [@investigation_id, @other_investigation_id])
    end)

    :ok
  end

  # ===========================================================================
  # 1. Unauthenticated requests
  # ===========================================================================

  describe "unauthenticated requests" do
    test "query :claim without user returns authentication error" do
      query = """
      query GetClaim($id: ID!) {
        claim(id: $id) { id text }
      }
      """

      {:ok, result} = run_query(query, %{"id" => "claim_auth_test_1"})

      assert %{errors: [%{message: message}]} = result
      assert message =~ "Authentication required"
    end

    test "query :claims without user returns authentication error" do
      query = """
      query ListClaims($invId: String!) {
        claims(investigationId: $invId) { id text }
      }
      """

      {:ok, result} = run_query(query, %{"invId" => @investigation_id})

      assert %{errors: [%{message: message}]} = result
      assert message =~ "Authentication required"
    end

    test "query :investigation without user returns authentication error" do
      query = """
      query GetInvestigation($id: ID!) {
        investigation(id: $id) { id title }
      }
      """

      {:ok, result} = run_query(query, %{"id" => @investigation_id})

      assert %{errors: [%{message: message}]} = result
      assert message =~ "Authentication required"
    end

    test "query :evidence without user returns authentication error" do
      query = """
      query GetEvidence($id: ID!) {
        evidence(id: $id) { id title }
      }
      """

      {:ok, result} = run_query(query, %{"id" => "ev_auth_test_1"})

      assert %{errors: [%{message: message}]} = result
      assert message =~ "Authentication required"
    end

    test "mutation :createClaim without user returns authentication error" do
      mutation = """
      mutation CreateClaim($input: CreateClaimInput!) {
        createClaim(input: $input) { id text }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "text" => "Unauthenticated claim attempt during authorization testing",
        "claimType" => "PRIMARY"
      }

      {:ok, result} = run_query(mutation, %{"input" => input})

      assert %{errors: [%{message: message}]} = result
      assert message =~ "Authentication required"
    end

    test "mutation :grantAccess without user returns authentication error" do
      mutation = """
      mutation GrantAccess($input: GrantAccessInput!) {
        grantAccess(input: $input) { id userId role }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "userId" => "some_user",
        "role" => "VIEWER"
      }

      {:ok, result} = run_query(mutation, %{"input" => input})

      assert %{errors: [%{message: message}]} = result
      assert message =~ "Authentication required"
    end
  end

  # ===========================================================================
  # 2. Unauthorized access — user without access to the investigation
  # ===========================================================================

  describe "unauthorized access (outsider)" do
    test "outsider cannot query a claim in an investigation they lack access to" do
      query = """
      query GetClaim($id: ID!) {
        claim(id: $id) { id text }
      }
      """

      {:ok, result} = run_query(query, %{"id" => "claim_auth_test_1"}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "outsider cannot list claims for an investigation they lack access to" do
      query = """
      query ListClaims($invId: String!) {
        claims(investigationId: $invId) { id text }
      }
      """

      {:ok, result} = run_query(query, %{"invId" => @investigation_id}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "outsider cannot query the investigation directly" do
      query = """
      query GetInvestigation($id: ID!) {
        investigation(id: $id) { id title }
      }
      """

      {:ok, result} = run_query(query, %{"id" => @investigation_id}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "outsider cannot query evidence in the investigation" do
      query = """
      query GetEvidence($id: ID!) {
        evidence(id: $id) { id title }
      }
      """

      {:ok, result} = run_query(query, %{"id" => "ev_auth_test_1"}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "outsider cannot create a claim in the investigation" do
      mutation = """
      mutation CreateClaim($input: CreateClaimInput!) {
        createClaim(input: $input) { id text }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "text" => "Outsider attempting to create a claim in foreign investigation",
        "claimType" => "PRIMARY"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "outsider cannot grant access on the investigation" do
      mutation = """
      mutation GrantAccess($input: GrantAccessInput!) {
        grantAccess(input: $input) { id userId role }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "userId" => "some_new_user",
        "role" => "VIEWER"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "outsider cannot list another user's investigations" do
      query = """
      query UserInvestigations($userId: String!) {
        userInvestigations(userId: $userId) { investigationId role }
      }
      """

      {:ok, result} =
        run_query(query, %{"userId" => @owner_id}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end
  end

  # ===========================================================================
  # 3. Authorized access — user with correct access gets data
  # ===========================================================================

  describe "authorized access (viewer)" do
    test "viewer can query a claim in their investigation" do
      query = """
      query GetClaim($id: ID!) {
        claim(id: $id) { id text investigationId }
      }
      """

      {:ok, result} = run_query(query, %{"id" => "claim_auth_test_1"}, authed_context(@viewer_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"claim" => %{"id" => "claim_auth_test_1"}}} = result
    end

    test "viewer can list claims in their investigation" do
      query = """
      query ListClaims($invId: String!) {
        claims(investigationId: $invId) { id text }
      }
      """

      {:ok, result} = run_query(query, %{"invId" => @investigation_id}, authed_context(@viewer_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"claims" => claims}} = result
      assert is_list(claims)
    end

    test "viewer can query the investigation" do
      query = """
      query GetInvestigation($id: ID!) {
        investigation(id: $id) { id title }
      }
      """

      {:ok, result} =
        run_query(query, %{"id" => @investigation_id}, authed_context(@viewer_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"investigation" => %{"id" => @investigation_id}}} = result
    end

    test "viewer can query evidence in their investigation" do
      query = """
      query GetEvidence($id: ID!) {
        evidence(id: $id) { id title }
      }
      """

      {:ok, result} = run_query(query, %{"id" => "ev_auth_test_1"}, authed_context(@viewer_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"evidence" => %{"id" => "ev_auth_test_1"}}} = result
    end

    test "viewer can list collaborators on their investigation" do
      query = """
      query Collaborators($invId: String!) {
        collaborators(investigationId: $invId) { userId role }
      }
      """

      {:ok, result} = run_query(query, %{"invId" => @investigation_id}, authed_context(@viewer_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"collaborators" => collaborators}} = result
      assert length(collaborators) >= 4
    end

    test "viewer can list their own investigations" do
      query = """
      query UserInvestigations($userId: String!) {
        userInvestigations(userId: $userId) { investigationId role }
      }
      """

      {:ok, result} =
        run_query(query, %{"userId" => @viewer_id}, authed_context(@viewer_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"userInvestigations" => grants}} = result
      assert Enum.any?(grants, &(&1["investigationId"] == @investigation_id))
    end
  end

  # ===========================================================================
  # 4. Permission levels — :view vs :edit vs :delete vs :manage
  # ===========================================================================

  describe "permission levels — viewer cannot mutate" do
    test "viewer cannot create a claim (:edit required)" do
      mutation = """
      mutation CreateClaim($input: CreateClaimInput!) {
        createClaim(input: $input) { id text }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "text" => "Viewer attempting to create a claim without edit permission",
        "claimType" => "SUPPORTING"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@viewer_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "viewer cannot create evidence (:edit required)" do
      mutation = """
      mutation CreateEvidence($input: CreateEvidenceInput!) {
        createEvidence(input: $input) { id title }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "title" => "Viewer should not be able to add evidence",
        "evidenceType" => "DOCUMENT"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@viewer_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "viewer cannot update an investigation (:edit required)" do
      mutation = """
      mutation UpdateInvestigation($id: ID!, $input: UpdateInvestigationInput!) {
        updateInvestigation(id: $id, input: $input) { id title }
      }
      """

      {:ok, result} =
        run_query(
          mutation,
          %{"id" => @investigation_id, "input" => %{"title" => "Hacked Title"}},
          authed_context(@viewer_id)
        )

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "viewer cannot grant access (:manage required)" do
      mutation = """
      mutation GrantAccess($input: GrantAccessInput!) {
        grantAccess(input: $input) { id }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "userId" => "some_user",
        "role" => "VIEWER"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@viewer_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "viewer cannot archive an investigation (:manage required)" do
      mutation = """
      mutation ArchiveInvestigation($id: ID!) {
        archiveInvestigation(id: $id) { id status }
      }
      """

      {:ok, result} =
        run_query(mutation, %{"id" => @investigation_id}, authed_context(@viewer_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end
  end

  describe "permission levels — reviewer has :view and :export but not :edit" do
    test "reviewer can query claims (has :view)" do
      query = """
      query ListClaims($invId: String!) {
        claims(investigationId: $invId) { id text }
      }
      """

      {:ok, result} =
        run_query(query, %{"invId" => @investigation_id}, authed_context(@reviewer_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"claims" => _}} = result
    end

    test "reviewer cannot create a claim (lacks :edit)" do
      mutation = """
      mutation CreateClaim($input: CreateClaimInput!) {
        createClaim(input: $input) { id text }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "text" => "Reviewer attempting to create a claim without edit permission",
        "claimType" => "PRIMARY"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@reviewer_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "reviewer cannot grant access (lacks :manage)" do
      mutation = """
      mutation GrantAccess($input: GrantAccessInput!) {
        grantAccess(input: $input) { id }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "userId" => "attacker",
        "role" => "EDITOR"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@reviewer_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end
  end

  describe "permission levels — editor has :view, :edit, :export, :share" do
    test "editor can query claims" do
      query = """
      query ListClaims($invId: String!) {
        claims(investigationId: $invId) { id text }
      }
      """

      {:ok, result} =
        run_query(query, %{"invId" => @investigation_id}, authed_context(@editor_id))

      refute Map.has_key?(result, :errors)
    end

    test "editor can create a claim (:edit allowed)" do
      mutation = """
      mutation CreateClaim($input: CreateClaimInput!) {
        createClaim(input: $input) { id text investigationId }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "text" => "Editor creating a legitimate claim with proper edit permissions",
        "claimType" => "SUPPORTING"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@editor_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"createClaim" => %{"investigationId" => @investigation_id}}} = result

      # Clean up the created claim
      if claim_id = get_in(result, [:data, "createClaim", "id"]) do
        cleanup_arango_docs("claims", [claim_id])
      end
    end

    test "editor can update a claim (:edit allowed)" do
      mutation = """
      mutation UpdateClaim($id: ID!, $input: UpdateClaimInput!) {
        updateClaim(id: $id, input: $input) { id text }
      }
      """

      {:ok, result} =
        run_query(
          mutation,
          %{"id" => "claim_auth_test_1", "input" => %{"text" => "Updated claim text by editor with proper authorization"}},
          authed_context(@editor_id)
        )

      refute Map.has_key?(result, :errors)
      assert %{data: %{"updateClaim" => %{"id" => "claim_auth_test_1"}}} = result
    end

    test "editor cannot delete a claim (lacks :delete)" do
      mutation = """
      mutation DeleteClaim($id: ID!) {
        deleteClaim(id: $id)
      }
      """

      {:ok, result} =
        run_query(mutation, %{"id" => "claim_auth_test_1"}, authed_context(@editor_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "editor cannot grant access (lacks :manage)" do
      mutation = """
      mutation GrantAccess($input: GrantAccessInput!) {
        grantAccess(input: $input) { id }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "userId" => "some_user",
        "role" => "VIEWER"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@editor_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "editor cannot archive investigation (lacks :manage)" do
      mutation = """
      mutation ArchiveInvestigation($id: ID!) {
        archiveInvestigation(id: $id) { id }
      }
      """

      {:ok, result} =
        run_query(mutation, %{"id" => @investigation_id}, authed_context(@editor_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end
  end

  describe "permission levels — owner has all permissions" do
    test "owner can query claims" do
      query = """
      query ListClaims($invId: String!) {
        claims(investigationId: $invId) { id text }
      }
      """

      {:ok, result} =
        run_query(query, %{"invId" => @investigation_id}, authed_context(@owner_id))

      refute Map.has_key?(result, :errors)
    end

    test "owner can create a claim (:edit)" do
      mutation = """
      mutation CreateClaim($input: CreateClaimInput!) {
        createClaim(input: $input) { id text }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "text" => "Owner creating a claim for the investigation they own",
        "claimType" => "PRIMARY"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@owner_id))

      refute Map.has_key?(result, :errors)

      if claim_id = get_in(result, [:data, "createClaim", "id"]) do
        cleanup_arango_docs("claims", [claim_id])
      end
    end

    test "owner can delete a claim (:delete)" do
      # Seed a disposable claim for this test
      seed_claim("claim_auth_delete_test", @investigation_id)

      mutation = """
      mutation DeleteClaim($id: ID!) {
        deleteClaim(id: $id)
      }
      """

      {:ok, result} =
        run_query(mutation, %{"id" => "claim_auth_delete_test"}, authed_context(@owner_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"deleteClaim" => true}} = result
    end

    test "owner can grant access (:manage)" do
      mutation = """
      mutation GrantAccess($input: GrantAccessInput!) {
        grantAccess(input: $input) { id userId role }
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "userId" => "user_newly_granted",
        "role" => "VIEWER"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@owner_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"grantAccess" => %{"userId" => "user_newly_granted", "role" => "viewer"}}} = result

      # Clean up the extra grant
      Authorization.revoke_access(@investigation_id, "user_newly_granted")
    end

    test "owner can revoke access (:manage)" do
      # Grant a temporary collaborator to revoke
      Authorization.grant_access(@investigation_id, "user_to_revoke", :viewer)

      mutation = """
      mutation RevokeAccess($input: RevokeAccessInput!) {
        revokeAccess(input: $input)
      }
      """

      input = %{
        "investigationId" => @investigation_id,
        "userId" => "user_to_revoke"
      }

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(@owner_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"revokeAccess" => true}} = result
    end

    test "owner can update an investigation (:edit)" do
      mutation = """
      mutation UpdateInvestigation($id: ID!, $input: UpdateInvestigationInput!) {
        updateInvestigation(id: $id, input: $input) { id title }
      }
      """

      {:ok, result} =
        run_query(
          mutation,
          %{"id" => @investigation_id, "input" => %{"title" => "Updated by Owner"}},
          authed_context(@owner_id)
        )

      refute Map.has_key?(result, :errors)
      assert %{data: %{"updateInvestigation" => %{"title" => "Updated by Owner"}}} = result
    end
  end

  # ===========================================================================
  # 5. Record-by-ID lookups check parent investigation
  # ===========================================================================

  describe "record-by-ID lookups enforce investigation access" do
    test "claim lookup by ID checks the parent investigation" do
      query = """
      query GetClaim($id: ID!) {
        claim(id: $id) { id investigationId }
      }
      """

      # Outsider has access to @other_investigation_id but not @investigation_id
      # The claim belongs to @investigation_id
      {:ok, result} =
        run_query(query, %{"id" => "claim_auth_test_1"}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "evidence lookup by ID checks the parent investigation" do
      query = """
      query GetEvidence($id: ID!) {
        evidence(id: $id) { id title investigationId }
      }
      """

      {:ok, result} =
        run_query(query, %{"id" => "ev_auth_test_1"}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "update claim by ID checks the parent investigation (not the requesting user's)" do
      mutation = """
      mutation UpdateClaim($id: ID!, $input: UpdateClaimInput!) {
        updateClaim(id: $id, input: $input) { id text }
      }
      """

      {:ok, result} =
        run_query(
          mutation,
          %{"id" => "claim_auth_test_1", "input" => %{"text" => "Outsider should not be able to update this claim"}},
          authed_context(@outsider_id)
        )

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "delete claim by ID checks the parent investigation" do
      mutation = """
      mutation DeleteClaim($id: ID!) {
        deleteClaim(id: $id)
      }
      """

      {:ok, result} =
        run_query(mutation, %{"id" => "claim_auth_test_1"}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end

    test "investigation_stats by ID checks access" do
      query = """
      query InvestigationStats($id: ID!) {
        investigationStats(id: $id) { claimCount evidenceCount }
      }
      """

      {:ok, result} =
        run_query(query, %{"id" => @investigation_id}, authed_context(@outsider_id))

      assert %{errors: [%{message: message}]} = result
      assert message =~ "forbidden"
    end
  end

  # ===========================================================================
  # 6. Create investigation grants owner to creator
  # ===========================================================================

  describe "create investigation auto-grants owner" do
    test "any authenticated user can create an investigation and becomes owner" do
      mutation = """
      mutation CreateInvestigation($input: CreateInvestigationInput!) {
        createInvestigation(input: $input) { id title }
      }
      """

      input = %{
        "title" => "Brand New Investigation for Auth Test",
        "description" => "Created to verify owner auto-grant"
      }

      new_user_id = "user_brand_new_#{System.unique_integer([:positive])}"

      {:ok, result} = run_query(mutation, %{"input" => input}, authed_context(new_user_id))

      refute Map.has_key?(result, :errors)
      assert %{data: %{"createInvestigation" => %{"id" => inv_id, "title" => title}}} = result
      assert title == "Brand New Investigation for Auth Test"

      # Verify the creator was auto-granted :owner
      assert {:ok, :owner} = Authorization.get_user_role(inv_id, new_user_id)

      # Clean up
      cleanup_access_grants([inv_id])
      cleanup_arango_docs("investigations", [inv_id])
    end
  end
end
