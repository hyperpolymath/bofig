# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
defmodule EvidenceGraphWeb.Schema.Types.AuthorizationTypes do
  @moduledoc """
  Absinthe type definitions for the Authorization (RBAC) module.
  """

  use Absinthe.Schema.Notation

  @desc "An access grant linking a user to an investigation with a specific role"
  object :access_grant do
    field :id, non_null(:id)
    field :investigation_id, non_null(:string)
    field :user_id, non_null(:string)
    field :role, non_null(:string)
    field :granted_at, :string
    field :updated_at, :string
  end

  enum :rbac_role_enum do
    value :owner, description: "Full control including deletion and management"
    value :editor, description: "View, edit, export, share"
    value :reviewer, description: "Read-only with export capability"
    value :viewer, description: "Read-only access"
  end

  input_object :grant_access_input do
    field :investigation_id, non_null(:string)
    field :user_id, non_null(:string)
    field :role, non_null(:rbac_role_enum)
  end

  input_object :revoke_access_input do
    field :investigation_id, non_null(:string)
    field :user_id, non_null(:string)
  end
end
