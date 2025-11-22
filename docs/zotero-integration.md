# Zotero Integration Design

## Overview

Two-way sync between Zotero and Evidence Graph:
- **Export:** Zotero items → Evidence Graph (via modified extension)
- **Import:** Evidence Graph → Zotero (via API + manual)
- **Metadata:** Preserve Dublin Core, Schema.org, custom fields

## Architecture

```
┌─────────────────┐          ┌──────────────────┐         ┌─────────────────┐
│  Zotero Client  │          │  Evidence Graph  │         │   ArangoDB      │
│                 │          │     Phoenix API   │         │                 │
│  ┌───────────┐  │          │                  │         │  ┌───────────┐  │
│  │ Items     │  │          │  POST /api/v1/   │         │  │ evidence  │  │
│  │ (papers,  │──┼─export──▶│  evidence/import │────────▶│  │ collection│  │
│  │  data,    │  │          │                  │         │  └───────────┘  │
│  │  etc.)    │  │          │  GET /api/v1/    │         │                 │
│  └───────────┘  │          │  evidence/:id/   │         │                 │
│       ▲         │          │  export          │         │                 │
│       │         │          └──────────────────┘         └─────────────────┘
│       │         │                    │
│  ┌────┴──────┐  │                    │
│  │ Modified  │  │◀────import─────────┘
│  │ exporter. │  │    (manual: download JSON,
│  │ js plugin │  │     import to Zotero)
│  └───────────┘  │
└─────────────────┘
```

## Zotero → Evidence Graph Export

### Modified Extension: `lib/exporter.js`

The existing bofig repository contains an old Zotero→Voyant export plugin. We'll extend it to POST to Evidence Graph API.

#### Original Plugin Structure (2017)
```
lib/
├── exporter.js          # Main export logic
├── translators/
│   └── voyant.js        # Voyant-specific translator
└── chrome/
    └── content/
        └── overlay.xul  # Firefox UI overlay
```

#### New Structure (2025+)
```
lib/
├── exporter.js          # Extended with Evidence Graph POST
├── translators/
│   ├── voyant.js        # Keep legacy support
│   └── evidencegraph.js # NEW: Evidence Graph translator
├── config.js            # NEW: API endpoint configuration
└── chrome/
    └── content/
        ├── overlay.xul  # Updated for modern Zotero
        └── prompt.xhtml # NEW: PROMPT scoring dialog
```

### Code: `lib/translators/evidencegraph.js`

```javascript
/**
 * Evidence Graph Translator
 * Exports Zotero items to Evidence Graph API
 */

const EvidenceGraphTranslator = {
  async exportItem(item, investigationId, apiEndpoint, apiKey) {
    const evidence = this.mapZoteroToEvidence(item, investigationId);

    // POST to Evidence Graph API
    const response = await fetch(`${apiEndpoint}/api/v1/evidence/import`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify(evidence)
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.statusText}`);
    }

    const result = await response.json();

    // Store Evidence Graph ID in Zotero item metadata
    item.setField('extra', `evidence_graph_id: ${result.data.id}`);
    await item.saveTx();

    return result.data;
  },

  mapZoteroToEvidence(item, investigationId) {
    const itemType = this.mapItemType(item.itemType);
    const dublinCore = this.extractDublinCore(item);
    const schemaOrg = this.extractSchemaOrg(item);

    return {
      investigation_id: investigationId,
      title: item.getField('title'),
      evidence_type: itemType,
      source_url: item.getField('url') || null,
      zotero_key: item.key,
      zotero_version: item.version,
      dublin_core: dublinCore,
      schema_org: schemaOrg,
      prompt_scores: {
        // Default scores (user can update in Evidence Graph UI)
        provenance: this.inferProvenance(item),
        replicability: 50,
        objective: 50,
        methodology: this.inferMethodology(item),
        publication: this.inferPublication(item),
        transparency: 50
      },
      tags: item.getTags().map(t => t.tag),
      metadata: {
        zotero_library_id: item.libraryID,
        zotero_collections: this.getCollections(item),
        attachments: this.getAttachments(item),
        notes: this.getNotes(item)
      }
    };
  },

  mapItemType(zoteroType) {
    const typeMap = {
      'journalArticle': 'document',
      'book': 'document',
      'bookSection': 'document',
      'conferencePaper': 'document',
      'report': 'document',
      'thesis': 'document',
      'webpage': 'document',
      'interview': 'interview',
      'dataset': 'dataset',
      'audioRecording': 'media',
      'videoRecording': 'media',
      'podcast': 'media',
      'artwork': 'media'
    };
    return typeMap[zoteroType] || 'other';
  },

  extractDublinCore(item) {
    return {
      title: item.getField('title'),
      creator: this.getCreators(item),
      subject: item.getTags().map(t => t.tag).join('; '),
      description: item.getField('abstractNote') || null,
      publisher: item.getField('publisher') || null,
      date: item.getField('date') || null,
      type: item.itemType,
      format: item.getField('format') || null,
      identifier: this.getIdentifiers(item),
      source: item.getField('libraryCatalog') || null,
      language: item.getField('language') || null,
      relation: item.getField('relations') || null,
      rights: item.getField('rights') || null
    };
  },

  extractSchemaOrg(item) {
    return {
      '@context': 'https://schema.org',
      '@type': this.mapSchemaOrgType(item.itemType),
      '@id': item.getField('DOI') ? `https://doi.org/${item.getField('DOI')}` : null,
      'name': item.getField('title'),
      'author': this.getCreators(item).map(name => ({
        '@type': 'Person',
        'name': name
      })),
      'datePublished': item.getField('date'),
      'publisher': item.getField('publisher') ? {
        '@type': 'Organization',
        'name': item.getField('publisher')
      } : null,
      'url': item.getField('url'),
      'identifier': this.getIdentifiers(item)
    };
  },

  mapSchemaOrgType(zoteroType) {
    const schemaMap = {
      'journalArticle': 'ScholarlyArticle',
      'book': 'Book',
      'dataset': 'Dataset',
      'interview': 'Interview',
      'videoRecording': 'VideoObject',
      'audioRecording': 'AudioObject',
      'webpage': 'WebPage'
    };
    return schemaMap[zoteroType] || 'CreativeWork';
  },

  getCreators(item) {
    return item.getCreators().map(creator => {
      if (creator.firstName && creator.lastName) {
        return `${creator.firstName} ${creator.lastName}`;
      }
      return creator.name || '';
    });
  },

  getIdentifiers(item) {
    const identifiers = [];
    const doi = item.getField('DOI');
    const isbn = item.getField('ISBN');
    const issn = item.getField('ISSN');
    const url = item.getField('url');

    if (doi) identifiers.push(`DOI:${doi}`);
    if (isbn) identifiers.push(`ISBN:${isbn}`);
    if (issn) identifiers.push(`ISSN:${issn}`);
    if (url) identifiers.push(`URL:${url}`);

    return identifiers.join('; ');
  },

  getCollections(item) {
    const collections = item.getCollections();
    return collections.map(colID => {
      const col = Zotero.Collections.get(colID);
      return col ? col.name : null;
    }).filter(Boolean);
  },

  getAttachments(item) {
    return item.getAttachments().map(attachID => {
      const attach = Zotero.Items.get(attachID);
      return {
        title: attach.getField('title'),
        path: attach.getFilePath(),
        mimeType: attach.getField('contentType'),
        url: attach.getField('url')
      };
    });
  },

  getNotes(item) {
    return item.getNotes().map(noteID => {
      const note = Zotero.Items.get(noteID);
      return note.getNote();
    });
  },

  // Infer PROMPT scores from Zotero metadata
  inferProvenance(item) {
    let score = 50; // Default

    // High-quality publishers
    const publisher = item.getField('publisher') || '';
    const highQualityPublishers = [
      'Oxford University Press',
      'Cambridge University Press',
      'Nature Publishing Group',
      'Elsevier',
      'Springer'
    ];
    if (highQualityPublishers.some(p => publisher.includes(p))) {
      score += 30;
    }

    // Has DOI (peer-reviewed likely)
    if (item.getField('DOI')) {
      score += 20;
    }

    // Government/official source
    const source = item.getField('libraryCatalog') || '';
    if (source.includes('gov') || source.includes('Official')) {
      score += 20;
    }

    return Math.min(score, 100);
  },

  inferMethodology(item) {
    let score = 50;

    // Has methodology keywords in abstract
    const abstract = item.getField('abstractNote') || '';
    const methodologyKeywords = [
      'methodology', 'methods', 'randomized', 'controlled',
      'sample size', 'statistical', 'regression'
    ];
    const keywordCount = methodologyKeywords.filter(k =>
      abstract.toLowerCase().includes(k)
    ).length;
    score += keywordCount * 10;

    return Math.min(score, 100);
  },

  inferPublication(item) {
    let score = 50;

    // Peer-reviewed journal
    if (item.itemType === 'journalArticle' && item.getField('DOI')) {
      score += 40;
    }

    // Has publication date
    if (item.getField('date')) {
      score += 10;
    }

    return Math.min(score, 100);
  }
};

if (typeof module !== 'undefined') {
  module.exports = EvidenceGraphTranslator;
}
```

### Code: `lib/chrome/content/prompt.xhtml`

PROMPT scoring dialog shown before export:

```xml
<?xml version="1.0"?>
<?xml-stylesheet href="chrome://global/skin/" type="text/css"?>

<dialog id="evidence-graph-prompt-dialog"
        title="PROMPT Scoring"
        xmlns="http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul"
        buttons="accept,cancel"
        ondialogaccept="return PromptDialog.accept();"
        style="width: 600px; height: 500px;">

  <script src="prompt.js"/>

  <vbox flex="1" style="padding: 20px;">
    <description style="margin-bottom: 20px;">
      Rate this evidence on six epistemological dimensions (0-100):
    </description>

    <!-- Provenance -->
    <hbox align="center" style="margin-bottom: 15px;">
      <label value="Provenance:" style="width: 150px;"/>
      <scale id="provenance-slider" min="0" max="100" increment="5" flex="1"/>
      <label id="provenance-value" value="50" style="width: 40px; text-align: right;"/>
    </hbox>
    <description style="margin-left: 150px; margin-bottom: 10px; font-size: 0.9em; color: gray;">
      Source credibility and authority
    </description>

    <!-- Replicability -->
    <hbox align="center" style="margin-bottom: 15px;">
      <label value="Replicability:" style="width: 150px;"/>
      <scale id="replicability-slider" min="0" max="100" increment="5" flex="1"/>
      <label id="replicability-value" value="50" style="width: 40px; text-align: right;"/>
    </hbox>
    <description style="margin-left: 150px; margin-bottom: 10px; font-size: 0.9em; color: gray;">
      Can others verify this?
    </description>

    <!-- Objective/Operational -->
    <hbox align="center" style="margin-bottom: 15px;">
      <label value="Objective:" style="width: 150px;"/>
      <scale id="objective-slider" min="0" max="100" increment="5" flex="1"/>
      <label id="objective-value" value="50" style="width: 40px; text-align: right;"/>
    </hbox>
    <description style="margin-left: 150px; margin-bottom: 10px; font-size: 0.9em; color: gray;">
      Clear operational definitions
    </description>

    <!-- Methodology -->
    <hbox align="center" style="margin-bottom: 15px;">
      <label value="Methodology:" style="width: 150px;"/>
      <scale id="methodology-slider" min="0" max="100" increment="5" flex="1"/>
      <label id="methodology-value" value="50" style="width: 40px; text-align: right;"/>
    </hbox>
    <description style="margin-left: 150px; margin-bottom: 10px; font-size: 0.9em; color: gray;">
      Research quality and rigor
    </description>

    <!-- Publication -->
    <hbox align="center" style="margin-bottom: 15px;">
      <label value="Publication:" style="width: 150px;"/>
      <scale id="publication-slider" min="0" max="100" increment="5" flex="1"/>
      <label id="publication-value" value="50" style="width: 40px; text-align: right;"/>
    </hbox>
    <description style="margin-left: 150px; margin-bottom: 10px; font-size: 0.9em; color: gray;">
      Peer review and venue quality
    </description>

    <!-- Transparency -->
    <hbox align="center" style="margin-bottom: 15px;">
      <label value="Transparency:" style="width: 150px;"/>
      <scale id="transparency-slider" min="0" max="100" increment="5" flex="1"/>
      <label id="transparency-value" value="50" style="width: 40px; text-align: right;"/>
    </hbox>
    <description style="margin-left: 150px; margin-bottom: 10px; font-size: 0.9em; color: gray;">
      Open data and methods
    </description>

    <!-- Overall Score -->
    <separator style="margin-top: 20px;"/>
    <hbox align="center" style="margin-top: 10px;">
      <label value="Overall Score:" style="font-weight: bold; width: 150px;"/>
      <label id="overall-score" value="50.0" style="font-weight: bold; font-size: 1.2em;"/>
    </hbox>
  </vbox>
</dialog>
```

### Code: `lib/config.js`

User configuration for API endpoint:

```javascript
const EvidenceGraphConfig = {
  getApiEndpoint() {
    return Zotero.Prefs.get('extensions.evidencegraph.apiEndpoint') ||
           'https://api.evidencegraph.org';
  },

  setApiEndpoint(endpoint) {
    Zotero.Prefs.set('extensions.evidencegraph.apiEndpoint', endpoint);
  },

  getApiKey() {
    return Zotero.Prefs.get('extensions.evidencegraph.apiKey') || '';
  },

  setApiKey(key) {
    Zotero.Prefs.set('extensions.evidencegraph.apiKey', key);
  },

  getDefaultInvestigation() {
    return Zotero.Prefs.get('extensions.evidencegraph.defaultInvestigation') || null;
  },

  setDefaultInvestigation(id) {
    Zotero.Prefs.set('extensions.evidencegraph.defaultInvestigation', id);
  },

  promptForScores() {
    return Zotero.Prefs.get('extensions.evidencegraph.promptForScores') !== false;
  }
};
```

## Evidence Graph → Zotero Import

### API Endpoint: `/api/v1/evidence/:id/export`

```elixir
# lib/evidence_graph_web/controllers/evidence_controller.ex

defmodule EvidenceGraphWeb.EvidenceController do
  use EvidenceGraphWeb, :controller

  def export(conn, %{"id" => id}) do
    evidence = EvidenceGraph.get_evidence!(id)
    zotero_json = to_zotero_format(evidence)

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition",
         "attachment; filename=\"#{evidence.zotero_key || id}.json\"")
    |> json(zotero_json)
  end

  defp to_zotero_format(evidence) do
    %{
      key: evidence.zotero_key || generate_zotero_key(),
      version: evidence.metadata["zotero_version"] || 0,
      itemType: map_evidence_type_to_zotero(evidence.evidence_type),
      title: evidence.title,
      url: evidence.source_url,
      tags: Enum.map(evidence.tags, &%{tag: &1}),
      # Dublin Core → Zotero fields
      creators: parse_creators(evidence.dublin_core["creator"]),
      date: evidence.dublin_core["date"],
      publisher: evidence.dublin_core["publisher"],
      abstractNote: evidence.dublin_core["description"],
      language: evidence.dublin_core["language"],
      rights: evidence.dublin_core["rights"],
      # Custom fields
      extra: build_extra_field(evidence)
    }
  end

  defp build_extra_field(evidence) do
    """
    evidence_graph_id: #{evidence.id}
    PROMPT Scores:
    - Provenance: #{evidence.prompt_scores.provenance}/100
    - Replicability: #{evidence.prompt_scores.replicability}/100
    - Objective: #{evidence.prompt_scores.objective}/100
    - Methodology: #{evidence.prompt_scores.methodology}/100
    - Publication: #{evidence.prompt_scores.publication}/100
    - Transparency: #{evidence.prompt_scores.transparency}/100
    Overall: #{calculate_overall(evidence.prompt_scores)}/100
    """
  end

  defp map_evidence_type_to_zotero(type) do
    case type do
      :document -> "journalArticle"  # Default
      :dataset -> "dataset"
      :interview -> "interview"
      :media -> "audioRecording"
      _ -> "webpage"
    end
  end
end
```

### Manual Import Workflow

1. User clicks "Export to Zotero" in Evidence Graph UI
2. Browser downloads `evidence_123.json`
3. User opens Zotero → File → Import → Select JSON file
4. Zotero creates new item with metadata + PROMPT scores in "Extra" field

## Sync Strategy

### Conflict Resolution

**Scenario:** User updates item in both Zotero AND Evidence Graph

**Solution:** Last-write-wins with version tracking

```elixir
defmodule EvidenceGraph.Sync do
  def sync_from_zotero(evidence_id, zotero_item) do
    evidence = get_evidence!(evidence_id)

    cond do
      # Zotero version newer → update Evidence Graph
      zotero_item.version > evidence.metadata["zotero_version"] ->
        update_from_zotero(evidence, zotero_item)

      # Evidence Graph newer → skip (user must manually export)
      evidence.updated_at > zotero_item.dateModified ->
        {:error, :evidence_graph_newer}

      # Same version → no action
      true ->
        {:ok, :up_to_date}
    end
  end
end
```

### Webhook Support (Future)

Zotero doesn't support webhooks, but we can poll:

```elixir
# Run every 15 minutes via Oban job
defmodule EvidenceGraph.Workers.ZoteroSync do
  use Oban.Worker, queue: :sync

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Get all evidence with zotero_key
    evidence_with_keys = list_evidence_with_zotero_keys()

    Enum.each(evidence_with_keys, fn evidence ->
      # Fetch from Zotero API
      case Zotero.API.get_item(evidence.zotero_key) do
        {:ok, zotero_item} ->
          Sync.sync_from_zotero(evidence.id, zotero_item)
        {:error, _} ->
          # Item deleted in Zotero? Mark as unsynced
          mark_sync_failed(evidence)
      end
    end)

    :ok
  end
end
```

## Testing Plan

### Unit Tests

```elixir
# test/evidence_graph/zotero_test.exs

defmodule EvidenceGraph.ZoteroTest do
  use EvidenceGraph.DataCase

  describe "to_zotero_format/1" do
    test "converts evidence to Zotero JSON" do
      evidence = %Evidence{
        title: "Test Paper",
        evidence_type: :document,
        source_url: "https://example.com/paper.pdf",
        dublin_core: %{
          "creator" => "John Doe; Jane Smith",
          "date" => "2023-01-15"
        }
      }

      zotero = EvidenceGraphWeb.EvidenceController.to_zotero_format(evidence)

      assert zotero.title == "Test Paper"
      assert zotero.itemType == "journalArticle"
      assert length(zotero.creators) == 2
    end
  end

  describe "from_zotero_format/1" do
    test "converts Zotero JSON to Evidence" do
      zotero_item = %{
        "key" => "ABC123",
        "itemType" => "journalArticle",
        "title" => "Test Paper",
        "url" => "https://example.com",
        "creators" => [
          %{"firstName" => "John", "lastName" => "Doe"}
        ]
      }

      evidence = EvidenceGraph.Importer.from_zotero(zotero_item, "inv_123")

      assert evidence.title == "Test Paper"
      assert evidence.zotero_key == "ABC123"
      assert evidence.evidence_type == :document
    end
  end
end
```

### Integration Tests

```elixir
# test/evidence_graph_web/controllers/evidence_controller_test.exs

defmodule EvidenceGraphWeb.EvidenceControllerTest do
  use EvidenceGraphWeb.ConnCase

  test "POST /api/v1/evidence/import creates evidence from Zotero", %{conn: conn} do
    zotero_json = %{
      "key" => "TEST123",
      "itemType" => "dataset",
      "title" => "UK Inflation Data",
      "tags" => [%{"tag" => "inflation"}]
    }

    conn = post(conn, "/api/v1/evidence/import", zotero_json)

    assert %{"data" => %{"id" => id}} = json_response(conn, 201)

    evidence = EvidenceGraph.get_evidence!(id)
    assert evidence.title == "UK Inflation Data"
    assert evidence.zotero_key == "TEST123"
    assert "inflation" in evidence.tags
  end

  test "GET /api/v1/evidence/:id/export returns Zotero JSON", %{conn: conn} do
    evidence = insert(:evidence, title: "Test Evidence")

    conn = get(conn, "/api/v1/evidence/#{evidence.id}/export")

    assert %{"title" => "Test Evidence"} = json_response(conn, 200)
    assert get_resp_header(conn, "content-disposition") != []
  end
end
```

## User Documentation

### Setup Guide

**1. Install Zotero Extension**
```bash
# Download from GitHub releases
curl -LO https://github.com/Hyperpolymath/bofig/releases/latest/bofig-evidencegraph.xpi

# In Zotero: Tools → Add-ons → Gear Icon → Install Add-on From File
```

**2. Configure API Endpoint**
```
Zotero → Edit → Preferences → Evidence Graph
- API Endpoint: https://api.evidencegraph.org
- API Key: [paste your key from Evidence Graph settings]
- Default Investigation: [select from dropdown]
```

**3. Export Items**
```
1. Select items in Zotero library
2. Right-click → Export to Evidence Graph
3. (Optional) Adjust PROMPT scores in dialog
4. Click "Export"
5. Items appear in Evidence Graph investigation
```

---

**Last Updated:** 2025-11-22
**Status:** Design complete, implementation pending
