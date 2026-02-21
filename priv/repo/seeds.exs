# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
# UK Inflation 2023 Investigation - Test Dataset
# Phase 1 Goal: 7 claims, 30 evidence items, 6 navigation paths

alias EvidenceGraph.{Claims, Evidence, Relationships, Navigation}

IO.puts("Seeding UK Inflation 2023 investigation...")

# Investigation metadata (stored in ArangoDB investigations collection)
investigation_id = "uk_inflation_2023"

# Setup database collections
IO.puts("Setting up ArangoDB collections...")
EvidenceGraph.ArangoDB.setup_database()

#
# CLAIMS (7 total)
#

IO.puts("Creating claims...")

{:ok, claim_1} =
  Claims.create_claim(%{
    investigation_id: investigation_id,
    text: "UK inflation reached a 40-year high of 11.1% in October 2022",
    claim_type: :primary,
    confidence_level: 0.98,
    prompt_scores: %{
      provenance: 95,
      replicability: 100,
      objective: 95,
      methodology: 90,
      publication: 100,
      transparency: 95
    },
    created_by: "sarah.johnson@investigativeunit.uk"
  })

{:ok, claim_2} =
  Claims.create_claim(%{
    investigation_id: investigation_id,
    text: "Energy price cap increase was the primary driver of the inflation spike",
    claim_type: :supporting,
    confidence_level: 0.85,
    prompt_scores: %{
      provenance: 80,
      replicability: 75,
      objective: 70,
      methodology: 80,
      publication: 85,
      transparency: 75
    },
    created_by: "sarah.johnson@investigativeunit.uk"
  })

{:ok, claim_3} =
  Claims.create_claim(%{
    investigation_id: investigation_id,
    text: "Food price inflation exceeded 15% by early 2023, driven by supply chain disruptions",
    claim_type: :supporting,
    confidence_level: 0.90,
    prompt_scores: %{
      provenance: 85,
      replicability: 85,
      objective: 80,
      methodology: 85,
      publication: 90,
      transparency: 80
    },
    created_by: "sarah.johnson@investigativeunit.uk"
  })

{:ok, claim_4} =
  Claims.create_claim(%{
    investigation_id: investigation_id,
    text: "Bank of England interest rate increases failed to curb inflation in 2022",
    claim_type: :primary,
    confidence_level: 0.75,
    prompt_scores: %{
      provenance: 70,
      replicability: 60,
      objective: 65,
      methodology: 70,
      publication: 75,
      transparency: 70
    },
    created_by: "sarah.johnson@investigativeunit.uk"
  })

{:ok, claim_5} =
  Claims.create_claim(%{
    investigation_id: investigation_id,
    text: "Real wages declined by 3.1% year-on-year in Q4 2022",
    claim_type: :primary,
    confidence_level: 0.92,
    prompt_scores: %{
      provenance: 90,
      replicability: 95,
      objective: 90,
      methodology: 88,
      publication: 95,
      transparency: 90
    },
    created_by: "sarah.johnson@investigativeunit.uk"
  })

{:ok, claim_6} =
  Claims.create_claim(%{
    investigation_id: investigation_id,
    text: "Low-income households were disproportionately affected by inflation",
    claim_type: :supporting,
    confidence_level: 0.88,
    prompt_scores: %{
      provenance: 75,
      replicability: 70,
      objective: 65,
      methodology: 75,
      publication: 80,
      transparency: 70
    },
    created_by: "sarah.johnson@investigativeunit.uk"
  })

{:ok, claim_7} =
  Claims.create_claim(%{
    investigation_id: investigation_id,
    text: "Government cost-of-living support package was insufficient to offset inflation impact",
    claim_type: :counter,
    confidence_level: 0.70,
    prompt_scores: %{
      provenance: 60,
      replicability: 55,
      objective: 50,
      methodology: 60,
      publication: 65,
      transparency: 60
    },
    created_by: "sarah.johnson@investigativeunit.uk"
  })

IO.puts("Created #{7} claims")

#
# EVIDENCE (30 total)
#

IO.puts("Creating evidence...")

# ============================================================================
# Official statistics (high PROMPT scores) - Evidence 1-5
# ============================================================================

{:ok, evidence_1} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Consumer Price Index (CPI) - October 2022",
    evidence_type: :dataset,
    source_url: "https://www.ons.gov.uk/economy/inflationandpriceindices/bulletins/consumerpriceinflation/october2022",
    zotero_key: "ONS_CPI_OCT2022",
    dublin_core: %{
      "creator" => "Office for National Statistics",
      "date" => "2022-11-16",
      "publisher" => "ONS",
      "type" => "Statistical Bulletin"
    },
    prompt_scores: %{
      provenance: 100,
      replicability: 100,
      objective: 95,
      methodology: 95,
      publication: 100,
      transparency: 95
    },
    tags: ["inflation", "cpi", "official-statistics", "uk"]
  })

{:ok, evidence_2} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Ofgem Energy Price Cap Announcement - Q4 2022",
    evidence_type: :document,
    source_url: "https://www.ofgem.gov.uk/publications/price-cap-increase-october-2022",
    zotero_key: "OFGEM_PRICECAP_Q42022",
    dublin_core: %{
      "creator" => "Office of Gas and Electricity Markets",
      "date" => "2022-08-26",
      "publisher" => "Ofgem",
      "type" => "Press Release"
    },
    prompt_scores: %{
      provenance: 95,
      replicability: 90,
      objective: 85,
      methodology: 80,
      publication: 90,
      transparency: 85
    },
    tags: ["energy", "price-cap", "ofgem", "uk"]
  })

{:ok, evidence_3} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Food Price Inflation Data - ONS",
    evidence_type: :dataset,
    source_url: "https://www.ons.gov.uk/economy/inflationandpriceindices/datasets/foodpriceindices",
    zotero_key: "ONS_FOOD_2023",
    dublin_core: %{
      "creator" => "Office for National Statistics",
      "date" => "2023-02-15",
      "publisher" => "ONS"
    },
    prompt_scores: %{
      provenance: 100,
      replicability: 100,
      objective: 95,
      methodology: 95,
      publication: 100,
      transparency: 95
    },
    tags: ["food-prices", "inflation", "official-statistics"]
  })

{:ok, evidence_4} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Bank of England Monetary Policy Report - November 2022",
    evidence_type: :document,
    source_url: "https://www.bankofengland.co.uk/monetary-policy-report/2022/november-2022",
    zotero_key: "BOE_MPR_NOV2022",
    dublin_core: %{
      "creator" => "Bank of England",
      "date" => "2022-11-03",
      "publisher" => "Bank of England"
    },
    prompt_scores: %{
      provenance: 95,
      replicability: 85,
      objective: 80,
      methodology: 85,
      publication: 95,
      transparency: 80
    },
    tags: ["monetary-policy", "bank-of-england", "interest-rates"]
  })

{:ok, evidence_5} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Average Weekly Earnings - Q4 2022",
    evidence_type: :dataset,
    source_url: "https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/earningsandworkinghours",
    zotero_key: "ONS_AWE_Q42022",
    dublin_core: %{
      "creator" => "Office for National Statistics",
      "date" => "2023-01-17",
      "publisher" => "ONS"
    },
    prompt_scores: %{
      provenance: 100,
      replicability: 100,
      objective: 95,
      methodology: 95,
      publication: 100,
      transparency: 95
    },
    tags: ["wages", "earnings", "official-statistics"]
  })

# ============================================================================
# Academic research (medium-high PROMPT scores) - Evidence 6-7
# ============================================================================

{:ok, evidence_6} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Distributional Impact of UK Inflation 2022-2023",
    evidence_type: :document,
    source_url: "https://doi.org/10.1111/example.12345",
    zotero_key: "SMITH_DIST_2023",
    dublin_core: %{
      "creator" => "Smith, J.; Jones, A.",
      "date" => "2023-03-10",
      "publisher" => "Economic Policy Review",
      "type" => "Peer-reviewed Article"
    },
    prompt_scores: %{
      provenance: 85,
      replicability: 80,
      objective: 75,
      methodology: 85,
      publication: 90,
      transparency: 75
    },
    tags: ["inequality", "distributional-effects", "peer-reviewed"]
  })

{:ok, evidence_7} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Energy Market Dynamics and Consumer Impact Study",
    evidence_type: :document,
    source_url: "https://doi.org/10.1016/example.2023",
    zotero_key: "BROWN_ENERGY_2023",
    dublin_core: %{
      "creator" => "Brown, T.; Wilson, R.",
      "date" => "2023-01-20",
      "publisher" => "Energy Economics Journal"
    },
    prompt_scores: %{
      provenance: 80,
      replicability: 75,
      objective: 70,
      methodology: 80,
      publication: 85,
      transparency: 70
    },
    tags: ["energy-markets", "peer-reviewed", "consumer-impact"]
  })

# ============================================================================
# Think tank reports (medium PROMPT scores) - Evidence 8-9
# ============================================================================

{:ok, evidence_8} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Resolution Foundation: Living Standards Crisis Report",
    evidence_type: :document,
    source_url: "https://www.resolutionfoundation.org/publications/living-standards-crisis",
    zotero_key: "RF_LIVING_2022",
    dublin_core: %{
      "creator" => "Resolution Foundation",
      "date" => "2022-12-05",
      "publisher" => "Resolution Foundation"
    },
    prompt_scores: %{
      provenance: 75,
      replicability: 70,
      objective: 65,
      methodology: 75,
      publication: 80,
      transparency: 70
    },
    tags: ["think-tank", "living-standards", "inequality"]
  })

{:ok, evidence_9} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Institute for Fiscal Studies: Autumn Statement Analysis",
    evidence_type: :document,
    source_url: "https://ifs.org.uk/publications/autumn-statement-2022-analysis",
    zotero_key: "IFS_AUTUMN_2022",
    dublin_core: %{
      "creator" => "Institute for Fiscal Studies",
      "date" => "2022-11-17",
      "publisher" => "IFS"
    },
    prompt_scores: %{
      provenance: 80,
      replicability: 75,
      objective: 70,
      methodology: 80,
      publication: 85,
      transparency: 75
    },
    tags: ["fiscal-policy", "think-tank", "government-support"]
  })

# ============================================================================
# Interviews (lower replicability, varying PROMPT scores) - Evidence 10
# ============================================================================

{:ok, evidence_10} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Interview: Prof. Sarah Mitchell, Economics LSE",
    evidence_type: :interview,
    dublin_core: %{
      "creator" => "Mitchell, Sarah (interviewee); Johnson, S. (interviewer)",
      "date" => "2023-01-15",
      "description" => "Expert interview on inflation drivers"
    },
    prompt_scores: %{
      provenance: 85,
      replicability: 45,
      objective: 60,
      methodology: 50,
      publication: 40,
      transparency: 75
    },
    tags: ["interview", "expert-opinion", "economics"]
  })

# ============================================================================
# Additional ONS datasets - Evidence 11-14
# ============================================================================

{:ok, evidence_11} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Consumer Prices Index including Owner Occupiers' Housing Costs (CPIH) - Q4 2022",
    evidence_type: :dataset,
    source_url: "https://www.ons.gov.uk/economy/inflationandpriceindices/bulletins/consumerpriceinflation/december2022",
    zotero_key: "ONS_CPIH_Q42022",
    dublin_core: %{
      "creator" => "Office for National Statistics",
      "date" => "2023-01-18",
      "publisher" => "ONS",
      "type" => "Statistical Bulletin"
    },
    prompt_scores: %{
      provenance: 100,
      replicability: 100,
      objective: 95,
      methodology: 95,
      publication: 100,
      transparency: 95
    },
    tags: ["inflation", "cpih", "housing-costs", "official-statistics", "uk"]
  })

{:ok, evidence_12} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Retail Prices Index (RPI) Annual Summary 2022",
    evidence_type: :dataset,
    source_url: "https://www.ons.gov.uk/economy/inflationandpriceindices/timeseries/czbh/mm23",
    zotero_key: "ONS_RPI_2022",
    dublin_core: %{
      "creator" => "Office for National Statistics",
      "date" => "2023-02-15",
      "publisher" => "ONS",
      "type" => "Time Series Dataset"
    },
    prompt_scores: %{
      provenance: 100,
      replicability: 100,
      objective: 90,
      methodology: 85,
      publication: 100,
      transparency: 90
    },
    tags: ["inflation", "rpi", "official-statistics", "uk", "time-series"]
  })

{:ok, evidence_13} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Producer Price Inflation - December 2022",
    evidence_type: :dataset,
    source_url: "https://www.ons.gov.uk/economy/inflationandpriceindices/bulletins/producerpriceinflation/december2022",
    zotero_key: "ONS_PPI_DEC2022",
    dublin_core: %{
      "creator" => "Office for National Statistics",
      "date" => "2023-01-18",
      "publisher" => "ONS",
      "type" => "Statistical Bulletin"
    },
    prompt_scores: %{
      provenance: 100,
      replicability: 100,
      objective: 95,
      methodology: 95,
      publication: 100,
      transparency: 95
    },
    tags: ["producer-prices", "supply-chain", "official-statistics", "uk"]
  })

{:ok, evidence_14} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "UK Trade Statistics - Q4 2022",
    evidence_type: :dataset,
    source_url: "https://www.ons.gov.uk/economy/nationalaccounts/balanceofpayments/bulletins/uktrade/december2022",
    zotero_key: "ONS_TRADE_Q42022",
    dublin_core: %{
      "creator" => "Office for National Statistics",
      "date" => "2023-02-10",
      "publisher" => "ONS",
      "type" => "Statistical Bulletin"
    },
    prompt_scores: %{
      provenance: 100,
      replicability: 100,
      objective: 95,
      methodology: 90,
      publication: 100,
      transparency: 90
    },
    tags: ["trade", "imports", "supply-chain", "official-statistics", "uk"]
  })

# ============================================================================
# Academic papers - Evidence 15-18
# ============================================================================

{:ok, evidence_15} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Monetary Policy Transmission Lags in the Post-COVID UK Economy",
    evidence_type: :document,
    source_url: "https://doi.org/10.1093/ej/example.2023",
    zotero_key: "TAYLOR_TRANSMISSION_2023",
    dublin_core: %{
      "creator" => "Taylor, M.; Sheridan, K.",
      "date" => "2023-04-12",
      "publisher" => "The Economic Journal",
      "type" => "Peer-reviewed Article"
    },
    prompt_scores: %{
      provenance: 85,
      replicability: 80,
      objective: 80,
      methodology: 90,
      publication: 95,
      transparency: 80
    },
    tags: ["monetary-policy", "transmission-mechanism", "peer-reviewed", "interest-rates"]
  })

{:ok, evidence_16} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Food Supply Chain Disruptions and Consumer Price Pass-Through in the UK",
    evidence_type: :document,
    source_url: "https://doi.org/10.1080/example.2023.food",
    zotero_key: "CHEN_FOOD_SUPPLY_2023",
    dublin_core: %{
      "creator" => "Chen, L.; Patel, R.; Edwards, G.",
      "date" => "2023-02-28",
      "publisher" => "Journal of Agricultural Economics",
      "type" => "Peer-reviewed Article"
    },
    prompt_scores: %{
      provenance: 80,
      replicability: 75,
      objective: 80,
      methodology: 85,
      publication: 90,
      transparency: 75
    },
    tags: ["food-prices", "supply-chain", "peer-reviewed", "agriculture"]
  })

{:ok, evidence_17} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Greedflation or Supply Shock? Decomposing UK Corporate Margins 2021-2023",
    evidence_type: :document,
    source_url: "https://doi.org/10.1257/example.2023.greedflation",
    zotero_key: "WEBER_GREEDFLATION_2023",
    dublin_core: %{
      "creator" => "Weber, I.; Wasner, E.",
      "date" => "2023-05-15",
      "publisher" => "Cambridge Journal of Economics",
      "type" => "Peer-reviewed Article"
    },
    prompt_scores: %{
      provenance: 75,
      replicability: 70,
      objective: 60,
      methodology: 80,
      publication: 85,
      transparency: 70
    },
    tags: ["greedflation", "corporate-profits", "peer-reviewed", "price-setting"]
  })

{:ok, evidence_18} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Inflation Expectations and Household Decision-Making: UK Survey Evidence",
    evidence_type: :document,
    source_url: "https://doi.org/10.1111/example.2023.expectations",
    zotero_key: "HALDANE_EXPECTATIONS_2023",
    dublin_core: %{
      "creator" => "Haldane, A.; Madouros, V.",
      "date" => "2023-06-20",
      "publisher" => "Economica",
      "type" => "Peer-reviewed Article"
    },
    prompt_scores: %{
      provenance: 80,
      replicability: 70,
      objective: 75,
      methodology: 80,
      publication: 90,
      transparency: 75
    },
    tags: ["inflation-expectations", "household-behaviour", "peer-reviewed", "survey"]
  })

# ============================================================================
# Media investigations - Evidence 19-21
# ============================================================================

{:ok, evidence_19} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "BBC Panorama: The Real Cost of Living",
    evidence_type: :media,
    source_url: "https://www.bbc.co.uk/programmes/m001gx7t",
    zotero_key: "BBC_PANORAMA_COL_2022",
    dublin_core: %{
      "creator" => "BBC Panorama",
      "date" => "2022-11-28",
      "publisher" => "BBC",
      "type" => "Television Documentary"
    },
    prompt_scores: %{
      provenance: 70,
      replicability: 50,
      objective: 55,
      methodology: 60,
      publication: 90,
      transparency: 55
    },
    tags: ["media", "bbc", "cost-of-living", "documentary"]
  })

{:ok, evidence_20} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Guardian Investigation: Supermarket Profit Margins During the Food Price Crisis",
    evidence_type: :media,
    source_url: "https://www.theguardian.com/business/2023/mar/15/supermarket-profits-food-prices-investigation",
    zotero_key: "GUARDIAN_SUPERMARKETS_2023",
    dublin_core: %{
      "creator" => "Collinson, P.; Butler, S.",
      "date" => "2023-03-15",
      "publisher" => "The Guardian",
      "type" => "Investigative Article"
    },
    prompt_scores: %{
      provenance: 65,
      replicability: 55,
      objective: 50,
      methodology: 55,
      publication: 85,
      transparency: 60
    },
    tags: ["media", "guardian", "supermarkets", "food-prices", "corporate-profits"]
  })

{:ok, evidence_21} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Financial Times: How the Bank of England Lost Control of Inflation",
    evidence_type: :media,
    source_url: "https://www.ft.com/content/example-boe-inflation-2023",
    zotero_key: "FT_BOE_CONTROL_2023",
    dublin_core: %{
      "creator" => "Giles, C.; Stubbington, T.",
      "date" => "2023-02-20",
      "publisher" => "Financial Times",
      "type" => "Analysis"
    },
    prompt_scores: %{
      provenance: 70,
      replicability: 55,
      objective: 60,
      methodology: 65,
      publication: 90,
      transparency: 60
    },
    tags: ["media", "financial-times", "bank-of-england", "monetary-policy"]
  })

# ============================================================================
# NGO reports - Evidence 22-24
# ============================================================================

{:ok, evidence_22} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Joseph Rowntree Foundation: UK Poverty Report 2023",
    evidence_type: :document,
    source_url: "https://www.jrf.org.uk/report/uk-poverty-2023",
    zotero_key: "JRF_POVERTY_2023",
    dublin_core: %{
      "creator" => "Joseph Rowntree Foundation",
      "date" => "2023-01-25",
      "publisher" => "JRF",
      "type" => "Research Report"
    },
    prompt_scores: %{
      provenance: 75,
      replicability: 65,
      objective: 60,
      methodology: 70,
      publication: 85,
      transparency: 70
    },
    tags: ["ngo", "poverty", "inequality", "jrf", "cost-of-living"]
  })

{:ok, evidence_23} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Citizens Advice: Energy Debt Crisis - National Data Report",
    evidence_type: :document,
    source_url: "https://www.citizensadvice.org.uk/about-us/our-work/policy/policy-research-topics/energy-policy-research/energy-debt-crisis-2023",
    zotero_key: "CA_ENERGY_DEBT_2023",
    dublin_core: %{
      "creator" => "Citizens Advice",
      "date" => "2023-02-08",
      "publisher" => "Citizens Advice",
      "type" => "Policy Report"
    },
    prompt_scores: %{
      provenance: 70,
      replicability: 60,
      objective: 55,
      methodology: 65,
      publication: 80,
      transparency: 65
    },
    tags: ["ngo", "energy-debt", "citizens-advice", "fuel-poverty"]
  })

{:ok, evidence_24} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Trussell Trust: End of Year Statistics 2022-2023",
    evidence_type: :dataset,
    source_url: "https://www.trusselltrust.org/news-and-blog/latest-stats/end-year-stats-2022-23",
    zotero_key: "TRUSSELL_STATS_2023",
    dublin_core: %{
      "creator" => "Trussell Trust",
      "date" => "2023-04-26",
      "publisher" => "Trussell Trust",
      "type" => "Statistical Summary"
    },
    prompt_scores: %{
      provenance: 80,
      replicability: 85,
      objective: 70,
      methodology: 75,
      publication: 85,
      transparency: 80
    },
    tags: ["ngo", "food-banks", "trussell-trust", "poverty", "hunger"]
  })

# ============================================================================
# Government documents - Evidence 25-26
# ============================================================================

{:ok, evidence_25} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "HM Treasury: Cost of Living Support Factsheet - Autumn Statement 2022",
    evidence_type: :document,
    source_url: "https://www.gov.uk/government/publications/autumn-statement-2022-cost-of-living-support-factsheet",
    zotero_key: "HMT_COL_FACTSHEET_2022",
    dublin_core: %{
      "creator" => "HM Treasury",
      "date" => "2022-11-17",
      "publisher" => "HM Government",
      "type" => "Government Policy Document"
    },
    prompt_scores: %{
      provenance: 90,
      replicability: 80,
      objective: 55,
      methodology: 65,
      publication: 95,
      transparency: 60
    },
    tags: ["government", "hm-treasury", "cost-of-living", "fiscal-policy"]
  })

{:ok, evidence_26} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "DWP: Benefit Uprating Review - Response to Inflation",
    evidence_type: :document,
    source_url: "https://www.gov.uk/government/publications/benefit-uprating-2023",
    zotero_key: "DWP_UPRATING_2023",
    dublin_core: %{
      "creator" => "Department for Work and Pensions",
      "date" => "2022-11-17",
      "publisher" => "HM Government",
      "type" => "Policy Statement"
    },
    prompt_scores: %{
      provenance: 90,
      replicability: 80,
      objective: 50,
      methodology: 60,
      publication: 90,
      transparency: 55
    },
    tags: ["government", "dwp", "benefits", "social-security", "uprating"]
  })

# ============================================================================
# International comparisons - Evidence 27-28
# ============================================================================

{:ok, evidence_27} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Eurostat: HICP - Comparative Inflation Across EU and UK - 2022",
    evidence_type: :dataset,
    source_url: "https://ec.europa.eu/eurostat/databrowser/view/prc_hicp_manr/default/table",
    zotero_key: "EUROSTAT_HICP_2022",
    dublin_core: %{
      "creator" => "Eurostat",
      "date" => "2023-01-20",
      "publisher" => "European Commission",
      "type" => "Comparative Statistical Dataset"
    },
    prompt_scores: %{
      provenance: 95,
      replicability: 95,
      objective: 90,
      methodology: 90,
      publication: 95,
      transparency: 90
    },
    tags: ["international", "eurostat", "eu", "hicp", "comparative"]
  })

{:ok, evidence_28} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "IMF World Economic Outlook: Chapter on Advanced Economy Inflation - October 2022",
    evidence_type: :document,
    source_url: "https://www.imf.org/en/Publications/WEO/Issues/2022/10/11/world-economic-outlook-october-2022",
    zotero_key: "IMF_WEO_OCT2022",
    dublin_core: %{
      "creator" => "International Monetary Fund",
      "date" => "2022-10-11",
      "publisher" => "IMF",
      "type" => "Analytical Report"
    },
    prompt_scores: %{
      provenance: 90,
      replicability: 85,
      objective: 80,
      methodology: 90,
      publication: 95,
      transparency: 80
    },
    tags: ["international", "imf", "global-inflation", "advanced-economies"]
  })

# ============================================================================
# Expert interviews - Evidence 29
# ============================================================================

{:ok, evidence_29} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Interview: Dr. James Meadway, Former Economic Adviser to Shadow Chancellor",
    evidence_type: :interview,
    dublin_core: %{
      "creator" => "Meadway, James (interviewee); Johnson, S. (interviewer)",
      "date" => "2023-03-02",
      "description" => "Expert interview on fiscal policy response to inflation and greedflation thesis"
    },
    prompt_scores: %{
      provenance: 75,
      replicability: 40,
      objective: 50,
      methodology: 45,
      publication: 35,
      transparency: 70
    },
    tags: ["interview", "expert-opinion", "fiscal-policy", "greedflation"]
  })

# ============================================================================
# Whistleblower / leaked documents (lowest PROMPT scores) - Evidence 30
# ============================================================================

{:ok, evidence_30} =
  Evidence.create_evidence(%{
    investigation_id: investigation_id,
    title: "Leaked Internal Memo: Major UK Energy Supplier Pricing Strategy Review",
    evidence_type: :other,
    dublin_core: %{
      "creator" => "Anonymous (redacted energy company employee)",
      "date" => "2023-01-10",
      "description" => "Internal document suggesting energy suppliers anticipated price cap mechanics and adjusted wholesale hedging to maximise margin under the cap structure",
      "rights" => "Source protected under NUJ code of conduct"
    },
    prompt_scores: %{
      provenance: 30,
      replicability: 15,
      objective: 40,
      methodology: 20,
      publication: 10,
      transparency: 25
    },
    tags: ["leaked", "whistleblower", "energy-supplier", "pricing-strategy", "confidential"]
  })

IO.puts("Created 30 evidence items")

#
# RELATIONSHIPS (connecting claims to evidence, and cross-connections)
#

IO.puts("Creating relationships...")

# ============================================================================
# Original 10 relationships (claims to evidence)
# ============================================================================

# Claim 1 <- Evidence 1 (strong support)
{:ok, _rel_1} =
  Relationships.create_relationship(%{
    from_id: claim_1.id,
    from_type: :claim,
    to_id: evidence_1.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 1.0,
    confidence: 0.95,
    reasoning: "ONS CPI data directly confirms the 11.1% inflation figure for October 2022",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 2 <- Evidence 2 (strong support)
{:ok, _rel_2} =
  Relationships.create_relationship(%{
    from_id: claim_2.id,
    from_type: :claim,
    to_id: evidence_2.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.85,
    confidence: 0.90,
    reasoning: "Ofgem price cap data shows timing correlation with inflation spike",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 2 <- Evidence 7 (academic support)
{:ok, _rel_3} =
  Relationships.create_relationship(%{
    from_id: claim_2.id,
    from_type: :claim,
    to_id: evidence_7.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.75,
    confidence: 0.80,
    reasoning: "Academic study confirms energy markets as primary driver",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 3 <- Evidence 3
{:ok, _rel_4} =
  Relationships.create_relationship(%{
    from_id: claim_3.id,
    from_type: :claim,
    to_id: evidence_3.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.95,
    confidence: 0.92,
    reasoning: "ONS food price data confirms >15% inflation rate",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 4 <- Evidence 4 (contextual, not direct support)
{:ok, _rel_5} =
  Relationships.create_relationship(%{
    from_id: claim_4.id,
    from_type: :claim,
    to_id: evidence_4.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.60,
    confidence: 0.75,
    reasoning: "BoE report provides context on interest rate policy",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 5 <- Evidence 5
{:ok, _rel_6} =
  Relationships.create_relationship(%{
    from_id: claim_5.id,
    from_type: :claim,
    to_id: evidence_5.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.92,
    confidence: 0.94,
    reasoning: "AWE data confirms real wage decline figure",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 6 <- Evidence 6
{:ok, _rel_7} =
  Relationships.create_relationship(%{
    from_id: claim_6.id,
    from_type: :claim,
    to_id: evidence_6.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.80,
    confidence: 0.85,
    reasoning: "Academic research demonstrates distributional inequality",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 6 <- Evidence 8
{:ok, _rel_8} =
  Relationships.create_relationship(%{
    from_id: claim_6.id,
    from_type: :claim,
    to_id: evidence_8.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.75,
    confidence: 0.80,
    reasoning: "Resolution Foundation report corroborates inequality impact",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 7 <- Evidence 9 (weak contradiction - debate)
{:ok, _rel_9} =
  Relationships.create_relationship(%{
    from_id: claim_7.id,
    from_type: :claim,
    to_id: evidence_9.id,
    to_type: :evidence,
    relationship_type: :contradicts,
    weight: -0.40,
    confidence: 0.60,
    reasoning: "IFS analysis suggests support package had measurable (if insufficient) impact",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Expert interview supports Claim 2
{:ok, _rel_10} =
  Relationships.create_relationship(%{
    from_id: claim_2.id,
    from_type: :claim,
    to_id: evidence_10.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.65,
    confidence: 0.70,
    reasoning: "Expert opinion aligns with energy price causation",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# ============================================================================
# New relationships for evidence 11-30
# ============================================================================

# Claim 1 <- Evidence 11 (CPIH confirms headline inflation)
{:ok, _rel_11} =
  Relationships.create_relationship(%{
    from_id: claim_1.id,
    from_type: :claim,
    to_id: evidence_11.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.95,
    confidence: 0.93,
    reasoning: "CPIH measure corroborates CPI headline figure with housing costs included",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 1 <- Evidence 12 (RPI provides alternative measure)
{:ok, _rel_12} =
  Relationships.create_relationship(%{
    from_id: claim_1.id,
    from_type: :claim,
    to_id: evidence_12.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.70,
    confidence: 0.85,
    reasoning: "RPI gives higher inflation reading (14.2%), contextualises CPI as conservative measure",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 3 <- Evidence 13 (producer prices upstream of food prices)
{:ok, _rel_13} =
  Relationships.create_relationship(%{
    from_id: claim_3.id,
    from_type: :claim,
    to_id: evidence_13.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.70,
    confidence: 0.80,
    reasoning: "Producer price inflation confirms upstream cost pressures feeding into food prices",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 3 <- Evidence 14 (trade disruptions and food imports)
{:ok, _rel_14} =
  Relationships.create_relationship(%{
    from_id: claim_3.id,
    from_type: :claim,
    to_id: evidence_14.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.65,
    confidence: 0.75,
    reasoning: "Trade statistics reveal import cost increases for food commodities post-Brexit",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 4 <- Evidence 15 (academic study on transmission lags)
{:ok, _rel_15} =
  Relationships.create_relationship(%{
    from_id: claim_4.id,
    from_type: :claim,
    to_id: evidence_15.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.80,
    confidence: 0.85,
    reasoning: "Academic analysis demonstrates extended monetary policy transmission lags in post-COVID economy",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 3 <- Evidence 16 (food supply chain academic study)
{:ok, _rel_16} =
  Relationships.create_relationship(%{
    from_id: claim_3.id,
    from_type: :claim,
    to_id: evidence_16.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.80,
    confidence: 0.82,
    reasoning: "Peer-reviewed study quantifies supply chain disruption pass-through to UK food prices",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 2 <- Evidence 17 (greedflation contradicts energy-only explanation)
{:ok, _rel_17} =
  Relationships.create_relationship(%{
    from_id: claim_2.id,
    from_type: :claim,
    to_id: evidence_17.id,
    to_type: :evidence,
    relationship_type: :contradicts,
    weight: -0.50,
    confidence: 0.70,
    reasoning: "Greedflation analysis suggests corporate profit-taking was a significant co-driver alongside energy costs",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 6 <- Evidence 18 (household expectations and behaviour)
{:ok, _rel_18} =
  Relationships.create_relationship(%{
    from_id: claim_6.id,
    from_type: :claim,
    to_id: evidence_18.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.60,
    confidence: 0.70,
    reasoning: "Survey data shows low-income households had highest inflation expectations and greatest behavioural adjustment",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 6 <- Evidence 19 (BBC documentary on lived experience)
{:ok, _rel_19} =
  Relationships.create_relationship(%{
    from_id: claim_6.id,
    from_type: :claim,
    to_id: evidence_19.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.55,
    confidence: 0.65,
    reasoning: "Documentary provides first-person testimony of disproportionate impact on low-income households",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 3 <- Evidence 20 (Guardian investigation on supermarket margins)
{:ok, _rel_20} =
  Relationships.create_relationship(%{
    from_id: claim_3.id,
    from_type: :claim,
    to_id: evidence_20.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.55,
    confidence: 0.60,
    reasoning: "Investigative reporting suggests supply chain disruptions were partially amplified by supermarket margin expansion",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 4 <- Evidence 21 (FT analysis on BoE failures)
{:ok, _rel_21} =
  Relationships.create_relationship(%{
    from_id: claim_4.id,
    from_type: :claim,
    to_id: evidence_21.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.65,
    confidence: 0.72,
    reasoning: "FT analysis details institutional and communication failures in BoE inflation response",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 6 <- Evidence 22 (JRF poverty report)
{:ok, _rel_22} =
  Relationships.create_relationship(%{
    from_id: claim_6.id,
    from_type: :claim,
    to_id: evidence_22.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.80,
    confidence: 0.82,
    reasoning: "JRF data demonstrates inflation pushed additional 400,000 people into destitution in 2022",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 2 <- Evidence 23 (Citizens Advice energy debt)
{:ok, _rel_23} =
  Relationships.create_relationship(%{
    from_id: claim_2.id,
    from_type: :claim,
    to_id: evidence_23.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.70,
    confidence: 0.75,
    reasoning: "Energy debt data confirms energy costs as dominant household pressure",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 6 <- Evidence 24 (Trussell Trust food bank usage)
{:ok, _rel_24} =
  Relationships.create_relationship(%{
    from_id: claim_6.id,
    from_type: :claim,
    to_id: evidence_24.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.75,
    confidence: 0.80,
    reasoning: "Record 3 million food bank parcels in 2022-23 demonstrates disproportionate impact on poorest",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 7 <- Evidence 25 (HM Treasury support package details)
{:ok, _rel_25} =
  Relationships.create_relationship(%{
    from_id: claim_7.id,
    from_type: :claim,
    to_id: evidence_25.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.55,
    confidence: 0.65,
    reasoning: "Treasury factsheet details scope of support, enabling assessment of sufficiency",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 7 <- Evidence 26 (DWP benefit uprating)
{:ok, _rel_26} =
  Relationships.create_relationship(%{
    from_id: claim_7.id,
    from_type: :claim,
    to_id: evidence_26.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.60,
    confidence: 0.70,
    reasoning: "Benefit uprating lagged inflation peak by several months, confirming timing gap in support",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 1 <- Evidence 27 (Eurostat comparative context)
{:ok, _rel_27} =
  Relationships.create_relationship(%{
    from_id: claim_1.id,
    from_type: :claim,
    to_id: evidence_27.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.65,
    confidence: 0.80,
    reasoning: "Eurostat data shows UK inflation exceeded EU average, contextualising as partly UK-specific",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 4 <- Evidence 28 (IMF cross-country analysis)
{:ok, _rel_28} =
  Relationships.create_relationship(%{
    from_id: claim_4.id,
    from_type: :claim,
    to_id: evidence_28.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.60,
    confidence: 0.75,
    reasoning: "IMF analysis suggests supply-side inflation resists monetary tightening across advanced economies",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 7 <- Evidence 29 (expert critique of fiscal response)
{:ok, _rel_29} =
  Relationships.create_relationship(%{
    from_id: claim_7.id,
    from_type: :claim,
    to_id: evidence_29.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.55,
    confidence: 0.60,
    reasoning: "Former economic adviser argues fiscal response was poorly targeted and insufficient",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Claim 2 <- Evidence 30 (leaked supplier pricing memo)
{:ok, _rel_30} =
  Relationships.create_relationship(%{
    from_id: claim_2.id,
    from_type: :claim,
    to_id: evidence_30.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.40,
    confidence: 0.35,
    reasoning: "Leaked memo suggests energy supplier anticipated and exploited price cap mechanics; low confidence due to unverifiable provenance",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# ============================================================================
# Cross-connections between evidence items
# ============================================================================

# Evidence 17 (greedflation) contextualises Evidence 20 (Guardian supermarket investigation)
{:ok, _rel_31} =
  Relationships.create_relationship(%{
    from_id: evidence_17.id,
    from_type: :evidence,
    to_id: evidence_20.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.70,
    confidence: 0.75,
    reasoning: "Academic greedflation framework provides theoretical basis for Guardian profit margin findings",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Evidence 13 (producer prices) supports Evidence 16 (food supply chain study)
{:ok, _rel_32} =
  Relationships.create_relationship(%{
    from_id: evidence_13.id,
    from_type: :evidence,
    to_id: evidence_16.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.80,
    confidence: 0.85,
    reasoning: "ONS producer price data underpins supply chain pass-through estimates in academic study",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Evidence 22 (JRF poverty) supports Evidence 24 (Trussell Trust food banks)
{:ok, _rel_33} =
  Relationships.create_relationship(%{
    from_id: evidence_22.id,
    from_type: :evidence,
    to_id: evidence_24.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.75,
    confidence: 0.80,
    reasoning: "JRF destitution figures consistent with Trussell Trust record food bank usage",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Evidence 27 (Eurostat) contradicts Evidence 15 (transmission lags - UK-specific framing)
{:ok, _rel_34} =
  Relationships.create_relationship(%{
    from_id: evidence_27.id,
    from_type: :evidence,
    to_id: evidence_15.id,
    to_type: :evidence,
    relationship_type: :contradicts,
    weight: -0.35,
    confidence: 0.55,
    reasoning: "Cross-country data suggests UK transmission lag is not unique, weakening UK-specific policy failure narrative",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Evidence 30 (leaked memo) contextualises Evidence 23 (Citizens Advice energy debt)
{:ok, _rel_35} =
  Relationships.create_relationship(%{
    from_id: evidence_30.id,
    from_type: :evidence,
    to_id: evidence_23.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.35,
    confidence: 0.30,
    reasoning: "If verified, leaked pricing strategy memo would explain mechanism behind rising energy debt",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Evidence 11 (CPIH) supports Evidence 1 (CPI) - methodological cross-validation
{:ok, _rel_36} =
  Relationships.create_relationship(%{
    from_id: evidence_11.id,
    from_type: :evidence,
    to_id: evidence_1.id,
    to_type: :evidence,
    relationship_type: :supports,
    weight: 0.90,
    confidence: 0.95,
    reasoning: "CPIH and CPI track closely, confirming measurement robustness across methodologies",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Evidence 28 (IMF) contextualises Evidence 4 (BoE Monetary Policy)
{:ok, _rel_37} =
  Relationships.create_relationship(%{
    from_id: evidence_28.id,
    from_type: :evidence,
    to_id: evidence_4.id,
    to_type: :evidence,
    relationship_type: :contextualizes,
    weight: 0.65,
    confidence: 0.72,
    reasoning: "IMF global analysis provides broader context for BoE policy decisions",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

# Evidence 25 (HM Treasury) contradicts Evidence 29 (Meadway interview)
{:ok, _rel_38} =
  Relationships.create_relationship(%{
    from_id: evidence_25.id,
    from_type: :evidence,
    to_id: evidence_29.id,
    to_type: :evidence,
    relationship_type: :contradicts,
    weight: -0.45,
    confidence: 0.55,
    reasoning: "Treasury factsheet claims broad and sufficient support; Meadway argues it was poorly targeted",
    created_by: "sarah.johnson@investigativeunit.uk"
  })

IO.puts("Created 38 relationships")

#
# NAVIGATION PATHS (6 total - for different audiences)
#

IO.puts("Creating navigation paths...")

# Path 1: Researcher perspective (prioritizes methodology)
{:ok, _path_researcher} =
  Navigation.create_path(%{
    investigation_id: investigation_id,
    audience_type: :researcher,
    name: "Academic Research Path",
    description: "Evidence-first approach prioritizing methodology and replicability",
    entry_points: [claim_1.id],
    path_nodes: [
      %{"entity_id" => claim_1.id, "entity_type" => "claim", "order" => 1, "context" => "Start with primary quantitative claim"},
      %{"entity_id" => evidence_1.id, "entity_type" => "evidence", "order" => 2, "context" => "Official ONS dataset - highest replicability"},
      %{"entity_id" => claim_2.id, "entity_type" => "claim", "order" => 3, "context" => "Causal hypothesis"},
      %{"entity_id" => evidence_7.id, "entity_type" => "evidence", "order" => 4, "context" => "Peer-reviewed academic study"},
      %{"entity_id" => claim_5.id, "entity_type" => "claim", "order" => 5, "context" => "Real wage impact - quantitative"},
      %{"entity_id" => evidence_5.id, "entity_type" => "evidence", "order" => 6, "context" => "ONS earnings data"}
    ],
    created_by: "sarah.johnson@investigativeunit.uk",
    metadata: %{"priority_dimensions" => ["methodology", "replicability", "transparency"]}
  })

# Path 2: Policymaker perspective (prioritizes provenance and publication)
{:ok, _path_policymaker} =
  Navigation.create_path(%{
    investigation_id: investigation_id,
    audience_type: :policymaker,
    name: "Policy Impact Path",
    description: "Authoritative sources for policy recommendations",
    entry_points: [claim_1.id],
    path_nodes: [
      %{"entity_id" => claim_1.id, "entity_type" => "claim", "order" => 1, "context" => "Primary inflation figure"},
      %{"entity_id" => evidence_1.id, "entity_type" => "evidence", "order" => 2, "context" => "Official government statistics"},
      %{"entity_id" => claim_6.id, "entity_type" => "claim", "order" => 3, "context" => "Inequality concern"},
      %{"entity_id" => evidence_8.id, "entity_type" => "evidence", "order" => 4, "context" => "Think tank analysis"},
      %{"entity_id" => claim_7.id, "entity_type" => "claim", "order" => 5, "context" => "Policy evaluation"},
      %{"entity_id" => evidence_9.id, "entity_type" => "evidence", "order" => 6, "context" => "IFS fiscal analysis"}
    ],
    created_by: "sarah.johnson@investigativeunit.uk",
    metadata: %{"priority_dimensions" => ["provenance", "publication", "objective"]}
  })

# Path 3: Affected Person perspective (prioritizes clarity and relevance)
{:ok, _path_affected} =
  Navigation.create_path(%{
    investigation_id: investigation_id,
    audience_type: :affected_person,
    name: "Personal Impact Path",
    description: "Clear explanations of how inflation affects daily life",
    entry_points: [claim_5.id],
    path_nodes: [
      %{"entity_id" => claim_5.id, "entity_type" => "claim", "order" => 1, "context" => "Start with wage impact - directly relevant"},
      %{"entity_id" => evidence_5.id, "entity_type" => "evidence", "order" => 2, "context" => "Official wage data"},
      %{"entity_id" => claim_3.id, "entity_type" => "claim", "order" => 3, "context" => "Food prices - household budget"},
      %{"entity_id" => evidence_3.id, "entity_type" => "evidence", "order" => 4, "context" => "Food price statistics"},
      %{"entity_id" => claim_2.id, "entity_type" => "claim", "order" => 5, "context" => "Energy costs - bills impact"},
      %{"entity_id" => evidence_2.id, "entity_type" => "evidence", "order" => 6, "context" => "Price cap information"}
    ],
    created_by: "sarah.johnson@investigativeunit.uk",
    metadata: %{"priority_dimensions" => ["objective", "provenance", "transparency"]}
  })

# Path 4: Skeptic perspective (prioritizes transparency and replicability, starts with contradictions)
{:ok, _path_skeptic} =
  Navigation.create_path(%{
    investigation_id: investigation_id,
    audience_type: :skeptic,
    name: "Critical Verification Path",
    description: "Transparency-first approach starting with contested claims and contradictory evidence to stress-test the investigation",
    entry_points: [claim_4.id],
    path_nodes: [
      %{"entity_id" => claim_4.id, "entity_type" => "claim", "order" => 1, "context" => "Start with most contested claim - BoE policy failure"},
      %{"entity_id" => evidence_15.id, "entity_type" => "evidence", "order" => 2, "context" => "Academic study on transmission lags - testable hypothesis"},
      %{"entity_id" => evidence_28.id, "entity_type" => "evidence", "order" => 3, "context" => "IMF cross-country data - does UK pattern replicate internationally?"},
      %{"entity_id" => evidence_27.id, "entity_type" => "evidence", "order" => 4, "context" => "Eurostat comparative data - contradicts UK-specific failure narrative"},
      %{"entity_id" => claim_2.id, "entity_type" => "claim", "order" => 5, "context" => "Energy as primary driver - examine competing explanations"},
      %{"entity_id" => evidence_17.id, "entity_type" => "evidence", "order" => 6, "context" => "Greedflation study contradicts simple supply-shock narrative"},
      %{"entity_id" => evidence_30.id, "entity_type" => "evidence", "order" => 7, "context" => "Leaked memo - lowest PROMPT scores; assess provenance critically"},
      %{"entity_id" => claim_1.id, "entity_type" => "claim", "order" => 8, "context" => "Return to headline claim - verify against multiple ONS measures"},
      %{"entity_id" => evidence_11.id, "entity_type" => "evidence", "order" => 9, "context" => "CPIH cross-validation of CPI methodology"},
      %{"entity_id" => evidence_12.id, "entity_type" => "evidence", "order" => 10, "context" => "RPI alternative measure - shows methodological sensitivity"}
    ],
    created_by: "sarah.johnson@investigativeunit.uk",
    metadata: %{"priority_dimensions" => ["transparency", "replicability", "methodology"]}
  })

# Path 5: Activist perspective (prioritizes impact and provenance, starts with inequality claims)
{:ok, _path_activist} =
  Navigation.create_path(%{
    investigation_id: investigation_id,
    audience_type: :activist,
    name: "Social Impact Path",
    description: "Impact-first approach starting with inequality claims and NGO evidence for advocacy and campaigning",
    entry_points: [claim_6.id],
    path_nodes: [
      %{"entity_id" => claim_6.id, "entity_type" => "claim", "order" => 1, "context" => "Start with inequality claim - who is most affected?"},
      %{"entity_id" => evidence_22.id, "entity_type" => "evidence", "order" => 2, "context" => "JRF poverty data - 400,000 additional people in destitution"},
      %{"entity_id" => evidence_24.id, "entity_type" => "evidence", "order" => 3, "context" => "Trussell Trust food bank records - concrete impact metric"},
      %{"entity_id" => evidence_19.id, "entity_type" => "evidence", "order" => 4, "context" => "BBC documentary - lived experience testimony"},
      %{"entity_id" => claim_5.id, "entity_type" => "claim", "order" => 5, "context" => "Real wage decline - quantified harm to workers"},
      %{"entity_id" => evidence_5.id, "entity_type" => "evidence", "order" => 6, "context" => "ONS earnings data - official provenance for advocacy"},
      %{"entity_id" => claim_7.id, "entity_type" => "claim", "order" => 7, "context" => "Government response was insufficient"},
      %{"entity_id" => evidence_26.id, "entity_type" => "evidence", "order" => 8, "context" => "DWP benefit uprating lag - policy failure with traceable provenance"},
      %{"entity_id" => evidence_23.id, "entity_type" => "evidence", "order" => 9, "context" => "Citizens Advice energy debt data - systemic failure evidence"},
      %{"entity_id" => claim_3.id, "entity_type" => "claim", "order" => 10, "context" => "Food price crisis - basic necessity under pressure"},
      %{"entity_id" => evidence_20.id, "entity_type" => "evidence", "order" => 11, "context" => "Guardian supermarket profit investigation - accountability angle"}
    ],
    created_by: "sarah.johnson@investigativeunit.uk",
    metadata: %{"priority_dimensions" => ["provenance", "objective", "publication"]}
  })

# Path 6: Journalist perspective (balanced path, starts with strongest sourced claims)
{:ok, _path_journalist} =
  Navigation.create_path(%{
    investigation_id: investigation_id,
    audience_type: :journalist,
    name: "Balanced Investigation Path",
    description: "Balanced approach starting with strongest-sourced claims, triangulating across official data, academic research, and on-the-ground reporting",
    entry_points: [claim_1.id],
    path_nodes: [
      %{"entity_id" => claim_1.id, "entity_type" => "claim", "order" => 1, "context" => "Lead with strongest-sourced headline claim"},
      %{"entity_id" => evidence_1.id, "entity_type" => "evidence", "order" => 2, "context" => "ONS CPI - unimpeachable source for lead paragraph"},
      %{"entity_id" => evidence_27.id, "entity_type" => "evidence", "order" => 3, "context" => "Eurostat comparison - UK vs EU context for reader"},
      %{"entity_id" => claim_2.id, "entity_type" => "claim", "order" => 4, "context" => "Energy as primary driver - the why behind the number"},
      %{"entity_id" => evidence_2.id, "entity_type" => "evidence", "order" => 5, "context" => "Ofgem price cap - regulatory source"},
      %{"entity_id" => evidence_17.id, "entity_type" => "evidence", "order" => 6, "context" => "Greedflation counter-narrative - journalistic balance"},
      %{"entity_id" => claim_6.id, "entity_type" => "claim", "order" => 7, "context" => "Human impact angle"},
      %{"entity_id" => evidence_24.id, "entity_type" => "evidence", "order" => 8, "context" => "Trussell Trust statistics - concrete and citable"},
      %{"entity_id" => evidence_10.id, "entity_type" => "evidence", "order" => 9, "context" => "Expert quote from LSE economist"},
      %{"entity_id" => claim_7.id, "entity_type" => "claim", "order" => 10, "context" => "Government response assessment - hold power to account"},
      %{"entity_id" => evidence_25.id, "entity_type" => "evidence", "order" => 11, "context" => "Treasury factsheet - government's own claims"},
      %{"entity_id" => evidence_29.id, "entity_type" => "evidence", "order" => 12, "context" => "Expert rebuttal - balance against government position"},
      %{"entity_id" => evidence_30.id, "entity_type" => "evidence", "order" => 13, "context" => "Leaked memo - potential exclusive, requires verification caveat"}
    ],
    created_by: "sarah.johnson@investigativeunit.uk",
    metadata: %{"priority_dimensions" => ["provenance", "transparency", "publication"]}
  })

IO.puts("Created 6 navigation paths")

IO.puts("\nUK Inflation 2023 investigation seeded successfully!")
IO.puts("Summary:")
IO.puts("  - Investigation ID: #{investigation_id}")
IO.puts("  - Claims: 7")
IO.puts("  - Evidence: 30")
IO.puts("  - Relationships: 38")
IO.puts("  - Navigation Paths: 6 (researcher, policymaker, affected_person, skeptic, activist, journalist)")
IO.puts("\nReady for Phase 1 user testing!")
