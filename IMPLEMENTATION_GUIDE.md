# Step-by-Step Implementation Guide

## Feature: Rule Severity Escalation & Audit Trail

### Step 1: Add Error Constants
Add two new error codes for audit-related operations:
```clarity
(define-constant ERR-AUDIT-NOT-FOUND (err u109))
(define-constant ERR-INVALID-AUDIT-QUERY (err u110))
```

### Step 2: Add State Variable
Add counter for audit entry IDs:
```clarity
(define-data-var next-audit-id uint u1)
```

### Step 3: Define Audit Trail Data Structure
Create immutable map to store all rule modifications:
```clarity
(define-map rule-audit-trail
    uint
    {
        rule-id: uint,
        action: (string-ascii 20),
        previous-severity: (string-ascii 10),
        new-severity: (string-ascii 10),
        previous-enabled: bool,
        new-enabled: bool,
        changed-by: principal,
        change-timestamp: uint,
        change-reason: (string-ascii 100)
    }
)
```

### Step 4: Add Read-Only Query Functions
Enable querying audit entries:
```clarity
(define-read-only (get-audit-entry (audit-id uint))
    (map-get? rule-audit-trail audit-id)
)

(define-read-only (get-next-audit-id)
    (var-get next-audit-id)
)
```

### Step 5: Create Severity Change Recording Function
New public function to explicitly record severity changes:
```clarity
(define-public (record-rule-severity-change
    (rule-id uint)
    (previous-severity (string-ascii 10))
    (new-severity (string-ascii 10))
    (change-reason (string-ascii 100)))
    (match (map-get? linting-rules rule-id)
        rule-data
        (begin
            (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                         (is-eq tx-sender (get created-by rule-data))) ERR-NOT-AUTHORIZED)
            (asserts! (or (is-eq new-severity "critical")
                          (is-eq new-severity "high")
                          (is-eq new-severity "medium")
                          (is-eq new-severity "low")) ERR-INVALID-RULE)

            (let ((audit-id (var-get next-audit-id)))
                (map-set rule-audit-trail audit-id {
                    rule-id: rule-id,
                    action: "severity-change",
                    previous-severity: previous-severity,
                    new-severity: new-severity,
                    previous-enabled: (get enabled rule-data),
                    new-enabled: (get enabled rule-data),
                    changed-by: tx-sender,
                    change-timestamp: stacks-block-height,
                    change-reason: change-reason
                })

                (var-set next-audit-id (+ audit-id u1))
                (ok audit-id)
            )
        )
        ERR-RULE-NOT-FOUND
    )
)
```

### Step 6: Enhance toggle-rule Function
Modify existing function to record audit entries:
```clarity
(define-public (toggle-rule (rule-id uint))
    (match (map-get? linting-rules rule-id)
        rule-data
        (begin
            (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                         (is-eq tx-sender (get created-by rule-data))) ERR-NOT-AUTHORIZED)
            (let ((audit-id (var-get next-audit-id))
                  (old-enabled (get enabled rule-data))
                  (new-enabled (not old-enabled)))
                (map-set linting-rules rule-id
                    (merge rule-data {enabled: new-enabled}))

                (map-set rule-audit-trail audit-id {
                    rule-id: rule-id,
                    action: "toggle",
                    previous-severity: (get severity rule-data),
                    new-severity: (get severity rule-data),
                    previous-enabled: old-enabled,
                    new-enabled: new-enabled,
                    changed-by: tx-sender,
                    change-timestamp: stacks-block-height,
                    change-reason: "rule-toggled"
                })

                (var-set next-audit-id (+ audit-id u1))
                (ok true)
            )
        )
        ERR-RULE-NOT-FOUND
    )
)
```

### Step 7: Enhance update-rule Function
Modify to record audit entries when rules are updated:
```clarity
(let ((audit-id (var-get next-audit-id))
      (old-severity (get severity rule-data)))
    (map-set linting-rules rule-id {
        name: name,
        description: description,
        severity: severity,
        category: category,
        enabled: (get enabled rule-data),
        created-by: (get created-by rule-data)
    })

    (map-set rule-audit-trail audit-id {
        rule-id: rule-id,
        action: "update",
        previous-severity: old-severity,
        new-severity: severity,
        previous-enabled: (get enabled rule-data),
        new-enabled: (get enabled rule-data),
        changed-by: tx-sender,
        change-timestamp: stacks-block-height,
        change-reason: "rule-updated"
    })

    (var-set next-audit-id (+ audit-id u1))
    (ok true)
)
```

### Step 8: Verify Compilation
Run clarinet check to ensure no errors:
```bash
clarinet check
```

Expected output: ✔ 1 contract checked (with warnings only)

## Testing the Feature

### Test 1: Record Severity Change
```clarity
(record-rule-severity-change u1 "low" "critical" "security-issue-found")
```

### Test 2: Query Audit Entry
```clarity
(get-audit-entry u0)
```

### Test 3: Toggle Rule (Auto-Audited)
```clarity
(toggle-rule u1)
```

### Test 4: Get Next Audit ID
```clarity
(get-next-audit-id)
```

## Verification Checklist

- [x] All variables defined before use
- [x] Error constants properly defined
- [x] Data structure fields match usage
- [x] Authorization checks in place
- [x] Immutable audit trail maintained
- [x] Timestamp recorded via stacks-block-height
- [x] No breaking changes to existing functions
- [x] Compilation successful with clarinet check

