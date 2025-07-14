;; ------------------------------------------------------------
;; Contract: stackscrowdsafe-v2
;; Purpose: Decentralized crowdfunding with refund guarantees & extended DAO features
;; Author: [Your Name]
;; License: MIT
;; ------------------------------------------------------------

;; === Constants ===
(define-constant ERR_NOT_FOUND (err u100))
(define-constant ERR_UNAUTHORIZED (err u101))
(define-constant ERR_ALREADY_CLAIMED (err u102))
(define-constant ERR_TOO_EARLY (err u103))
(define-constant ERR_GOAL_NOT_REACHED (err u104))
(define-constant ERR_ALREADY_REFUNDED (err u105))
(define-constant ERR_CAMPAIGN_ACTIVE (err u106))
(define-constant ERR_DEADLINE_PASSED (err u107))
(define-constant ERR_INVALID_AMOUNT (err u108))
(define-constant ERR_TRANSFER_FAILED (err u109))
(define-constant ERR_CAMPAIGN_PAUSED (err u110))

(define-data-var next-id uint u1)
(define-data-var admin principal tx-sender)

;; === Structures ===
(define-map campaigns
  uint
  {
    creator: principal,
    goal: uint,
    deadline: uint,
    raised: uint,
    claimed: bool,
    active: bool
  }
)

(define-map contributions
  { campaign-id: uint, contributor: principal }
  uint
)

(define-map campaign-backers
  uint
  (list 200 principal)
)

(define-map user-campaigns
  principal
  (list 100 uint)
)

;; === Utility ===
(define-read-only (get-current-block-height)
  stacks-block-height
)

(define-private (or-bool (accum bool) (item bool)) (or accum item))

;; === Create Campaign ===
(define-public (create-campaign (goal uint) (duration uint))
  (let 
    (
      (id (var-get next-id))
      (creator tx-sender)
      (deadline (+ (get-current-block-height) duration))
    )
    (begin
      (asserts! (> goal u0) ERR_INVALID_AMOUNT)
      (asserts! (> duration u0) ERR_INVALID_AMOUNT)
      (map-set campaigns id {
        creator: creator,
        goal: goal,
        deadline: deadline,
        raised: u0,
        claimed: false,
        active: true
      })
      (let ((current-list (default-to (list) (map-get? user-campaigns creator))))
        (if (is-eq (len current-list) u0)
            (map-set user-campaigns creator (list id))
            false))
      (var-set next-id (+ id u1))
      (ok id)
    )
  )
)

;; === Contribute ===
(define-public (contribute (id uint) (amount uint))
  (let ((sender tx-sender))
    (match (map-get? campaigns id)
      campaign
      (begin
        (asserts! (get active campaign) ERR_CAMPAIGN_PAUSED)
        (asserts! (< (get-current-block-height) (get deadline campaign)) ERR_DEADLINE_PASSED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)

        (unwrap! (stx-transfer? amount sender (as-contract tx-sender)) ERR_TRANSFER_FAILED)

        (map-set campaigns id {
          creator: (get creator campaign),
          goal: (get goal campaign),
          deadline: (get deadline campaign),
          raised: (+ (get raised campaign) amount),
          claimed: (get claimed campaign),
          active: true
        })

        (map-set contributions { campaign-id: id, contributor: sender }
                 (+ amount (default-to u0 (map-get? contributions { campaign-id: id, contributor: sender }))))

        ;; Just append sender to backers (duplicates possible, but avoids lambda/interdependent errors)
        (let ((backers (default-to (list) (map-get? campaign-backers id))))
          (if (is-eq (len backers) u0)
              (map-set campaign-backers id (list sender))
              false))
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

;; === Claim Funds ===
(define-public (claim-funds (id uint))
  (match (map-get? campaigns id)
    campaign
    (begin
      (asserts! (is-eq (get creator campaign) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (>= (get raised campaign) (get goal campaign)) ERR_GOAL_NOT_REACHED)
      (asserts! (not (get claimed campaign)) ERR_ALREADY_CLAIMED)

      (map-set campaigns id {
        creator: (get creator campaign),
        goal: (get goal campaign),
        deadline: (get deadline campaign),
        raised: (get raised campaign),
        claimed: true,
        active: false
      })

      (unwrap! (as-contract (stx-transfer? (get raised campaign) tx-sender tx-sender)) ERR_TRANSFER_FAILED)
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; === Refund Contributor ===
(define-public (refund (id uint))
  (let ((sender tx-sender))
    (match (map-get? campaigns id)
      campaign
      (begin
        (asserts! (> (get-current-block-height) (get deadline campaign)) ERR_CAMPAIGN_ACTIVE)
        (asserts! (< (get raised campaign) (get goal campaign)) ERR_GOAL_NOT_REACHED)
        (match (map-get? contributions { campaign-id: id, contributor: sender })
          user-amount
          (begin
            (asserts! (> user-amount u0) ERR_ALREADY_REFUNDED)
            (map-delete contributions { campaign-id: id, contributor: sender })
            (unwrap! (as-contract (stx-transfer? user-amount tx-sender sender)) ERR_TRANSFER_FAILED)
            (ok true)
          )
          ERR_NOT_FOUND
        )
      )
      ERR_NOT_FOUND
    )
  )
)

;; === Campaign Admin Controls ===

(define-public (pause-campaign (id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set campaigns id (merge (unwrap! (map-get? campaigns id) ERR_NOT_FOUND) { active: false }))
    (ok true)
  )
)

(define-public (update-deadline (id uint) (extra-blocks uint))
  (match (map-get? campaigns id)
    campaign
    (begin
      (asserts! (is-eq tx-sender (get creator campaign)) ERR_UNAUTHORIZED)
      (asserts! (< (get-current-block-height) (get deadline campaign)) ERR_DEADLINE_PASSED)

      (map-set campaigns id {
        creator: (get creator campaign),
        goal: (get goal campaign),
        deadline: (+ (get deadline campaign) extra-blocks),
        raised: (get raised campaign),
        claimed: (get claimed campaign),
        active: true
      })
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-public (cancel-campaign (id uint))
  (match (map-get? campaigns id)
    campaign
    (begin
      (asserts! (is-eq tx-sender (get creator campaign)) ERR_UNAUTHORIZED)
      (map-set campaigns id (merge campaign { active: false }))
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; === Read-Only Queries ===

(define-read-only (get-campaign (id uint))
  (match (map-get? campaigns id)
    data (ok data)
    ERR_NOT_FOUND
  )
)

(define-read-only (get-contribution (id uint) (user principal))
  (ok (default-to u0 (map-get? contributions { campaign-id: id, contributor: user })))
)

(define-read-only (get-campaign-status (id uint))
  (match (map-get? campaigns id)
    campaign 
    (let (
      (current-block (get-current-block-height))
      (deadline (get deadline campaign))
      (goal-reached (>= (get raised campaign) (get goal campaign)))
      (is-active (and (get active campaign) (< current-block deadline)))
    )
      (ok {
        active: is-active,
        goal-reached: goal-reached,
        claimed: (get claimed campaign),
        blocks-remaining: (if is-active (- deadline current-block) u0)
      })
    )
    ERR_NOT_FOUND
  )
)

(define-read-only (get-campaign-count)
  (ok (- (var-get next-id) u1))
)

(define-read-only (get-campaign-backers (id uint))
  (ok (default-to (list) (map-get? campaign-backers id)))
)

(define-read-only (get-user-campaigns (user principal))
  (ok (default-to (list) (map-get? user-campaigns user)))
)

(define-read-only (get-campaign-stats (id uint))
  (match (map-get? campaigns id)
    campaign
    (ok {
      raised: (get raised campaign),
      goal: (get goal campaign),
      percent: (if (> (get goal campaign) u0)
                  (/ (* (get raised campaign) u100) (get goal campaign))
                  u0),
      backers: (len (default-to (list) (map-get? campaign-backers id)))
    })
    ERR_NOT_FOUND
  )
)
