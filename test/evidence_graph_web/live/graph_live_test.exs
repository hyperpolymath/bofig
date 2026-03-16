# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.GraphLiveTest do
  use EvidenceGraphWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GraphLive" do
    test "mounts with graph container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/graph")

      assert html =~ "Evidence Graph"
      assert html =~ "evidence-graph"
    end

    test "displays audience selector buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/graph")

      assert html =~ "Audience"
      assert html =~ "Researcher"
      assert html =~ "Policymaker"
    end

    test "shows detail panel placeholder", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/graph")

      assert html =~ "Click a node to see details"
    end

    test "audience selection updates assigns", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/investigations/uk_inflation_2023/graph")

      html = render_click(view, "select_audience", %{"audience" => "researcher"})
      assert html =~ "Clear filter"
    end
  end
end
