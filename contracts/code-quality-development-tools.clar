(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-RULE (err u101))
(define-constant ERR-RULE-EXISTS (err u102))
(define-constant ERR-RULE-NOT-FOUND (err u103))
(define-constant ERR-INVALID-SCORE (err u104))
(define-constant ERR-SCAN-NOT-FOUND (err u105))

(define-data-var next-rule-id uint u1)
(define-data-var next-scan-id uint u1)

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
            (map-set linting-rules rule-id 
                (merge rule-data {enabled: (not (get enabled rule-data))}))
            (ok true)
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
            
            (map-set linting-rules rule-id {
                name: name,
                description: description,
                severity: severity,
                category: category,
                enabled: (get enabled rule-data),
                created-by: (get created-by rule-data)
            })
            (ok true)
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
