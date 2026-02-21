// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

// Phoenix LiveView entry point for Evidence Graph.
// Connects to the LiveView socket, registers hooks for D3.js
// visualisations (evidence graph + PROMPT radar chart), and
// sets up the topbar progress indicator.

import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import Hooks from "./hooks";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#2196f3" }, shadowColor: "rgba(0,0,0,.3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// Connect if there are any LiveViews on the page
liveSocket.connect();

// Expose liveSocket on window for web console debug logs and latency simulation:
//   >> liveSocket.enableDebug()
//   >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
//   >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
