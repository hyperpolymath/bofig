# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.PromptLiveTest do
  use EvidenceGraphWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "PromptLive" do
    test "renders PROMPT scoring page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/prompt")

      assert html =~ "PROMPT Scores"
      assert html =~ "Epistemological scoring"
    end

    test "shows item selector", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/prompt")

      assert html =~ "Select Item"
    end

    test "shows audience weight toggles", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/prompt")

      assert html =~ "Audience Weights"
      assert html =~ "Researcher"
      assert html =~ "Skeptic"
    end

    test "contains radar chart container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/investigations/uk_inflation_2023/prompt")

      assert html =~ "prompt-radar"
    end
  end
end
