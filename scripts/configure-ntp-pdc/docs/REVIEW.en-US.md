# Review of the supplied code

Configure NTP PDC 1.0.0 · October 23, 2026 · F. Model / FMODEL

The original purpose is preserved: organize AD time from the appropriate PDC. The supplied file had no explicit version; 1.0.0 identifies this first reviewed library delivery. Microsoft references and project safeguards do not constitute universal compliance or certification.

| Original observation | Revision |
|---|---|
| GetCurrentDomain followed the operator's context. | Computer domain, forest root and full target identity are checked. |
| Any domain PDC was eligible. | Apply requires the forest-root domain's PDC. |
| Local host name was interpolated into regex. | Explicit full-name comparisons. |
| Fixed Brazilian peers and IP comments. | No default provider; explicit approved sources, without assuming old DNS mappings. |
| Native exit codes were not checked. | Captured streams, exit codes and timeout; failures stop later steps. |
| Running the file immediately changed settings. | Audit default, explicit Apply, ShouldProcess/WhatIf and high-impact approval. |
| No managed-policy check. | Existing W32Time policy branch blocks local Apply, including empty branches. |
| No pre-change state backup. | Snapshot, export, persisted pre-change report and per-action intent journal. |
| /reliable:yes without context discussion. | Automatic AnnounceFlags 10 default; optional Always 5 with limitations. |
| Anything other than Local CMOS Clock meant success. | Requested source, recognized age/leap/stratum, settings and exit codes participate. |
| Fixed three/five-second sleeps. | Running service wait and monotonic evidence polling. |
| Force restart. | No forced stopping of dependent services. |
| Microsoft manufacturer could imply a VM. | Model/vendor hint only, not proof. |
| Generic instruction to disable host time. | No automatic integration changes; platform/scenario-specific review. |
| /monitor could query the domain broadly. | Local diagnostics and optional stripchart of requested peers. |
| Errors lacked reliable automation outcome. | Documented states and exit codes 0/1/2. |
| No separated tests/evidence. | Mocks, isolated CLI processes and 5.1/7 Windows/Linux CI. |
| No individual operational manual. | PT-BR/EN-US README/manuals, HTML examples and acceptance guidance. |

## Project-specific choices

Audit default, refusing empty policy branches, local lock, native timeout, ten-peer limit, HTML and journal are engineering choices. They are not all literal requirements of a Microsoft configuration recipe.

AnnounceFlags=10 is not a universal policy prescription. Peer 0x8/0xA flags are a different field. Existing phase-correction limits and VM integration remain unchanged and require environment-specific review.

The tool does not make arbitrary upstreams trustworthy, authenticate external NTP or independently measure precision. DNS, acceptable stratum and recent status remain partial evidence, explicitly described in reports.

## Boundaries

There is no AD/registry/service transaction; FSMO/GPO can change between checks. The lock does not block other tools. No reverse clock operation, AD restore or VM recovery exists. Local backup is not immutable/encrypted or a restore test. Later API/output/language changes may require parser work.

Initial CI detected different service-enum resolution under Windows PowerShell 5.1. The implementation was corrected to use WaitForStatus method-parameter conversion. Final EVIDENCE.json pins the reviewed source; this must not be represented as a real-domain configuration test.

[Manual](MANUAL.en-US.md) · [Evidence](EVIDENCE.json) · [Acceptance](ACCEPTANCE.en-US.md). The original file hash is recorded; the unreviewed original is not shipped as an operational alternative.
