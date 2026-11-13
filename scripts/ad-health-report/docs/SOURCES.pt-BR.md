# Fontes oficiais e critérios — AD Health Report 1.2.0

FMODEL · F. Model · fmodel@fmodel.com.br

Consultadas em 13/11/2026. Os links fundamentam consultas e interpretação; não significam certificação, baseline completa ou validação em produção.

## W32TIME · Windows Time configuration

[Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings)

Preserve raw W32Time evidence and machine/policy registry values. Configuration and measured offset do not certify UTC accuracy.

## ADMIN500 · Role-specific built-in Administrator guidance

[Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-d--securing-built-in-administrator-accounts-in-active-directory)

Inventory rights by SID without a DC deny-right verdict. The cited deny-right recommendations target workstations/member servers.

## GPO-PERMISSIONS · Group Policy permissions

[Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gppermission?view=windowsserver2025-ps)

Read trustee permissions per GPO. Does not establish effective privilege across nested groups.

## AD-FEATURES · AD optional features

[Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adoptionalfeature?view=windowsserver2025-ps)

Feature GUID and EnabledScopes. Read-only observation; no activation.

## AD-SPN · SPN and UPN uniqueness

[Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/spn-and-upn-uniqueness)

Compare distinct object owners within exported scope. Not proof of forest-wide uniqueness with incomplete/domain-only collection.

## AD-UAC · Account flags

[Microsoft Learn](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/useraccountcontrol-manipulate-account-properties)

Decode documented UAC bits. Flags are configuration, not actual authentication/password contents.

## GPO · Group Policy XML report

[Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gporeport?view=windowsserver2025-ps)

Explicit Domain/Server/Guid; preserve XML. No claim of effective policy or conflict resolution.

## RSOP · Resultant Set of Policy

[Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gpresultantsetofpolicy?view=windowsserver2025-ps)

Computer-specific XML evidence. Requires target permissions; not effective privileges analysis.

## DNS-CONFIG · DNS server configuration

[Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/dnsserver/get-dnsserver?view=windowsserver2025-ps)

Inventory configuration without changing DNS. Recursion/forwarder/scavenging choices are architecture dependent.

## DNS-RECURSION · DNS recursion and forwarders

[Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/dns/quickstart-install-configure-dns-server)

Interpret configuration with server role. Disabling recursion also disables forwarders.

## BACKUP · AD partition backup evidence

[Microsoft Learn](https://learn.microsoft.com/en-us/services-hub/microsoft-engage-center/health/remediation-steps-ad/investigate-why-active-directory-directory-partitions-are-not-backed-up-for-longer-than-half-the-tom)

Read repadmin /showbackup output. No restoration test, RPO or component-coverage proof.

## HOTFIX · QFE inventory limits

[Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-hotfix?view=powershell-5.1)

Inventory QFE/KB evidence. Does not enumerate all update types or prove patch compliance.

## SECURITY-GUIDANCE · Microsoft Security Compliance Toolkit

[Microsoft Learn](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10)

Guide baseline selection and value comparison. Built-in selected guidance review is not a complete SCT baseline.

## SMB · SMB signing

[Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing)

Observe effective client/server signing requirement. Compatibility and approved exceptions require review.

## SPOOLER · Identity infrastructure security

[Microsoft Learn](https://learn.microsoft.com/en-us/defender-for-identity/security-posture-assessments/identity-infrastructure)

Separate Spooler security review. Stopped/Disabled is distinct from core AD services expected Running.

## LDAP · LDAP signing

[Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/identity/manage-ldap-signing-group-policy)

Selected LDAPServerIntegrity comparison. Absent registry value does not establish effective default.

## LDAP-CBT · LDAP channel binding

[Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/ldap-channel-binding)

Preserve channel binding configuration. No bind test or client compatibility certification.

## AUDIT · Audit policy query

[Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/auditpol-get)

Read CSV by subcategory GUID. Retain localized settings; no English pass/fail parser.

## EVENT-4624 · Successful logon event fields

[Microsoft Learn](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4624)

Use EventData LogonType rather than message text. Type 8 alone does not establish cleartext transmission.

## FUNCTIONAL-LEVELS · AD DS functional levels

[Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-functional-levels)

Separate OS/build from DFL/FFL. 2019/2022 OS does not imply 2019/2022 functional levels.

## Catálogo de valores selecionados

| RuleId | Registro / valor | Expected | Comparison |
|---|---|---|---|
| [LDAP-SIGNING](https://learn.microsoft.com/en-us/windows-server/identity/manage-ldap-signing-group-policy) | SYSTEM\CurrentControlSet\Services\NTDS\Parameters / LDAPServerIntegrity | 2 | EqualsAny |
| [LDAP-CBT](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/ldap-channel-binding) | SYSTEM\CurrentControlSet\Services\NTDS\Parameters / LdapEnforceChannelBinding | 2 | EqualsAny |
| [NO-LM-HASH](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-do-not-store-lan-manager-hash-value-on-next-password-change) | SYSTEM\CurrentControlSet\Control\Lsa / NoLMHash | 1 | EqualsAny |
| [NTLM-LEVEL](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-lan-manager-authentication-level) | SYSTEM\CurrentControlSet\Control\Lsa / LmCompatibilityLevel | 5 | EqualsAny |
| [NO-BLANK-REMOTE](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/accounts-limit-local-account-use-of-blank-passwords-to-console-logon-only) | SYSTEM\CurrentControlSet\Control\Lsa / LimitBlankPasswordUse | 1 | EqualsAny |
| [RESTRICT-SAM](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-access-do-not-allow-anonymous-enumeration-of-sam-accounts) | SYSTEM\CurrentControlSet\Control\Lsa / RestrictAnonymousSAM | 1 | EqualsAny / NotApplicableToDomainControllers |
| [NULL-SESSIONS](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-access-restrict-anonymous-access-to-named-pipes-and-shares) | SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters / RestrictNullSessAccess | 1 | EqualsAny |
| [UAC](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/user-account-control-run-all-administrators-in-admin-approval-mode) | SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System / EnableLUA | 1 | EqualsAny |
| [AUDIT-SUBCATEGORY](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/audit-force-audit-policy-subcategory-settings-to-override) | SYSTEM\CurrentControlSet\Control\Lsa / SCENoApplyLegacyAuditPolicy | 1 | EqualsAny |
| [PS-LOGGING](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_logging_windows?view=powershell-5.1) | SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging / EnableScriptBlockLogging | 1 | EqualsAny |
| [NTLM-MIN-CLIENT](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-minimum-session-security-for-ntlm-ssp-based-including-secure-rpc-clients) | SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0 / NTLMMinClientSec | 537395200 | ContainsBits |
| [NTLM-MIN-SERVER](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-minimum-session-security-for-ntlm-ssp-based-including-secure-rpc-servers) | SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0 / NTLMMinServerSec | 537395200 | ContainsBits |

Uma chave ausente não revela sozinha o default efetivo. Consulte o manual sobre tipo DWORD, limites de papel/versão, compatibilidade e o formato parcial de BaselineFile.

ADxRay e ALI TAJRAN foram referências de requisitos/comparação; as implementações novas são independentes. Créditos históricos e limitações permanecem nos manuais.

## OS-LIFECYCLE · Microsoft Lifecycle

[Microsoft Lifecycle](https://learn.microsoft.com/en-us/lifecycle/). Product references and regular end dates are used as review hints; AD OS attributes, editions, LTSC/LTSB, ESU and contracts require confirmation. Catalog checked 2026-11-13. No automatic unsupported verdict.
