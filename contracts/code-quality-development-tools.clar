(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-RULE (err u101))
(define-constant ERR-RULE-EXISTS (err u102))
(define-constant ERR-RULE-NOT-FOUND (err u103))
(define-constant ERR-INVALID-SCORE (err u104))
(define-constant ERR-SCAN-NOT-FOUND (err u105))
(define-constant ERR-FRAMEWORK-NOT-FOUND (err u106))
(define-constant ERR-INVALID-FRAMEWORK (err u107))
(define-constant ERR-REPORT-NOT-FOUND (err u108))
(define-constant ERR-AUDIT-NOT-FOUND (err u109))
(define-constant ERR-INVALID-AUDIT-QUERY (err u110))

(define-data-var next-rule-id uint u1)
(define-data-var next-scan-id uint u1)
(define-data-var next-framework-id uint u1)
(define-data-var next-report-id uint u1)
(define-data-var next-audit-id uint u1)

(define-map linting-rules
    uint
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        severity: (string-ascii 10),
        category: (string-ascii 20),
        enabled: bool,
        created-by: principal
    }
)

(define-map scan-results
    uint
    {
        contract-address: principal,
        total-issues: uint,
        critical-issues: uint,
        high-issues: uint,
        medium-issues: uint,
        low-issues: uint,
        quality-score: uint,
        scan-timestamp: uint,
        scanned-by: principal
    }
)

(define-map rule-violations
    {scan-id: uint, rule-id: uint}
    {
        line-number: uint,
        column-number: uint,
        message: (string-ascii 200),
        suggestion: (string-ascii 200)
    }
)

(define-map user-stats
    principal
    {
        total-scans: uint,
        rules-created: uint,
        average-quality-score: uint,
        last-scan-timestamp: uint
    }
)

(define-map compliance-frameworks
    uint
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        version: (string-ascii 10),
        categories: (list 10 (string-ascii 20)),
        min-score-threshold: uint,
        created-by: principal,
        active: bool
    }
)

(define-map compliance-reports
    uint
    {
        framework-id: uint,
        scan-id: uint,
        contract-address: principal,
        compliance-score: uint,
        passed-checks: uint,
        failed-checks: uint,
        total-checks: uint,
        certification-level: (string-ascii 20),
        report-timestamp: uint,
        generated-by: principal
    }
)

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

(define-read-only (get-rule (rule-id uint))
    (map-get? linting-rules rule-id)
)

(define-read-only (get-scan-result (scan-id uint))
    (map-get? scan-results scan-id)
)

(define-read-only (get-rule-violation (scan-id uint) (rule-id uint))
    (map-get? rule-violations {scan-id: scan-id, rule-id: rule-id})
)

(define-read-only (get-user-stats (user principal))
    (map-get? user-stats user)
)

(define-read-only (get-next-rule-id)
    (var-get next-rule-id)
)

(define-read-only (get-next-scan-id)
    (var-get next-scan-id)
)

(define-read-only (get-compliance-framework (framework-id uint))
    (map-get? compliance-frameworks framework-id)
)

(define-read-only (get-compliance-report (report-id uint))
    (map-get? compliance-reports report-id)
)

(define-read-only (get-next-framework-id)
    (var-get next-framework-id)
)

(define-read-only (get-next-report-id)
    (var-get next-report-id)
)

(define-read-only (get-audit-entry (audit-id uint))
    (map-get? rule-audit-trail audit-id)
)

(define-read-only (get-next-audit-id)
    (var-get next-audit-id)
)

(define-public (create-linting-rule 
    (name (string-ascii 50))
    (description (string-ascii 200))
    (severity (string-ascii 10))
    (category (string-ascii 20)))
    (let ((rule-id (var-get next-rule-id)))
        (asserts! (> (len name) u0) ERR-INVALID-RULE)
        (asserts! (> (len description) u0) ERR-INVALID-RULE)
        (asserts! (or (is-eq severity "critical") 
                      (is-eq severity "high") 
                      (is-eq severity "medium") 
                      (is-eq severity "low")) ERR-INVALID-RULE)
        
        (map-set linting-rules rule-id {
            name: name,
            description: description,
            severity: severity,
            category: category,
            enabled: true,
            created-by: tx-sender
        })
        
        (var-set next-rule-id (+ rule-id u1))
        
        (match (map-get? user-stats tx-sender)
            existing-stats
            (map-set user-stats tx-sender 
                (merge existing-stats {rules-created: (+ (get rules-created existing-stats) u1)}))
            (map-set user-stats tx-sender {
                total-scans: u0,
                rules-created: u1,
                average-quality-score: u0,
                last-scan-timestamp: u0
            })
        )
        
        (ok rule-id)
    )
)

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

(define-public (perform-security-scan
    (contract-address principal)
    (total-issues uint)
    (critical-issues uint)
    (high-issues uint)
    (medium-issues uint)
    (low-issues uint))
    (let ((scan-id (var-get next-scan-id))
          (quality-score (calculate-quality-score total-issues critical-issues high-issues)))
        
        (asserts! (<= (+ critical-issues high-issues medium-issues low-issues) total-issues) ERR-INVALID-SCORE)
        (asserts! (<= quality-score u100) ERR-INVALID-SCORE)
        
        (map-set scan-results scan-id {
            contract-address: contract-address,
            total-issues: total-issues,
            critical-issues: critical-issues,
            high-issues: high-issues,
            medium-issues: medium-issues,
            low-issues: low-issues,
            quality-score: quality-score,
            scan-timestamp: stacks-block-height,
            scanned-by: tx-sender
        })
        
        (var-set next-scan-id (+ scan-id u1))
        
        (update-user-stats tx-sender quality-score)
        
        (ok scan-id)
    )
)

(define-public (add-rule-violation 
    (scan-id uint)
    (rule-id uint)
    (line-number uint)
    (column-number uint)
    (message (string-ascii 200))
    (suggestion (string-ascii 200)))
    (begin
        (asserts! (is-some (map-get? scan-results scan-id)) ERR-SCAN-NOT-FOUND)
        (asserts! (is-some (map-get? linting-rules rule-id)) ERR-RULE-NOT-FOUND)
        (asserts! (> (len message) u0) ERR-INVALID-RULE)
        
        (let ((scan-data (unwrap! (map-get? scan-results scan-id) ERR-SCAN-NOT-FOUND)))
            (asserts! (is-eq tx-sender (get scanned-by scan-data)) ERR-NOT-AUTHORIZED)
        )
        
        (map-set rule-violations {scan-id: scan-id, rule-id: rule-id} {
            line-number: line-number,
            column-number: column-number,
            message: message,
            suggestion: suggestion
        })
        
        (ok true)
    )
)

(define-public (update-rule
    (rule-id uint)
    (name (string-ascii 50))
    (description (string-ascii 200))
    (severity (string-ascii 10))
    (category (string-ascii 20)))
    (match (map-get? linting-rules rule-id)
        rule-data
        (begin
            (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                         (is-eq tx-sender (get created-by rule-data))) ERR-NOT-AUTHORIZED)
            (asserts! (> (len name) u0) ERR-INVALID-RULE)
            (asserts! (> (len description) u0) ERR-INVALID-RULE)
            (asserts! (or (is-eq severity "critical")
                          (is-eq severity "high")
                          (is-eq severity "medium")
                          (is-eq severity "low")) ERR-INVALID-RULE)

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
        )
        ERR-RULE-NOT-FOUND
    )
)

(define-read-only (get-quality-grade (score uint))
    (if (>= score u90) "A"
        (if (>= score u80) "B"
            (if (>= score u70) "C"
                (if (>= score u60) "D"
                    "F"
                )
            )
        )
    )
)

(define-read-only (get-rules-by-category (category (string-ascii 20)))
    (let ((rule-ids (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)))
        (filter is-category-match 
            (map get-rule-with-id rule-ids)
        )
    )
)

(define-private (calculate-quality-score (total-issues uint) (critical-issues uint) (high-issues uint))
    (let ((base-score u100)
          (critical-penalty (* critical-issues u20))
          (high-penalty (* high-issues u10))
          (other-penalty (* (- total-issues (+ critical-issues high-issues)) u2)))
        (if (> (+ critical-penalty high-penalty other-penalty) base-score)
            u0
            (- base-score (+ critical-penalty high-penalty other-penalty))
        )
    )
)

(define-private (update-user-stats (user principal) (quality-score uint))
    (match (map-get? user-stats user)
        existing-stats
        (let ((new-total-scans (+ (get total-scans existing-stats) u1))
              (current-avg (get average-quality-score existing-stats))
              (new-avg (/ (+ (* current-avg (get total-scans existing-stats)) quality-score) new-total-scans)))
            (map-set user-stats user {
                total-scans: new-total-scans,
                rules-created: (get rules-created existing-stats),
                average-quality-score: new-avg,
                last-scan-timestamp: stacks-block-height
            })
        )
        (map-set user-stats user {
            total-scans: u1,
            rules-created: u0,
            average-quality-score: quality-score,
            last-scan-timestamp: stacks-block-height
        })
    )
)

(define-private (is-category-match (rule-option (optional {rule-id: uint, data: (optional {name: (string-ascii 50), description: (string-ascii 200), severity: (string-ascii 10), category: (string-ascii 20), enabled: bool, created-by: principal})})))
    (match rule-option
        rule-info
        (match (get data rule-info)
            rule-data
            (is-eq (get category rule-data) "security")
            false
        )
        false
    )
)

(define-private (get-rule-with-id (rule-id uint))
    (some {rule-id: rule-id, data: (map-get? linting-rules rule-id)})
)

(define-public (create-compliance-framework
    (name (string-ascii 50))
    (description (string-ascii 200))
    (version (string-ascii 10))
    (categories (list 10 (string-ascii 20)))
    (min-score-threshold uint))
    (let ((framework-id (var-get next-framework-id)))
        (asserts! (> (len name) u0) ERR-INVALID-FRAMEWORK)
        (asserts! (> (len description) u0) ERR-INVALID-FRAMEWORK)
        (asserts! (> (len version) u0) ERR-INVALID-FRAMEWORK)
        (asserts! (<= min-score-threshold u100) ERR-INVALID-FRAMEWORK)
        
        (map-set compliance-frameworks framework-id {
            name: name,
            description: description,
            version: version,
            categories: categories,
            min-score-threshold: min-score-threshold,
            created-by: tx-sender,
            active: true
        })
        
        (var-set next-framework-id (+ framework-id u1))
        (ok framework-id)
    )
)

(define-public (generate-compliance-report
    (framework-id uint)
    (scan-id uint)
    (passed-checks uint)
    (failed-checks uint))
    (let ((report-id (var-get next-report-id))
          (total-checks (+ passed-checks failed-checks))
          (compliance-score (calculate-compliance-score passed-checks total-checks)))
        
        (asserts! (is-some (map-get? compliance-frameworks framework-id)) ERR-FRAMEWORK-NOT-FOUND)
        (asserts! (is-some (map-get? scan-results scan-id)) ERR-SCAN-NOT-FOUND)
        (asserts! (> total-checks u0) ERR-INVALID-SCORE)
        
        (let ((framework-data (unwrap! (map-get? compliance-frameworks framework-id) ERR-FRAMEWORK-NOT-FOUND))
              (scan-data (unwrap! (map-get? scan-results scan-id) ERR-SCAN-NOT-FOUND))
              (certification-level (get-certification-level compliance-score (get min-score-threshold framework-data))))
            
            (map-set compliance-reports report-id {
                framework-id: framework-id,
                scan-id: scan-id,
                contract-address: (get contract-address scan-data),
                compliance-score: compliance-score,
                passed-checks: passed-checks,
                failed-checks: failed-checks,
                total-checks: total-checks,
                certification-level: certification-level,
                report-timestamp: stacks-block-height,
                generated-by: tx-sender
            })
            
            (var-set next-report-id (+ report-id u1))
            (ok report-id)
        )
    )
)

(define-public (toggle-framework (framework-id uint))
    (match (map-get? compliance-frameworks framework-id)
        framework-data
        (begin
            (asserts! (or (is-eq tx-sender CONTRACT-OWNER) 
                         (is-eq tx-sender (get created-by framework-data))) ERR-NOT-AUTHORIZED)
            (map-set compliance-frameworks framework-id 
                (merge framework-data {active: (not (get active framework-data))}))
            (ok true)
        )
        ERR-FRAMEWORK-NOT-FOUND
    )
)

(define-read-only (get-compliance-status (report-id uint))
    (match (map-get? compliance-reports report-id)
        report-data
        (let ((compliance-score (get compliance-score report-data))
              (certification-level (get certification-level report-data)))
            (ok {
                score: compliance-score,
                level: certification-level,
                passed: (> compliance-score u0),
                excellence: (>= compliance-score u95)
            })
        )
        ERR-REPORT-NOT-FOUND
    )
)

(define-read-only (get-framework-compliance-history (framework-id uint) (contract-address principal))
    (let ((report-ids (list u1 u2 u3 u4 u5)))
        (filter is-framework-contract-match
            (map get-report-with-id report-ids)
        )
    )
)

(define-private (calculate-compliance-score (passed-checks uint) (total-checks uint))
    (if (is-eq total-checks u0)
        u0
        (/ (* passed-checks u100) total-checks)
    )
)

(define-private (get-certification-level (score uint) (threshold uint))
    (if (>= score u95) "platinum"
        (if (>= score u85) "gold"
            (if (>= score u75) "silver"
                (if (>= score threshold) "bronze"
                    "uncertified"
                )
            )
        )
    )
)

(define-private (is-framework-contract-match (report-option (optional {report-id: uint, data: (optional {framework-id: uint, scan-id: uint, contract-address: principal, compliance-score: uint, passed-checks: uint, failed-checks: uint, total-checks: uint, certification-level: (string-ascii 20), report-timestamp: uint, generated-by: principal})})))
    (match report-option
        report-info
        (match (get data report-info)
            report-data
            true
            false
        )
        false
    )
)

(define-private (get-report-with-id (report-id uint))
    (some {report-id: report-id, data: (map-get? compliance-reports report-id)})
)

(define-private (process-violation-entry (entry {scan-id: uint, rule-id: uint, line-number: uint, column-number: uint, message: (string-ascii 200), suggestion: (string-ascii 200)}))
    (let ((scan-id (get scan-id entry))
          (rule-id (get rule-id entry))
          (line-number (get line-number entry))
          (column-number (get column-number entry))
          (message (get message entry))
          (suggestion (get suggestion entry)))
        (match (map-get? scan-results scan-id)
            scan-data
            (match (map-get? linting-rules rule-id)
                rule-data
                (if (and (> (len message) u0) (is-eq tx-sender (get scanned-by scan-data)))
                    (begin
                        (map-set rule-violations {scan-id: scan-id, rule-id: rule-id} {
                            line-number: line-number,
                            column-number: column-number,
                            message: message,
                            suggestion: suggestion
                        })
                        true
                    )
                    false
                )
                false
            )
            false
        )
    )
)

(define-private (is-true (b bool))
    b
)

(define-public (add-rule-violations-batch (entries (list 100 {scan-id: uint, rule-id: uint, line-number: uint, column-number: uint, message: (string-ascii 200), suggestion: (string-ascii 200)})))
    (let ((results (map process-violation-entry entries))
          (successes (filter is-true results)))
        (ok (len successes))
    )
)
