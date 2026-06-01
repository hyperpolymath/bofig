# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraph.Repo.Migrations.UpdateObanToV14 do
  use Ecto.Migration

  def up, do: Oban.Migrations.up(version: 14)
  def down, do: Oban.Migrations.down(version: 12)
end
