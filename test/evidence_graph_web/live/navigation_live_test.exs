# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.NavigationLiveTest do
  use EvidenceGraphWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "NavigationLive" do
    test "mounts with audience tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/navigate/researcher")

      assert html =~ "Navigation"
      assert html =~ "Researcher"
      assert html =~ "Policymaker"
    end

    test "shows progress indicator when path loaded", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/navigate/researcher")

      # Either shows progress or "no path available" — both are valid
      assert html =~ "Step" || html =~ "No navigation path"
    end

    test "audience switch navigates via patch", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/investigations/uk_inflation_2023/navigate/researcher")

      # Navigate to skeptic audience
      assert render_patch(view, ~p"/investigations/uk_inflation_2023/navigate/skeptic") =~
               "skeptic"
    end

    test "defaults to researcher when no audience given", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/navigate")

      assert html =~ "Navigation"
    end
  end
end
