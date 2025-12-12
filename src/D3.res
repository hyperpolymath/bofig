// D3.js bindings for ReScript

type selection
type simulation
type event = {transform: {..}}

// d3 global
@val external d3: {..} = "d3"

// Selection methods
@send external select: ({..}, string) => selection = "select"
@send external selectAll: (selection, string) => selection = "selectAll"
@send external append: (selection, string) => selection = "append"
@send external attr: (selection, string, 'a) => selection = "attr"
@send external style: (selection, string, string) => selection = "style"
@send external text: (selection, string) => selection = "text"
@send external data: (selection, array<'a>) => selection = "data"
@send external join: (selection, string) => selection = "join"
@send external on: (selection, string, 'a => unit) => selection = "on"
@send external call: (selection, 'a) => selection = "call"
@send external remove: selection => unit = "remove"

// Force simulation
@send external forceSimulation: ({..}, array<'a>) => simulation = "forceSimulation"
@send external force: (simulation, string, 'a) => simulation = "force"
@send external forceLink: ({..}, array<'a>) => {..} = "forceLink"
@send external forceManyBody: {..} => {..} = "forceManyBody"
@send external forceCenter: ({..}, float, float) => {..} = "forceCenter"
@send external forceCollide: {..} => {..} = "forceCollide"
@send external onTick: (simulation, string, unit => unit) => simulation = "on"
@send external id: ({..}, 'a => string) => {..} = "id"
@send external distance: ({..}, int) => {..} = "distance"
@send external strength: ({..}, int) => {..} = "strength"
@send external radius: ({..}, int) => {..} = "radius"

// Zoom
@send external zoom: {..} => {..} = "zoom"
@send external scaleExtent: ({..}, (float, float)) => {..} = "scaleExtent"
@send external onZoom: ({..}, string, event => unit) => {..} = "on"
