# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
external_contract? = System.get_env("RUN_EXTERNAL_CONTRACT_TESTS") in ["1", "true", "TRUE"]

if external_contract? do
  ExUnit.start()
else
  ExUnit.start(exclude: [external_repo_contract: true])
end
