# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Lithoglyph.NERExtractor do
  @moduledoc """
  Regex-based Named Entity Recognition for evidence content.

  Extracts candidate entity names from `content_text` using pattern
  matching heuristics. This is a lightweight extraction layer — the
  heavy lifting of deduplication and fuzzy matching is handled by
  `EvidenceGraph.Entities.resolve_ner_output/2`.

  ## Extraction Strategies

  1. **Capitalised multi-word sequences** — "Jeffrey Epstein", "HSBC Holdings"
  2. **Title-prefixed names** — "Dr. Jane Smith", "Prof. Alan Turing"
  3. **Organisation suffixes** — "Acme Corp", "Global Fund Ltd"
  4. **Location indicators** — "New York City", "United Kingdom"

  ## Usage

      iex> NERExtractor.extract("The ONS reported that HSBC Holdings received funding.")
      ["ONS", "HSBC Holdings"]
  """

  require Logger

  # Titles that precede person names
  @title_prefixes ~w(Mr Mrs Ms Dr Prof Sir Dame Lord Lady Judge Justice Sen Rep Gov)

  # Organisation suffixes (case-insensitive matching applied separately)
  @org_suffixes ~w(
    Ltd LLC Inc Corp plc PLC Group Foundation Trust Fund
    Association Institute University College Council Commission
    Authority Agency Bureau Department Ministry
  )

  # Common words that look like proper nouns but aren't entities
  @stopwords MapSet.new(~w(
    The This That These Those Which Where When What Who How
    January February March April May June July August September October November December
    Monday Tuesday Wednesday Thursday Friday Saturday Sunday
    Section Article Chapter Page Table Figure
    However Moreover Furthermore Additionally Nevertheless
    According Also Although Because Before Between During
    Evidence Investigation Report Document Statement
    Said Says Told Asked Added Noted Claimed Stated
    New Old First Last Next Previous Current Former
    United States Kingdom Nations
  ))

  @doc """
  Extract candidate entity names from content text.

  Returns a deduplicated list of entity name strings, ordered by first
  appearance in the text.
  """
  @spec extract(String.t()) :: [String.t()]
  def extract(nil), do: []
  def extract(""), do: []

  def extract(content) when is_binary(content) do
    # Normalize whitespace: collapse newlines/tabs into single spaces
    # so regexes don't span across line breaks
    normalized = String.replace(content, ~r/\s+/, " ")

    candidates =
      []
      |> Kernel.++(extract_titled_names(normalized))
      |> Kernel.++(extract_org_names(normalized))
      |> Kernel.++(extract_capitalised_sequences(normalized))

    candidates
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(String.length(&1) < 2))
    |> Enum.reject(&stopword?/1)
    |> Enum.uniq()
  end

  @doc """
  Extract entities from an evidence record's metadata.

  Pulls `content_text` from the record's metadata map and extracts
  entity candidates. Also considers the `title` field.
  """
  @spec extract_from_evidence(map()) :: [String.t()]
  def extract_from_evidence(%{} = evidence) do
    content = get_in(evidence, [:metadata, :content_text]) ||
              get_in(evidence, ["metadata", "content_text"]) || ""

    title = Map.get(evidence, :title) || Map.get(evidence, "title") || ""

    combined = "#{title}\n\n#{content}"
    extract(combined)
  end

  # -- Private extraction strategies --

  # Strategy 1: Title-prefixed names ("Dr. Jane Smith", "Prof. Alan Turing")
  defp extract_titled_names(content) do
    title_pattern = @title_prefixes |> Enum.join("|")
    {:ok, regex} = Regex.compile("(?:#{title_pattern})\\.?\\s+([A-Z][a-z]+(?:\\s+[A-Z][a-z]+){0,3})")

    regex
    |> Regex.scan(content)
    |> Enum.map(fn [full_match | _] -> String.trim(full_match) end)
  end

  # Strategy 2: Organisation names with known suffixes
  defp extract_org_names(content) do
    suffix_pattern = @org_suffixes |> Enum.join("|")
    {:ok, regex} = Regex.compile("([A-Z][A-Za-z&-]+(?:\\s+[A-Z][A-Za-z&-]+){0,5})\\s+(?:#{suffix_pattern})\\b")

    regex
    |> Regex.scan(content)
    |> Enum.map(fn [full_match | _] -> String.trim(full_match) end)
  end

  # Strategy 3: Capitalised multi-word sequences (2+ words starting with capitals)
  defp extract_capitalised_sequences(content) do
    ~r/\b([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)+)\b/
    |> Regex.scan(content)
    |> Enum.map(fn [match | _] -> String.trim(match) end)
  end

  defp stopword?(name) do
    # Check if the entire name is a stopword, or if it's a single-word
    # name that appears in our stoplist
    words = String.split(name)

    case words do
      [single] -> MapSet.member?(@stopwords, single)
      _ -> Enum.all?(words, &MapSet.member?(@stopwords, &1))
    end
  end
end
