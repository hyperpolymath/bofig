# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.InvestigationLiveTest do
  use EvidenceGraphWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "InvestigationLive.Index" do
    test "renders the dashboard page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Investigation"
      assert html =~ "Evidence Graph"
    end

    test "displays audience navigation badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Researcher"
      assert html =~ "Policymaker"
      assert html =~ "Skeptic"
      assert html =~ "Activist"
      assert html =~ "Affected Person"
      assert html =~ "Journalist"
    end

    test "shows claims and evidence sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Claims"
      assert html =~ "Evidence"
    end
  end

  describe "InvestigationLive.Show" do
    test "renders investigation detail page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023")

      assert html =~ "uk_inflation_2023"
      assert html =~ "Detailed view"
    end

    test "has graph and PROMPT action buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023")

      assert html =~ "Graph"
      assert html =~ "PROMPT"
    end
  end
end
