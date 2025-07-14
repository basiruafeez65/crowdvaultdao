;; ------------------------------------------------------------
;; Contract: stackscrowdsafe-v2
;; Purpose: Decentralized crowdfunding with refund guarantees
;; 🔹 Overview
;; ==============================
;; stackscrowdsafe-v2 enables decentralized crowdfunding on 
;; the Stacks blockchain. Campaign creators can raise funds
;; toward a goal before a deadline. If the goal is met, funds 
;; can be claimed. If not, contributors can request refunds.
;;
;; Additional admin and DAO-like controls are included for
;; campaign management and governance.

;; ==============================
;; 🔹 Key Features
;; ==============================
;; - Campaign creation with goal & deadline
;; - Contributions tracked per user
;; - Claim funds only if goal is reached
;; - Refunds if goal is not reached after deadline
;; - Admin controls: pause campaign, update deadline, cancel
;; - Data transparency with read-only queries

;; ==============================
;; 🔹 State Maps
;; ==============================
;; campaigns: 
;;   uint => {
;;     creator: principal,
;;     goal: uint,
;;     deadline: uint,
;;     raised: uint,
;;     claimed: bool,
;;     active: bool
;;   }

;; contributions: 
;;   { campaign-id: uint, contributor: principal } => uint

;; campaign-backers: 
;;   uint => (list 200 principal)

;; user-campaigns: 
;;   principal => (list 100 uint)

;; ==============================
;; 🔹 Core Functions
;; ==============================

;; create-campaign(goal uint, duration uint)
;; - Starts a new campaign by creator
;; - Returns campaign ID

;; contribute(id uint, amount uint)
;; - Sends STX to a campaign
;; - Updates raised amount & contributor records

;; claim-funds(id uint)
;; - Allows creator to withdraw funds if goal is met

;; refund(id uint)
;; - Allows contributors to withdraw if campaign fails

;; pause-campaign(id uint)
;; - Admin-only: disables new contributions

;; update-deadline(id uint, extra-blocks uint)
;; - Creator-only: extends campaign deadline

;; cancel-campaign(id uint)
;; - Creator-only: disables a campaign manually
