# Complete Code Reference - Rule Severity Escalation & Audit Trail

## All New Code Added to Contract

### 1. Error Constants (Lines 11-12)
```clarity
(define-constant ERR-AUDIT-NOT-FOUND (err u109))
(define-constant ERR-INVALID-AUDIT-QUERY (err u110))
```

### 2. State Variable (Line 18)
```clarity
(define-data-var next-audit-id uint u1)
```

### 3. Data Structure (Lines 96-109)
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

### 4. Read-Only Functions (Lines 151-157)
```clarity
(define-read-only (get-audit-entry (audit-id uint))
    (map-get? rule-audit-trail audit-id)
)

(define-read-only (get-next-audit-id)
    (var-get next-audit-id)
)
```

### 5. New Public Function (Lines 231-265)
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

### 6. Enhanced toggle-rule Function (Lines 199-229)
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

### 7. Enhanced update-rule Function (Lines 331-365)
Key addition within the function:
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

## Variable Definitions

All variables are clearly defined before use:

| Variable | Type | Scope | Purpose |
|----------|------|-------|---------|
| `audit-id` | uint | Local (let) | Current audit entry ID |
| `old-enabled` | bool | Local (let) | Previous enabled state |
| `new-enabled` | bool | Local (let) | Updated enabled state |
| `old-severity` | string-ascii 10 | Local (let) | Previous severity level |
| `rule-data` | tuple | Match binding | Retrieved rule data |
| `tx-sender` | principal | Built-in | Transaction sender |
| `stacks-block-height` | uint | Built-in | Current block height |

## Compilation Result

```
✔ 1 contract checked
! 15 warnings detected (pre-existing, unchecked data)
```

All new code compiles without errors.

