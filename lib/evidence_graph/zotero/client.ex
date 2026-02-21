# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraph.Zotero.Client do
  @moduledoc """
  Tesla-based client for the Zotero Web API v3.

  Supports both user and group libraries. Authentication is via
  `Zotero-API-Key` header. All responses include `Last-Modified-Version`
  for conflict detection.

  ## Configuration

      config :evidence_graph, EvidenceGraph.Zotero.Client,
        api_key: "your-zotero-api-key",
        user_id: "12345",
        library_type: :user  # or :group
  """

  use Tesla

  @base_url "https://api.zotero.org"

  plug Tesla.Middleware.BaseUrl, @base_url
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Headers, [{"zotero-api-version", "3"}]
  plug Tesla.Middleware.Retry, delay: 1_000, max_retries: 3

  @doc """
  Build a client with the configured API key.
  """
  def new(opts \\ []) do
    config = Application.get_env(:evidence_graph, __MODULE__, [])
    api_key = Keyword.get(opts, :api_key, config[:api_key])

    Tesla.client([
      {Tesla.Middleware.Headers, [{"zotero-api-key", api_key}]}
    ])
  end

  @doc """
  Get a single item by key.

  ## Examples

      iex> get_item(client, "ABC123")
      {:ok, %{"key" => "ABC123", "data" => %{...}}}
  """
  def get_item(client \\ new(), item_key) do
    path = library_path() <> "/items/#{item_key}"

    case get(client, path) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: 404}} ->
        {:error, :not_found}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:transport_error, reason}}
    end
  end

  @doc """
  List items in the library, with optional pagination and filtering.

  ## Options

    * `:limit` - Max items per request (default 100, max 100)
    * `:start` - Offset for pagination (default 0)
    * `:since` - Only items modified after this library version
    * `:item_type` - Filter by Zotero item type
    * `:sort` - Sort field (default "dateModified")
    * `:direction` - Sort direction, "asc" or "desc" (default "desc")
  """
  def list_items(client \\ new(), opts \\ []) do
    path = library_path() <> "/items"

    query =
      [
        limit: Keyword.get(opts, :limit, 100),
        start: Keyword.get(opts, :start, 0),
        sort: Keyword.get(opts, :sort, "dateModified"),
        direction: Keyword.get(opts, :direction, "desc")
      ]
      |> maybe_put(:since, Keyword.get(opts, :since))
      |> maybe_put(:itemType, Keyword.get(opts, :item_type))

    case get(client, path, query: query) do
      {:ok, %Tesla.Env{status: 200, body: body, headers: headers}} ->
        total = get_header(headers, "total-results")
        version = get_header(headers, "last-modified-version")
        {:ok, %{items: body, total: parse_int(total), library_version: parse_int(version)}}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:transport_error, reason}}
    end
  end

  @doc """
  Create a new item in the Zotero library.
  """
  def create_item(client \\ new(), item_data) do
    path = library_path() <> "/items"

    case post(client, path, [item_data]) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        case body do
          %{"successful" => %{"0" => created}} -> {:ok, created}
          %{"failed" => %{"0" => error}} -> {:error, {:creation_failed, error}}
          _ -> {:error, {:unexpected_response, body}}
        end

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:transport_error, reason}}
    end
  end

  @doc """
  Update an existing item. Requires the item's current version for
  conflict detection via `If-Unmodified-Since-Version` header.
  """
  def update_item(client \\ new(), item_key, item_data, version) do
    path = library_path() <> "/items/#{item_key}"

    headers_client =
      Tesla.client([
        {Tesla.Middleware.Headers,
         [
           {"zotero-api-key", get_api_key()},
           {"if-unmodified-since-version", to_string(version)}
         ]}
      ])

    case patch(headers_client, path, item_data) do
      {:ok, %Tesla.Env{status: 204}} ->
        :ok

      {:ok, %Tesla.Env{status: 412}} ->
        {:error, :conflict}

      {:ok, %Tesla.Env{status: 404}} ->
        {:error, :not_found}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:transport_error, reason}}
    end
  end

  @doc """
  Delete an item by key. Requires current version for conflict detection.
  """
  def delete_item(client \\ new(), item_key, version) do
    path = library_path() <> "/items/#{item_key}"

    headers_client =
      Tesla.client([
        {Tesla.Middleware.Headers,
         [
           {"zotero-api-key", get_api_key()},
           {"if-unmodified-since-version", to_string(version)}
         ]}
      ])

    case delete(headers_client, path) do
      {:ok, %Tesla.Env{status: 204}} ->
        :ok

      {:ok, %Tesla.Env{status: 412}} ->
        {:error, :conflict}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:transport_error, reason}}
    end
  end

  @doc """
  Get the current library version (for incremental sync).
  """
  def library_version(client \\ new()) do
    path = library_path() <> "/items"

    case get(client, path, query: [limit: 0, format: "versions"]) do
      {:ok, %Tesla.Env{status: 200, headers: headers}} ->
        version = get_header(headers, "last-modified-version")
        {:ok, parse_int(version)}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:transport_error, reason}}
    end
  end

  @doc """
  Get items modified since a given library version (for incremental sync).
  Returns all items across paginated responses.
  """
  def items_since(client \\ new(), since_version) do
    fetch_all_pages(client, since_version, 0, [])
  end

  # -- Private helpers --

  defp fetch_all_pages(client, since_version, start, acc) do
    case list_items(client, since: since_version, start: start, limit: 100) do
      {:ok, %{items: items, total: total, library_version: lib_ver}} ->
        all = acc ++ items
        fetched = start + length(items)

        if fetched < total do
          fetch_all_pages(client, since_version, fetched, all)
        else
          {:ok, %{items: all, library_version: lib_ver}}
        end

      error ->
        error
    end
  end

  defp library_path do
    config = Application.get_env(:evidence_graph, __MODULE__, [])
    library_type = config[:library_type] || :user
    library_id = config[:user_id]

    case library_type do
      :user -> "/users/#{library_id}"
      :group -> "/groups/#{library_id}"
    end
  end

  defp get_api_key do
    config = Application.get_env(:evidence_graph, __MODULE__, [])
    config[:api_key]
  end

  defp get_header(headers, name) do
    case List.keyfind(headers, name, 0) do
      {_, value} -> value
      nil -> nil
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(str) when is_binary(str), do: String.to_integer(str)
  defp parse_int(n) when is_integer(n), do: n

  defp maybe_put(keyword, _key, nil), do: keyword
  defp maybe_put(keyword, key, value), do: Keyword.put(keyword, key, value)
end
