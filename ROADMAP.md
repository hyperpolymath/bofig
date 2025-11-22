# Evidence Graph Implementation Roadmap

## 18-Month Plan: Three Phases

### Philosophy: Progressive Enhancement Over Big Bang

Start simple, validate with users, grow based on real needs. Each phase delivers working software.

---

## Phase 1: Proof of Concept (Months 1-6)

**Goal:** One complete investigation with user testing

### Month 1: Foundation
- [x] Architecture documentation
- [x] Technology stack selection
- [ ] Development environment setup
  - Elixir/Phoenix project initialized
  - ArangoDB local instance (Podman)
  - GraphQL API skeleton
- [ ] Core data models implemented
  - Claims, Evidence, Relationships
  - Basic PROMPT scores (no UI yet)
- [ ] First commit to `main` branch

**Deliverables:**
- Working GraphQL API
- ArangoDB schema created
- Sample data loaded (UK Inflation 2023)

**Hours:** ~80 hours (2 weeks full-time)

### Month 2: Zotero Integration
- [ ] Extend `lib/exporter.js` to POST to API
- [ ] API endpoint: `/api/v1/evidence/import`
- [ ] Metadata mapping: Zotero → Evidence schema
- [ ] Dublin Core / Schema.org preservation
- [ ] Two-way sync: Evidence → Zotero JSON export
- [ ] Test with 30 real Zotero items

**Deliverables:**
- Roundtrip Zotero integration working
- 30 evidence items imported
- Metadata preserved in JSON-LD

**Hours:** ~60 hours

### Month 3: Basic UI + DECISION POINT
- [ ] Phoenix LiveView setup
- [ ] Evidence list view (table with sorting)
- [ ] Claim creation form
- [ ] Basic relationship creation (dropdowns)
- [ ] D3.js graph visualization (read-only)
- [ ] **USER TESTING SESSION 1:**
  - 5 NUJ journalists
  - Task: "Map 3 claims to existing evidence"
  - Collect feedback on UI/UX

**DECISION POINT:** Continue or pivot based on user feedback

**Deliverables:**
- Working web UI (no PROMPT scoring yet)
- User testing report
- Go/No-Go decision documented

**Hours:** ~100 hours

### Month 4: PROMPT Scoring System
- [ ] PROMPT scoring UI (6 sliders: 0-100)
- [ ] Overall score calculation (weighted average)
- [ ] Score visualization (radar charts)
- [ ] Audience-weighted scoring algorithm
- [ ] Julia integration for statistical analysis
- [ ] Make scoring **optional** (adoption friction)

**Deliverables:**
- PROMPT UI complete
- Scoring algorithms tested
- Documentation: "Why these 6 dimensions?"

**Hours:** ~70 hours

### Month 5: Navigation Paths
- [ ] Navigation path data model
- [ ] 6 audience types implemented
- [ ] Path creation UI (drag-and-drop interface)
- [ ] Path playback: linear story mode
- [ ] Graph highlighting during path playback
- [ ] Test with 3 navigation paths on UK Inflation investigation

**Deliverables:**
- 3 working navigation paths
- Path creation/playback UI
- Audience type documentation

**Hours:** ~80 hours

### Month 6: Polish + User Testing
- [ ] Progressive enhancement audit (works without JS?)
- [ ] Performance optimization (query benchmarks)
- [ ] Complete UK Inflation investigation:
  - 7 claims
  - 30 evidence items
  - 3 navigation paths
- [ ] **USER TESTING SESSION 2:**
  - 25 NUJ participants
  - Mixed roles: investigative reporters, editors, researchers
  - Tasks: Navigate paths, assess PROMPT scores, find evidence
  - Qualitative interviews

**Deliverables:**
- Production-ready PoC
- User testing report (25 participants)
- Phase 1 retrospective document
- Public demo at NUJ event

**Hours:** ~90 hours

**Phase 1 Total:** ~480 hours (3 months full-time equivalent)

---

## Phase 2: Platform (Months 7-12)

**Goal:** Multi-investigation platform ready for newsrooms

### Month 7: Multi-User System
- [ ] Authentication (JWT, role-based access)
- [ ] User management (admin, journalist, reviewer, reader)
- [ ] Investigation ownership & collaboration
- [ ] Audit logs for all mutations
- [ ] Real-time collaboration (LiveView + Phoenix PubSub)
- [ ] Conflict resolution for concurrent edits

**Deliverables:**
- Multi-user authentication
- 3 test users with different roles
- Collaboration tested on shared investigation

**Hours:** ~80 hours

### Month 8: Advanced Graph Features
- [ ] Weighted relationship propagation
- [ ] Pathfinding algorithms (shortest path, highest confidence)
- [ ] Evidence chain traversal (depth-first, breadth-first)
- [ ] Contradiction detection (auto-highlight conflicts)
- [ ] Materialized paths for performance
- [ ] Graph layout algorithms (force-directed, hierarchical)

**Deliverables:**
- Advanced graph queries working
- Contradiction detector tested
- Performance: 10-hop chain in <1s

**Hours:** ~90 hours

### Month 9: IPFS Provenance
- [ ] IPFS node setup (Kubo)
- [ ] Evidence upload → IPFS hash generation
- [ ] Hash storage in Evidence records
- [ ] Verification: compare current hash to stored
- [ ] Tamper detection warnings
- [ ] Optional: IPFS gateway for public access

**Deliverables:**
- IPFS integration complete
- Provenance verification working
- Documentation: "Why IPFS?"

**Hours:** ~60 hours

### Month 10: Import/Export Ecosystem
- [ ] Export formats:
  - JSON (full investigation)
  - CSV (claims + evidence table)
  - GraphML (for Gephi/Cytoscape)
  - Markdown (human-readable report)
  - PDF (via Typst/LaTeX)
- [ ] Import from:
  - CSV (claims list)
  - BibTeX (academic citations)
  - Other evidence graphs (migration tool)
- [ ] API for external tools (e.g., R, Python)

**Deliverables:**
- 5 export formats working
- Import from CSV/BibTeX
- Python client library (basic)

**Hours:** ~70 hours

### Month 11: Production Deployment
- [ ] Hetzner Cloud setup (Debian 12 VPS)
- [ ] ArangoDB Cloud instance (€45/month)
- [ ] Nginx reverse proxy + SSL
- [ ] Automated backups (daily)
- [ ] Monitoring (Phoenix LiveDashboard, Prometheus)
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Staging environment

**Deliverables:**
- Production instance live at evidencegraph.org
- Uptime monitoring configured
- Backup restoration tested

**Hours:** ~50 hours

### Month 12: Real Investigation + Launch
- [ ] Partner with investigative team for real story
- [ ] Support during active investigation (bug fixes, features)
- [ ] Document workflow: "How we used Evidence Graph"
- [ ] Public launch:
  - Blog post announcement
  - NUJ newsletter feature
  - Academic paper submission (CHI/CSCW)
- [ ] Open source repository public
- [ ] User documentation complete

**Deliverables:**
- 1 published investigation using platform
- Public launch event
- Academic paper draft
- 50+ GitHub stars

**Hours:** ~80 hours

**Phase 2 Total:** ~430 hours (2.5 months full-time equivalent)

---

## Phase 3: Ecosystem (Months 13-18)

**Goal:** Integration with academic/journalism infrastructure

### Month 13-14: Semantic Web Integration
- [ ] Evaluate Virtuoso need (based on Phase 2 usage)
- [ ] If needed: Virtuoso setup + RDF export
- [ ] SPARQL endpoint for cross-investigation queries
- [ ] Linked Open Data publishing
- [ ] Integration with:
  - ORCID (researcher identifiers)
  - DOI (document identifiers)
  - Wikidata (entity linking)

**Deliverables:**
- SPARQL endpoint (if needed)
- Wikidata entity linking demo
- Academic repository integration

**Hours:** ~100 hours

### Month 15: Advanced Analytics
- [ ] Julia statistical analysis pipeline
- [ ] Network analysis:
  - Centrality measures (which evidence is most critical?)
  - Community detection (clusters of related claims)
  - Influence propagation
- [ ] PROMPT score evolution over time
- [ ] Bias detection (are we cherry-picking evidence?)
- [ ] Automated suggestions: "You might be missing..."

**Deliverables:**
- Analytics dashboard
- Bias detection alerts
- Network analysis visualizations

**Hours:** ~90 hours

### Month 16: Mobile & Accessibility
- [ ] Responsive design audit
- [ ] Mobile web optimization
- [ ] Accessibility (WCAG 2.1 AA):
  - Screen reader support
  - Keyboard navigation
  - Color contrast
- [ ] Progressive Web App (PWA):
  - Offline mode
  - Install to home screen
- [ ] Performance: < 3s load on 3G

**Deliverables:**
- WCAG 2.1 AA compliance
- PWA installable
- Mobile user testing (10 participants)

**Hours:** ~70 hours

### Month 17: Plugin Ecosystem
- [ ] Plugin API design
- [ ] Example plugins:
  - Sentiment analysis (evidence tone)
  - Named entity recognition (auto-tagging)
  - Fact-checking API integration (ClaimBuster)
  - Translation (multilingual investigations)
- [ ] Plugin marketplace (basic)
- [ ] Developer documentation

**Deliverables:**
- 4 working plugins
- Plugin developer guide
- 3rd-party plugin submitted

**Hours:** ~80 hours

### Month 18: Sustainability & Handoff
- [ ] Business model evaluation:
  - Freemium (free for individuals, paid for newsrooms)?
  - Grant funding (Mozilla, Knight Foundation)?
  - Academic partnerships?
- [ ] Community governance structure
- [ ] Contributor guidelines
- [ ] Roadmap for Year 2
- [ ] Project retrospective

**Deliverables:**
- Sustainability plan
- Community governance docs
- Year 1 retrospective report
- Year 2 roadmap

**Hours:** ~60 hours

**Phase 3 Total:** ~400 hours (2 months full-time equivalent)

---

## Total Timeline Summary

| Phase | Duration | Effort | Key Milestone |
|-------|----------|--------|---------------|
| Phase 1: PoC | Months 1-6 | 480 hours | User testing (25 participants) |
| Phase 2: Platform | Months 7-12 | 430 hours | Real investigation published |
| Phase 3: Ecosystem | Months 13-18 | 400 hours | Plugin ecosystem live |
| **Total** | **18 months** | **1,310 hours** | **Sustainable open-source project** |

**Full-time equivalent:** ~7.8 months (1,310 hours ÷ 168 hours/month)

---

## Risk Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| ArangoDB doesn't scale | Medium | High | Benchmark in Month 3; switch to PostgreSQL + AgensGraph if needed |
| PROMPT scoring too complex | High | Medium | Make optional, simplify to 3 dimensions if adoption low |
| Zotero API changes | Low | Medium | Version API calls, maintain fallback to manual import |
| IPFS performance issues | Medium | Low | Make IPFS optional, use traditional file storage as backup |

### User Adoption Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Journalists don't see value | Medium | High | **Month 3 decision point** - pivot if testing fails |
| Too steep learning curve | High | Medium | Video tutorials, in-app onboarding, progressive disclosure |
| Existing tools "good enough" | Medium | High | Focus on unique value: navigation paths + PROMPT scores |

### Sustainability Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Can't fund hosting after grants | High | Medium | Design for self-hosting, keep costs <€100/month |
| Maintainer burnout | Medium | High | Build community early, document everything, find co-maintainers |
| Academic interest fades | Low | Low | Focus on journalism use case, academic integration is bonus |

---

## Success Metrics

### Phase 1 (PoC)
- ✅ 25 user testing participants recruited
- ✅ 80%+ say "I would use this" (qualitative)
- ✅ 1 complete investigation (7 claims, 30 evidence)
- ✅ All 3 navigation paths rated "useful" or higher

### Phase 2 (Platform)
- ✅ 1 published investigation using platform
- ✅ 3+ newsrooms express interest
- ✅ <500ms average page load time
- ✅ 100+ GitHub stars
- ✅ Academic paper accepted to CHI/CSCW/Computation+Journalism

### Phase 3 (Ecosystem)
- ✅ 10+ active users (monthly)
- ✅ 5+ investigations published
- ✅ 3+ community plugins created
- ✅ 1+ academic citation
- ✅ Sustainability plan funded for Year 2

---

## Decision Points

### Month 3: Go/No-Go
**Question:** Do journalists find this useful?
**Data:** User testing qualitative feedback
**Options:**
1. **Go:** Proceed to Month 4-6
2. **Pivot:** Simplify to Zotero export only (lightweight tool)
3. **Stop:** Document learnings, archive project

### Month 9: Architecture Review
**Question:** Is ArangoDB still the right choice?
**Data:** Performance benchmarks, query complexity, cost
**Options:**
1. **Keep ArangoDB:** Optimize queries, upgrade tier if needed
2. **Migrate:** Switch to PostgreSQL + AgensGraph + full-text search

### Month 12: Semantic Web Decision
**Question:** Do we need Virtuoso/RDF?
**Data:** User requests for academic integration, cross-investigation queries
**Options:**
1. **Add Virtuoso:** Phase 3 semantic web integration
2. **Skip:** JSON-LD export sufficient, avoid complexity

---

## Parallel Tracks

Some work can happen concurrently:

### Research Track (ongoing)
- Academic literature review (i-docs, boundary objects)
- PROMPT framework refinement
- User interviews with investigative journalists

### Community Track (Month 3+)
- Blog posts documenting development
- NUJ presentations
- Conference submissions (Computation+Journalism, NICAR)

### Documentation Track (Month 1+)
- Developer docs (this repo)
- User guides (separate repo)
- Video tutorials (Phase 2)

---

## Resources Needed

### Human Resources
- **Primary developer:** 0.5 FTE for 18 months (you!)
- **UX designer:** 0.1 FTE (Months 3, 6, 12) - contract work
- **Test users:** NUJ network (volunteer)
- **Code reviewers:** Open source community

### Infrastructure Costs
- **ArangoDB Cloud:** €45/month × 12 months = €540
- **Hetzner VPS:** €10/month × 12 months = €120
- **Domain:** €15/year
- **IPFS Pinning (Pinata):** €20/month × 12 months = €240
- **Total Year 1:** ~€915 (~$1,000 USD)

### Funding Sources
- **Mozilla MOSS:** $10k-50k (open source support)
- **Knight Foundation:** $50k-250k (journalism innovation)
- **EU Horizon:** €50k-500k (research projects)
- **NUJ grant:** £5k-10k (membership innovation)

---

## Post-18-Month Vision

### Year 2+
- **Federated instances:** University A + Newsroom B share evidence via ActivityPub
- **AI integration:** Auto-PROMPT scoring via LLMs (with human oversight)
- **Blockchain provenance:** DIDs + verifiable credentials
- **Real-time collaboration:** Google Docs-style editing
- **Mobile native app:** iOS/Android (if web isn't enough)

### Long-term North Star
**"The GitHub for epistemology"** - where investigations are forked, evidence is pull-requested, and claims are peer-reviewed.

---

**Last Updated:** 2025-11-22
**Next Review:** Month 3 (Decision Point)
**Owner:** @Hyperpolymath
