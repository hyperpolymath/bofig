// Evidence Graph Visualization with D3.js
// Interactive force-directed graph for Claims and Evidence

type node = {
  id: string,
  label: string,
  nodeType: string,
  promptScore: float,
}

type link = {
  source: string,
  target: string,
  relationship: string,
}

type graphData = {
  nodes: array<node>,
  links: array<link>,
}

type t = {
  mutable container: Nullable.t<Dom.element>,
  mutable width: int,
  mutable height: int,
  mutable data: option<graphData>,
  mutable svg: option<D3.selection>,
  mutable simulation: option<D3.simulation>,
}

// DOM bindings
@val external document: Dom.document = "document"
@send external getElementById: (Dom.document, string) => Nullable.t<Dom.element> = "getElementById"
@get external clientWidth: Dom.element => int = "clientWidth"
@get external domId: Dom.element => string = "id"

// Fetch API
@val external fetch: (string, {..}) => promise<{..}> = "fetch"
@send external json: {..} => promise<{..}> = "json"

// Console
@val @scope("console") external log: 'a => unit = "log"
@val @scope("console") external error: string => unit = "error"
@val @scope("JSON") external stringify: 'a => string = "stringify"

let getRelationshipColor = relationship =>
  switch relationship {
  | "supports" => "#4CAF50"
  | "contradicts" => "#F44336"
  | "contextualizes" => "#2196F3"
  | _ => "#9E9E9E"
  }

let getNodeColor = (nodeType, promptScore) => {
  let baseColor = switch nodeType {
  | "claim" => (33, 150, 243)  // Blue
  | "evidence" => (76, 175, 80) // Green
  | _ => (158, 158, 158)
  }
  
  let (r, g, b) = baseColor
  let alpha = promptScore /. 100.0
  `rgba(${Int.toString(r)}, ${Int.toString(g)}, ${Int.toString(b)}, ${Float.toString(alpha)})`
}

let make = (containerId, ~width=?, ~height=600, ()) => {
  let container = document->getElementById(containerId)
  let w = switch (width, container->Nullable.toOption) {
  | (Some(w), _) => w
  | (None, Some(el)) => el->clientWidth
  | (None, None) => 800
  }
  
  {
    container,
    width: w,
    height,
    data: None,
    svg: None,
    simulation: None,
  }
}

let initSVG = viz => {
  viz.container->Nullable.toOption->Option.forEach(container => {
    let svg = D3.d3
      ->D3.select("#" ++ container->domId)
      ->D3.append("svg")
      ->D3.attr("width", viz.width)
      ->D3.attr("height", viz.height)
      ->D3.attr("viewBox", [0, 0, viz.width, viz.height])
    
    // Add container group
    svg->D3.append("g")->ignore
    
    // Add arrow markers
    let defs = svg->D3.append("defs")
    ["supports", "contradicts", "contextualizes"]->Array.forEach(rel => {
      defs
        ->D3.append("marker")
        ->D3.attr("id", "arrow-" ++ rel)
        ->D3.attr("viewBox", "0 -5 10 10")
        ->D3.attr("refX", 20)
        ->D3.attr("refY", 0)
        ->D3.attr("markerWidth", 6)
        ->D3.attr("markerHeight", 6)
        ->D3.attr("orient", "auto")
        ->D3.append("path")
        ->D3.attr("d", "M0,-5L10,0L0,5")
        ->D3.attr("fill", getRelationshipColor(rel))
        ->ignore
    })
    
    viz.svg = Some(svg)
  })
}

let loadData = async (viz, investigationId) => {
  let query = `
    query {
      claims(investigationId: "${investigationId}") {
        id
        text
        claimType
        promptScores { overall provenance methodology }
      }
      evidenceList(investigationId: "${investigationId}") {
        id
        title
        evidenceType
        promptScores { overall provenance methodology }
      }
    }
  `
  
  let response = await fetch("/api/graphql", {
    "method": "POST",
    "headers": {"Content-Type": "application/json"},
    "body": stringify({"query": query}),
  })
  
  let result = await response->json
  log(result)
  
  // Transform and render
  viz
}

let render = viz => {
  switch viz.data {
  | None => error("No data to render")
  | Some(data) => {
      viz.svg->Option.forEach(svg => {
        // Initialize force simulation
        let simulation = D3.d3
          ->D3.forceSimulation(data.nodes)
          ->D3.force("link", 
            D3.d3->D3.forceLink(data.links)
              ->D3.id(n => n.id)
              ->D3.distance(100))
          ->D3.force("charge", 
            D3.d3->D3.forceManyBody->D3.strength(-300))
          ->D3.force("center", 
            D3.d3->D3.forceCenter(Float.fromInt(viz.width) /. 2.0, Float.fromInt(viz.height) /. 2.0))
          ->D3.force("collision",
            D3.d3->D3.forceCollide->D3.radius(40))
        
        viz.simulation = Some(simulation)
        
        // Render nodes
        let nodeGroup = svg
          ->D3.select("g")
          ->D3.selectAll("circle.node")
          ->D3.data(data.nodes)
          ->D3.join("circle")
          ->D3.attr("class", "node")
          ->D3.attr("r", 15)
          ->D3.attr("fill", n => getNodeColor(n.nodeType, n.promptScore))
        
        log("Graph rendered")
      })
    }
  }
  viz
}

// Initialize on creation
let init = (containerId, ~width=?, ~height=600, ()) => {
  let viz = make(containerId, ~width?, ~height, ())
  initSVG(viz)
  viz
}
