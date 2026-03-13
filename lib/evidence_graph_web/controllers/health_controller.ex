# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.HealthController do
  @moduledoc """
  Health check endpoint for container orchestration and load balancers.
  Returns HTTP 200 with JSON status when the application is running.
  """
  use EvidenceGraphWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
