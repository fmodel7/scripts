# Lab and authorized-environment acceptance

Automated tests do not replace acceptance. Preserve evidence without committing real environment data to the public repository.

## Before applying

1. Independently identify forest root, current PDC, OS/runtime and authorized operator.
2. Confirm elevation, complete files, version/hashes and local output storage protected under policy.
3. Review GPO/MDM/automation managing W32Time. Use the managing mechanism when policy exists; do not forcibly delete it.
4. Select approved sources and review terms, actual diversity, location and latency.
5. Independently assess current offset, phase-correction limits and clock-step risk. The script does not measure absolute accuracy.
6. Review DNS and UDP 123 firewall/NAT, including the service's source port 123. stripchart alone does not validate that path.
7. For VMs, review host/guest provider, restart, saved-state/restore and migration. The script changes no integration settings.
8. Define maintenance window, responsible operators, recovery access and partial-change procedure. A registry export cannot undo time.

## Suggested exercises

- Run all three offline suites in separate processes and retain results.
- Audit and independently confirm no script-induced change.
- Apply -WhatIf using approved peers; confirm no change or .reg export.
- In an appropriate isolated test forest, confirm member/non-PDC/child-PDC rejection.
- Confirm policy/disabled-service guards without bypassing them.
- Review snapshot/export and reports before authorized application.
- Apply on the lab root PDC; independently check the five values, service, source, leap/stratum and age.
- Observe consumers/DCs and authentication under team procedures; AppliedVerified alone is not full acceptance.
- Check local language: unknown output must remain unconfirmed even if apparently healthy.
- Evaluate restart/role-transfer behavior in the lab with correct policies and topology.

## Completion

Record version, hashes, environment, sources, findings, remaining gaps and the responsible person's decision. Investigate timeout/partial state before another attempt. Do not induce production network, disk or FSMO failures merely to test the script.

Mocks cover failure paths. Additional live tests require a suitable environment and procedure that protects operational AD. [Manual](MANUAL.en-US.md).
