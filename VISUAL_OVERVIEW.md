# Visual Overview - Rule Severity Escalation & Audit Trail

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Smart Contract System                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Linting Rules Management                    │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ create-linting-rule                                │  │   │
│  │  │ update-rule ──────────────────┐                    │  │   │
│  │  │ toggle-rule ──────────────────┤                    │  │   │
│  │  │ get-rule                      │                    │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                       │
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         NEW: Rule Audit Trail System                     │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ record-rule-severity-change                        │  │   │
│  │  │ get-audit-entry                                    │  │   │
│  │  │ get-next-audit-id                                  │  │   │
│  │  │                                                    │  │   │
│  │  │ Auto-auditing:                                     │  │   │
│  │  │ • toggle-rule → audit entry                        │  │   │
│  │  │ • update-rule → audit entry                        │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                       │
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         Immutable Audit Trail Storage                    │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ rule-audit-trail Map                               │  │   │
│  │  │ • audit-id → audit entry                           │  │   │
│  │  │ • Immutable once written                           │  │   │
│  │  │ • Cryptographic timestamps (block height)          │  │   │
│  │  │ • Complete change history                          │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
User Action
    │
    ├─► toggle-rule(rule-id)
    │       │
    │       ├─► Validate authorization
    │       ├─► Toggle enabled state
    │       ├─► Create audit entry
    │       │   ├─ rule-id
    │       │   ├─ action: "toggle"
    │       │   ├─ previous-enabled
    │       │   ├─ new-enabled
    │       │   ├─ changed-by: tx-sender
    │       │   ├─ change-timestamp: block-height
    │       │   └─ change-reason: "rule-toggled"
    │       ├─► Store in rule-audit-trail
    │       └─► Increment next-audit-id
    │
    ├─► update-rule(rule-id, name, description, severity, category)
    │       │
    │       ├─► Validate authorization
    │       ├─► Validate inputs
    │       ├─► Update rule
    │       ├─► Create audit entry
    │       │   ├─ rule-id
    │       │   ├─ action: "update"
    │       │   ├─ previous-severity
    │       │   ├─ new-severity
    │       │   ├─ changed-by: tx-sender
    │       │   ├─ change-timestamp: block-height
    │       │   └─ change-reason: "rule-updated"
    │       ├─► Store in rule-audit-trail
    │       └─► Increment next-audit-id
    │
    └─► record-rule-severity-change(rule-id, prev-sev, new-sev, reason)
            │
            ├─► Validate authorization
            ├─► Validate severity values
            ├─► Create audit entry
            │   ├─ rule-id
            │   ├─ action: "severity-change"
            │   ├─ previous-severity
            │   ├─ new-severity
            │   ├─ changed-by: tx-sender
            │   ├─ change-timestamp: block-height
            │   └─ change-reason: (provided)
            ├─► Store in rule-audit-trail
            ├─► Increment next-audit-id
            └─► Return audit-id
```

## Audit Entry Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    Audit Entry (Immutable)                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  rule-id: uint                                              │
│  └─ Identifies which rule was modified                      │
│                                                              │
│  action: string-ascii 20                                    │
│  └─ Type of change: "toggle" | "update" | "severity-change"│
│                                                              │
│  previous-severity: string-ascii 10                         │
│  └─ Prior severity: "critical" | "high" | "medium" | "low" │
│                                                              │
│  new-severity: string-ascii 10                              │
│  └─ Updated severity: "critical" | "high" | "medium" | "low"│
│                                                              │
│  previous-enabled: bool                                     │
│  └─ Was rule enabled before change?                         │
│                                                              │
│  new-enabled: bool                                          │
│  └─ Is rule enabled after change?                           │
│                                                              │
│  changed-by: principal                                      │
│  └─ User who made the change (tx-sender)                    │
│                                                              │
│  change-timestamp: uint                                     │
│  └─ Block height when change occurred (cryptographic proof) │
│                                                              │
│  change-reason: string-ascii 100                            │
│  └─ Human-readable reason for the change                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Feature Integration Points

```
Existing Contract Functions
        │
        ├─► create-linting-rule
        │   └─ No changes (creates new rules)
        │
        ├─► toggle-rule ◄─── ENHANCED
        │   └─ Now records audit entry
        │
        ├─► update-rule ◄─── ENHANCED
        │   └─ Now records audit entry
        │
        ├─► perform-security-scan
        │   └─ No changes (scans contracts)
        │
        ├─► add-rule-violation
        │   └─ No changes (records violations)
        │
        ├─► create-compliance-framework
        │   └─ No changes (creates frameworks)
        │
        ├─► generate-compliance-report
        │   └─ No changes (generates reports)
        │
        └─► toggle-framework
            └─ No changes (toggles frameworks)

New Functions
        │
        ├─► record-rule-severity-change (NEW)
        │   └─ Explicitly record severity changes
        │
        ├─► get-audit-entry (NEW)
        │   └─ Query specific audit entries
        │
        └─► get-next-audit-id (NEW)
            └─ Get next available audit ID
```

## Use Case Flows

### Use Case 1: Security Vulnerability Response
```
1. Security team discovers vulnerability
2. Call: record-rule-severity-change(
     rule-id: u5,
     previous-severity: "medium",
     new-severity: "critical",
     change-reason: "CVE-2025-XXXXX-discovered"
   )
3. Audit entry created with:
   - Changed-by: security-team-principal
   - Change-timestamp: block-height
   - Complete change history preserved
4. Developers can query: get-audit-entry(audit-id)
5. Compliance team has permanent record
```

### Use Case 2: Rule Lifecycle Management
```
1. Developer creates rule: create-linting-rule(...)
2. Rule is tested and refined: update-rule(...)
   └─ Audit entry: action="update"
3. Rule is enabled: toggle-rule(...)
   └─ Audit entry: action="toggle", new-enabled=true
4. Later, rule is disabled: toggle-rule(...)
   └─ Audit entry: action="toggle", new-enabled=false
5. Complete history available for review
```

### Use Case 3: Compliance Audit
```
1. Auditor requests rule change history
2. Query: get-audit-entry(u0), get-audit-entry(u1), ...
3. Retrieve complete audit trail with:
   - Who made changes
   - When changes occurred (block height)
   - Why changes were made (reason)
   - What changed (severity, enabled state)
4. Generate compliance report with immutable evidence
```

## State Transitions

```
Rule State Transitions with Audit Trail

┌─────────────────────────────────────────────────────────────┐
│                    Rule Lifecycle                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Created                                                    │
│    │                                                        │
│    ├─► Updated ──────────────────► Audit Entry Created     │
│    │   (severity, name, etc.)      (action: "update")      │
│    │                                                        │
│    ├─► Toggled ──────────────────► Audit Entry Created     │
│    │   (enabled/disabled)          (action: "toggle")      │
│    │                                                        │
│    └─► Severity Changed ─────────► Audit Entry Created     │
│        (low→critical)              (action: "severity-change")
│                                                              │
│  All changes immutably recorded with:                       │
│  • Who made the change                                      │
│  • When it happened (block height)                          │
│  • Why it happened (reason)                                 │
│  • What changed (before/after states)                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Benefits Summary

```
┌──────────────────────────────────────────────────────────────┐
│                    Key Benefits                              │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ✅ Accountability                                            │
│     Every change attributed to specific user                 │
│                                                               │
│  ✅ Transparency                                              │
│     Complete history of rule modifications                   │
│                                                               │
│  ✅ Compliance                                                │
│     Immutable records for regulatory audits                  │
│                                                               │
│  ✅ Traceability                                              │
│     Understand why rules evolved                             │
│                                                               │
│  ✅ Governance                                                │
│     Track authorization and control                          │
│                                                               │
│  ✅ Incident Response                                         │
│     Reference changes during security events                 │
│                                                               │
│  ✅ Trend Analysis                                            │
│     Identify patterns in rule severity                       │
│                                                               │
│  ✅ Developer Experience                                      │
│     Understand rule changes and rationale                    │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

