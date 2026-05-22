# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.IPFS do
  @moduledoc """
  IPFS Pinning integration for the Evidence Graph.

  Pins evidence files to IPFS for content-addressable, tamper-evident storage.
  Uses the Req HTTP client to communicate with an IPFS HTTP API endpoint
  (Kubo/go-ipfs compatible).

  ## Configuration

  Set the IPFS API endpoint in your application config:

      config :evidence_graph, EvidenceGraph.IPFS,
        api_url: "http://localhost:5001",
        timeout: 30_000

  Or via environment variable `IPFS_API_URL`.
  """

  alias EvidenceGraph.ArangoDB

  @doc """
  Pin an evidence item's file to IPFS.

  Reads the file from the evidence item's `local_path`, adds it to IPFS,
  and stores the resulting CID in the evidence document's `ipfs_hash` field.

  ## Returns

  `{:ok, %{cid: string, evidence_id: string}}` or `{:error, reason}`
  """
  def pin_evidence(evidence_id) do
    with {:ok, evidence} <- ArangoDB.get("evidence", evidence_id),
         local_path when is_binary(local_path) <- evidence["local_path"],
         true <- File.exists?(local_path),
         {:ok, cid} <- add_to_ipfs(local_path),
         :ok <- pin_hash(cid),
         {:ok, _updated} <-
           ArangoDB.update("evidence", evidence_id, %{
             ipfs_hash: cid,
             updated_at: DateTime.to_iso8601(DateTime.utc_now())
           }) do
      {:ok, %{cid: cid, evidence_id: evidence_id}}
    else
      nil ->
        {:error, :no_local_path}

      false ->
        {:error, :file_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Verify that an evidence item's IPFS pin is still active and the content hash
  matches the stored SHA-256 hash (if available).

  ## Returns

  `{:ok, %{pinned: boolean, cid: string, hash_match: boolean | nil}}`
  """
  def verify_pin(evidence_id) do
    with {:ok, evidence} <- ArangoDB.get("evidence", evidence_id) do
      cid = evidence["ipfs_hash"]

      if is_nil(cid) or cid == "" do
        {:ok, %{pinned: false, cid: nil, hash_match: nil}}
      else
        case check_pin_status(cid) do
          {:ok, pinned} ->
            # If we have both a local file and stored SHA-256, verify integrity
            hash_match =
              if evidence["local_path"] && evidence["sha256_hash"] do
                verify_file_hash(evidence["local_path"], evidence["sha256_hash"])
              else
                nil
              end

            {:ok, %{pinned: pinned, cid: cid, hash_match: hash_match}}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  @doc """
  Remove an IPFS pin for an evidence item.

  Unpins the content from the local IPFS node and clears the `ipfs_hash`
  field on the evidence document.

  ## Returns

  `:ok` or `{:error, reason}`
  """
  def unpin_evidence(evidence_id) do
    with {:ok, evidence} <- ArangoDB.get("evidence", evidence_id) do
      cid = evidence["ipfs_hash"]

      if is_nil(cid) or cid == "" do
        :ok
      else
        with :ok <- unpin_hash(cid),
             {:ok, _updated} <-
               ArangoDB.update("evidence", evidence_id, %{
                 ipfs_hash: nil,
                 updated_at: DateTime.to_iso8601(DateTime.utc_now())
               }) do
          :ok
        end
      end
    end
  end

  @doc """
  Pin all evidence items for an investigation that have a `local_path` but
  no `ipfs_hash` yet.

  Returns a summary of the batch operation.

  ## Returns

  `{:ok, %{total: integer, pinned: integer, failed: integer, errors: [map]}}`
  """
  def batch_pin(investigation_id) do
    aql = """
    FOR ev IN evidence
      FILTER ev.investigation_id == @investigation_id
      FILTER ev.local_path != null AND ev.local_path != ""
      FILTER ev.ipfs_hash == null OR ev.ipfs_hash == ""
      RETURN ev._key
    """

    case ArangoDB.query_read(aql, %{investigation_id: investigation_id}) do
      {:ok, evidence_ids} ->
        results =
          Enum.map(evidence_ids, fn eid ->
            case pin_evidence(eid) do
              {:ok, result} -> {:ok, result}
              {:error, reason} -> {:error, %{evidence_id: eid, reason: inspect(reason)}}
            end
          end)

        {successes, failures} =
          Enum.split_with(results, fn
            {:ok, _} -> true
            {:error, _} -> false
          end)

        errors = Enum.map(failures, fn {:error, e} -> e end)

        {:ok,
         %{
           total: length(evidence_ids),
           pinned: length(successes),
           failed: length(failures),
           errors: errors
         }}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — IPFS HTTP API calls
  # ---------------------------------------------------------------------------

  defp api_url do
    config = Application.get_env(:evidence_graph, __MODULE__, [])
    Keyword.get(config, :api_url, System.get_env("IPFS_API_URL", "http://localhost:5001"))
  end

  defp timeout do
    config = Application.get_env(:evidence_graph, __MODULE__, [])
    Keyword.get(config, :timeout, 30_000)
  end

  # Add a file to IPFS and return its CID.
  defp add_to_ipfs(file_path) do
    url = "#{api_url()}/api/v0/add"
    file_content = File.read!(file_path)
    filename = Path.basename(file_path)

    multipart =
      Req.new(
        url: url,
        method: :post,
        body:
          {:multipart,
           [
             {:file, file_content,
              {"form-data", [{"name", "file"}, {"filename", filename}]},
              [{"content-type", "application/octet-stream"}]}
           ]},
        receive_timeout: timeout()
      )

    case Req.request(multipart) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        cid = body["Hash"]

        if cid do
          {:ok, cid}
        else
          {:error, :no_cid_in_response}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:ipfs_error, status, body}}

      {:error, reason} ->
        {:error, {:ipfs_request_failed, reason}}
    end
  end

  # Pin a CID on the local IPFS node.
  defp pin_hash(cid) do
    url = "#{api_url()}/api/v0/pin/add?arg=#{cid}"

    case Req.post(url, receive_timeout: timeout()) do
      {:ok, %Req.Response{status: 200}} -> :ok
      {:ok, %Req.Response{status: status, body: body}} -> {:error, {:ipfs_pin_failed, status, body}}
      {:error, reason} -> {:error, {:ipfs_request_failed, reason}}
    end
  end

  # Check if a CID is pinned.
  defp check_pin_status(cid) do
    url = "#{api_url()}/api/v0/pin/ls?arg=#{cid}&type=all"

    case Req.post(url, receive_timeout: timeout()) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        keys = body["Keys"] || %{}
        {:ok, Map.has_key?(keys, cid)}

      {:ok, %Req.Response{status: 500, body: %{"Message" => msg}}} ->
        if String.contains?(msg, "is not pinned") do
          {:ok, false}
        else
          {:error, {:ipfs_error, 500, msg}}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:ipfs_error, status, body}}

      {:error, reason} ->
        {:error, {:ipfs_request_failed, reason}}
    end
  end

  # Unpin a CID from the local IPFS node.
  defp unpin_hash(cid) do
    url = "#{api_url()}/api/v0/pin/rm?arg=#{cid}"

    case Req.post(url, receive_timeout: timeout()) do
      {:ok, %Req.Response{status: 200}} -> :ok
      {:ok, %Req.Response{status: 500, body: %{"Message" => msg}}} ->
        if String.contains?(msg, "not pinned") do
          :ok
        else
          {:error, {:ipfs_unpin_failed, msg}}
        end
      {:ok, %Req.Response{status: status, body: body}} -> {:error, {:ipfs_unpin_failed, status, body}}
      {:error, reason} -> {:error, {:ipfs_request_failed, reason}}
    end
  end

  # Verify a file's SHA-256 hash matches the expected value.
  defp verify_file_hash(file_path, expected_hash) do
    if File.exists?(file_path) do
      actual_hash =
        File.stream!(file_path, 65_536)
        |> Enum.reduce(:crypto.hash_init(:sha256), fn chunk, acc ->
          :crypto.hash_update(acc, chunk)
        end)
        |> :crypto.hash_final()
        |> Base.encode16(case: :lower)

      actual_hash == String.downcase(expected_hash)
    else
      nil
    end
  end
end
