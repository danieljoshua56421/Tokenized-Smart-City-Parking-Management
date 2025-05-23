;; Payment Processing Contract
;; Handles automated fee collection for parking

(define-data-var admin principal tx-sender)
(define-data-var treasury principal tx-sender)

;; Define the fungible token for payments
(define-fungible-token parking-token)

;; Data structure for payment records
(define-map payment-records
  { payment-id: uint }
  {
    user: principal,
    space-id: uint,
    amount: uint,
    timestamp: uint,
    payment-type: (string-ascii 20), ;; "reservation", "hourly", "penalty"
    reservation-id: (optional uint)
  }
)

;; Counter for payment IDs
(define-data-var payment-id-counter uint u0)

;; Space rates mapping
(define-map space-rates
  { space-id: uint }
  { hourly-rate: uint }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INSUFFICIENT-FUNDS u101)
(define-constant ERR-PAYMENT-NOT-FOUND u102)
(define-constant ERR-SPACE-NOT-FOUND u103)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Set hourly rate for a space
(define-public (set-hourly-rate (space-id uint) (rate uint))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (map-set space-rates
      { space-id: space-id }
      { hourly-rate: rate }
    )
    (ok true)
  )
)

;; Get hourly rate for a space
(define-read-only (get-hourly-rate (space-id uint))
  (default-to { hourly-rate: u0 } (map-get? space-rates { space-id: space-id }))
)

;; Process payment for parking
(define-public (process-payment
                (space-id uint)
                (amount uint)
                (payment-type (string-ascii 20))
                (reservation-id (optional uint)))
  (let ((new-id (+ (var-get payment-id-counter) u1))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))

    ;; Transfer tokens from user to treasury
    (try! (ft-transfer? parking-token amount tx-sender (var-get treasury)))

    ;; Record the payment
    (map-set payment-records
      { payment-id: new-id }
      {
        user: tx-sender,
        space-id: space-id,
        amount: amount,
        timestamp: current-time,
        payment-type: payment-type,
        reservation-id: reservation-id
      }
    )

    (var-set payment-id-counter new-id)
    (ok new-id)
  )
)

;; Calculate parking fee based on duration
(define-read-only (calculate-fee (space-id uint) (duration uint))
  (let ((rate (get hourly-rate (get-hourly-rate space-id))))
    (* rate duration)
  )
)

;; Get payment record
(define-read-only (get-payment (payment-id uint))
  (map-get? payment-records { payment-id: payment-id })
)

;; Mint tokens (admin only, for testing)
(define-public (mint-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (ft-mint? parking-token amount recipient)
  )
)

;; Set treasury address
(define-public (set-treasury (new-treasury principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set treasury new-treasury)
    (ok true)
  )
)

;; Transfer admin rights
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
