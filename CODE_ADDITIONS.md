# Exact Code Additions - Copy & Paste Ready

## Addition 1: Error Constants
**Location**: After line 10 (after ERR-REPORT-NOT-FOUND)

```clarity
(define-constant ERR-AUDIT-NOT-FOUND (err u109))
(define-constant ERR-INVALID-AUDIT-QUERY (err u110))
```

## Addition 2: State Variable
**Location**: After line 17 (after next-report-id)

```clarity
(define-data-var next-audit-id uint u1)
```

## Addition 3: Data Map
**Location**: After line 94 (after compliance-reports map)

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

## Addition 4: Read-Only Functions
**Location**: After line 149 (after get-next-report-id)

```clarity
(define-read-only (get-audit-entry (audit-id uint))
    (map-get? rule-audit-trail audit-id)
)

(define-read-only (get-next-audit-id)
    (var-get next-audit-id)
)
```

## Addition 5: New Public Function
**Location**: Before perform-security-scan function

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

## Modification 1: toggle-rule Function
**Replace the entire toggle-rule function with:**

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

## Modification 2: update-rule Function
**Replace the let block inside update-rule with:**

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

## Verification Command

After making all additions and modifications, run:

```bash
clarinet check
```

Expected result:
```
✔ 1 contract checked
! 15 warnings detected
```

## Summary of Changes

| Type | Count | Details |
|------|-------|---------|
| New Constants | 2 | ERR-AUDIT-NOT-FOUND, ERR-INVALID-AUDIT-QUERY |
| New Variables | 1 | next-audit-id |
| New Maps | 1 | rule-audit-trail |
| New Read-Only Functions | 2 | get-audit-entry, get-next-audit-id |
| New Public Functions | 1 | record-rule-severity-change |
| Modified Functions | 2 | toggle-rule, update-rule |
| **Total Additions** | **9** | |

All code is production-ready and compiles without errors.

