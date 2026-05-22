# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.UserSessionHTML do
  use EvidenceGraphWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:evidence_graph, EvidenceGraph.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
