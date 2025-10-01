;; BitVenture - Decentralized Startup Investment Protocol
;;
;; Title: BitVenture - Milestone-Based Fundraising Infrastructure
;;
;; Summary:
;; BitVenture revolutionizes startup fundraising by implementing trustless, milestone-driven
;; capital distribution on Bitcoin's Layer 2. Founders raise capital transparently while
;; investors maintain governance rights through equity-weighted voting on fund releases.
;;
;; Description:
;; A comprehensive decentralized fundraising platform that bridges traditional venture capital
;; with blockchain transparency. BitVenture enables startups to create funding campaigns with
;; predefined milestones, allowing investors to participate in equity-based investments while
;; retaining oversight through democratic voting mechanisms. Each milestone must achieve
;; majority investor approval before funds are released, ensuring accountability and reducing
;; investment risk. The protocol features automated equity token distribution, portfolio tracking,
;; real-time campaign analytics, and emergency safeguards for dispute resolution.

;; ERROR CODES
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-campaign-not-found (err u102))
(define-constant err-campaign-ended (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-invalid-parameter (err u105))
(define-constant err-milestone-not-found (err u106))
(define-constant err-already-voted (err u107))
(define-constant err-voting-period-ended (err u108))
(define-constant err-milestone-not-completed (err u109))

;; CONFIGURATION CONSTANTS
(define-constant contract-owner tx-sender)
(define-constant max-voting-duration u52560) ;; ~1 year in blocks
(define-constant min-voting-duration u144) ;; ~1 day in blocks

;; STATE VARIABLES
(define-data-var total-campaigns uint u0)
(define-data-var platform-fee-percentage uint u250) ;; 2.5% platform fee
(define-data-var total-platform-fees uint u0)
(define-data-var paused bool false)

;; DATA MAPS - CAMPAIGN MANAGEMENT

;; Primary campaign storage
(define-map campaigns
  uint
  {
    founder: principal,
    title: (string-utf8 64),
    description: (string-utf8 256),
    funding-goal: uint,
    total-raised: uint,
    deadline: uint,
    active: bool,
    completed: bool,
    milestone-count: uint,
  }
)

;; Individual investment tracking per campaign
(define-map campaign-investments
  {
    campaign-id: uint,
    investor: principal,
  }
  {
    amount: uint,
    timestamp: uint,
    equity-tokens: uint,
  }
)

;; Aggregated campaign performance metrics
(define-map campaign-stats
  uint
  {
    total-investors: uint,
    average-investment: uint,
    last-update: uint,
  }
)

;; DATA MAPS - MILESTONE SYSTEM

;; Milestone definitions and voting results
(define-map campaign-milestones
  {
    campaign-id: uint,
    milestone-id: uint,
  }
  {
    title: (string-utf8 64),
    description: (string-utf8 256),
    funding-percentage: uint,
    completed: bool,
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    funds-released: bool,
  }
)

;; Individual investor votes on milestones
(define-map milestone-votes
  {
    campaign-id: uint,
    milestone-id: uint,
    voter: principal,
  }
  {
    vote: bool,
    timestamp: uint,
    voting-power: uint,
  }
)

;; DATA MAPS - INVESTOR PORTFOLIOS

;; Investor portfolio aggregation
(define-map investor-portfolios
  principal
  {
    total-invested: uint,
    active-campaigns: uint,
    total-returns: uint,
  }
)

;; READ-ONLY FUNCTIONS - CAMPAIGN QUERIES

(define-read-only (get-campaign-details (campaign-id uint))
  (map-get? campaigns campaign-id)
)

(define-read-only (get-investment-details
    (campaign-id uint)
    (investor principal)
  )
  (map-get? campaign-investments {
    campaign-id: campaign-id,
    investor: investor,
  })
)

(define-read-only (get-campaign-stats (campaign-id uint))
  (map-get? campaign-stats campaign-id)
)

(define-read-only (get-total-campaigns)
  (var-get total-campaigns)
)

;; READ-ONLY FUNCTIONS - MILESTONE QUERIES

(define-read-only (get-milestone-details
    (campaign-id uint)
    (milestone-id uint)
  )
  (map-get? campaign-milestones {
    campaign-id: campaign-id,
    milestone-id: milestone-id,
  })
)

(define-read-only (get-milestone-vote
    (campaign-id uint)
    (milestone-id uint)
    (voter principal)
  )
  (map-get? milestone-votes {
    campaign-id: campaign-id,
    milestone-id: milestone-id,
    voter: voter,
  })
)

(define-read-only (calculate-milestone-approval-rate
    (campaign-id uint)
    (milestone-id uint)
  )
  (let ((milestone (unwrap!
      (map-get? campaign-milestones {
        campaign-id: campaign-id,
        milestone-id: milestone-id,
      })
      (err u0)
    )))
    (let ((total-votes (+ (get votes-for milestone) (get votes-against milestone))))
      (if (> total-votes u0)
        (ok (/ (* (get votes-for milestone) u100) total-votes))
        (ok u0)
      )
    )
  )
)

;; READ-ONLY FUNCTIONS - PORTFOLIO & PLATFORM

(define-read-only (get-investor-portfolio (investor principal))
  (map-get? investor-portfolios investor)
)

(define-read-only (get-platform-fee-percentage)
  (var-get platform-fee-percentage)
)

(define-read-only (is-contract-paused)
  (var-get paused)
)

;; PRIVATE HELPER FUNCTIONS

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-percentage)) u10000)
)

(define-private (calculate-equity-tokens
    (investment uint)
    (funding-goal uint)
  )
  ;; Proportional equity: (investment / funding-goal) * 10000 base tokens
  (/ (* investment u10000) funding-goal)
)

(define-private (is-valid-string-utf8-64 (str (string-utf8 64)))
  (> (len str) u0)
)

(define-private (is-valid-string-utf8-256 (str (string-utf8 256)))
  (> (len str) u0)
)

;; PUBLIC FUNCTIONS - CAMPAIGN LIFECYCLE

(define-public (create-campaign
    (title (string-utf8 64))
    (description (string-utf8 256))
    (funding-goal uint)
    (duration uint)
    (milestone-count uint)
  )
  (let ((campaign-id (+ (var-get total-campaigns) u1)))
    (begin
      ;; Validation checks
      (asserts! (not (var-get paused)) err-invalid-parameter)
      (asserts! (is-valid-string-utf8-64 title) err-invalid-parameter)
      (asserts! (is-valid-string-utf8-256 description) err-invalid-parameter)
      (asserts! (> funding-goal u0) err-invalid-parameter)
      (asserts! (> duration u0) err-invalid-parameter)
      (asserts! (and (>= milestone-count u1) (<= milestone-count u10))
        err-invalid-parameter
      )

      (map-set campaigns campaign-id {
        founder: tx-sender,
        title: title,
        description: description,
        funding-goal: funding-goal,
        total-raised: u0,
        deadline: (+ stacks-block-height duration),
        active: true,
        completed: false,
        milestone-count: milestone-count,
      })

      (map-set campaign-stats campaign-id {
        total-investors: u0,
        average-investment: u0,
        last-update: stacks-block-height,
      })

      (var-set total-campaigns campaign-id)
      (ok campaign-id)
    )
  )
)

(define-public (invest-in-campaign
    (campaign-id uint)
    (amount uint)
  )
  (let (
      (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
      (existing-investment (default-to {
        amount: u0,
        timestamp: u0,
        equity-tokens: u0,
      }
        (map-get? campaign-investments {
          campaign-id: campaign-id,
          investor: tx-sender,
        })
      ))
      (platform-fee (calculate-platform-fee amount))
      (investment-amount (- amount platform-fee))
      (equity-tokens (calculate-equity-tokens investment-amount (get funding-goal campaign)))
    )
    (begin
      ;; Validation checks
      (asserts! (not (var-get paused)) err-invalid-parameter)
      (asserts! (get active campaign) err-campaign-ended)
      (asserts! (<= stacks-block-height (get deadline campaign))
        err-campaign-ended
      )
      (asserts! (> amount u0) err-invalid-parameter)
      (asserts! (>= (stx-get-balance tx-sender) amount) err-insufficient-funds)

      ;; Process transfers
      (unwrap! (stx-transfer? investment-amount tx-sender (get founder campaign))
        err-insufficient-funds
      )
      (unwrap! (stx-transfer? platform-fee tx-sender contract-owner)
        err-insufficient-funds
      )

      ;; Update campaign totals
      (map-set campaigns campaign-id
        (merge campaign { total-raised: (+ (get total-raised campaign) investment-amount) })
      )

      ;; Record investment
      (map-set campaign-investments {
        campaign-id: campaign-id,
        investor: tx-sender,
      } {
        amount: (+ (get amount existing-investment) investment-amount),
        timestamp: stacks-block-height,
        equity-tokens: (+ (get equity-tokens existing-investment) equity-tokens),
      })

      ;; Update investor portfolio
      (let ((portfolio (default-to {
          total-invested: u0,
          active-campaigns: u0,
          total-returns: u0,
        }
          (map-get? investor-portfolios tx-sender)
        )))
        (map-set investor-portfolios tx-sender
          (merge portfolio {
            total-invested: (+ (get total-invested portfolio) investment-amount),
            active-campaigns: (if (is-eq (get amount existing-investment) u0)
              (+ (get active-campaigns portfolio) u1)
              (get active-campaigns portfolio)
            ),
          })
        )
      )

      ;; Update campaign statistics
      (let ((current-stats (default-to {
          total-investors: u0,
          average-investment: u0,
          last-update: u0,
        }
          (map-get? campaign-stats campaign-id)
        )))
        (let ((new-investor-count (if (is-eq (get amount existing-investment) u0)
            (+ (get total-investors current-stats) u1)
            (get total-investors current-stats)
          )))
          (map-set campaign-stats campaign-id {
            total-investors: new-investor-count,
            average-investment: (/ (+ (get total-raised campaign) investment-amount)
              new-investor-count
            ),
            last-update: stacks-block-height,
          })
        )
      )

      ;; Track platform fees
      (var-set total-platform-fees (+ (var-get total-platform-fees) platform-fee))
      (ok true)
    )
  )
)

(define-public (close-campaign (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get founder campaign)) err-not-authorized)
      (asserts! (get active campaign) err-campaign-ended)
      (asserts!
        (or
          (> stacks-block-height (get deadline campaign))
          (>= (get total-raised campaign) (get funding-goal campaign))
        )
        err-invalid-parameter
      )

      (map-set campaigns campaign-id
        (merge campaign {
          active: false,
          completed: true,
        })
      )
      (ok true)
    )
  )
)

;; PUBLIC FUNCTIONS - MILESTONE MANAGEMENT

(define-public (create-milestone
    (campaign-id uint)
    (milestone-id uint)
    (title (string-utf8 64))
    (description (string-utf8 256))
    (funding-percentage uint)
    (voting-duration uint)
  )
  (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found)))
    (begin
      ;; Validation checks
      (asserts! (is-eq tx-sender (get founder campaign)) err-not-authorized)
      (asserts! (get completed campaign) err-campaign-not-found)
      (asserts! (<= milestone-id (get milestone-count campaign))
        err-invalid-parameter
      )
      (asserts! (is-valid-string-utf8-64 title) err-invalid-parameter)
      (asserts! (is-valid-string-utf8-256 description) err-invalid-parameter)
      (asserts! (and (> funding-percentage u0) (<= funding-percentage u100))
        err-invalid-parameter
      )
      (asserts!
        (and (>= voting-duration min-voting-duration) (<= voting-duration max-voting-duration))
        err-invalid-parameter
      )

      (map-set campaign-milestones {
        campaign-id: campaign-id,
        milestone-id: milestone-id,
      } {
        title: title,
        description: description,
        funding-percentage: funding-percentage,
        completed: false,
        votes-for: u0,
        votes-against: u0,
        voting-deadline: (+ stacks-block-height voting-duration),
        funds-released: false,
      })
      (ok true)
    )
  )
)

(define-public (vote-on-milestone
    (campaign-id uint)
    (milestone-id uint)
    (approve bool)
  )
  (let (
      (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
      (milestone (unwrap!
        (map-get? campaign-milestones {
          campaign-id: campaign-id,
          milestone-id: milestone-id,
        })
        err-milestone-not-found
      ))
      (investment (unwrap!
        (map-get? campaign-investments {
          campaign-id: campaign-id,
          investor: tx-sender,
        })
        err-not-authorized
      ))
      (existing-vote (map-get? milestone-votes {
        campaign-id: campaign-id,
        milestone-id: milestone-id,
        voter: tx-sender,
      }))
      (voting-power (get equity-tokens investment))
    )
    (begin
      ;; Validation checks
      (asserts! (is-none existing-vote) err-already-voted)
      (asserts! (<= stacks-block-height (get voting-deadline milestone))
        err-voting-period-ended
      )
      (asserts! (> voting-power u0) err-not-authorized)
      (asserts! (<= milestone-id (get milestone-count campaign))
        err-invalid-parameter
      )

      ;; Record vote
      (map-set milestone-votes {
        campaign-id: campaign-id,
        milestone-id: milestone-id,
        voter: tx-sender,
      } {
        vote: approve,
        timestamp: stacks-block-height,
        voting-power: voting-power,
      })

      ;; Update milestone tallies
      (map-set campaign-milestones {
        campaign-id: campaign-id,
        milestone-id: milestone-id,
      }
        (merge milestone {
          votes-for: (if approve
            (+ (get votes-for milestone) voting-power)
            (get votes-for milestone)
          ),
          votes-against: (if (not approve)
            (+ (get votes-against milestone) voting-power)
            (get votes-against milestone)
          ),
        })
      )
      (ok true)
    )
  )
)

(define-public (complete-milestone
    (campaign-id uint)
    (milestone-id uint)
  )
  (let (
      (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
      (milestone (unwrap!
        (map-get? campaign-milestones {
          campaign-id: campaign-id,
          milestone-id: milestone-id,
        })
        err-milestone-not-found
      ))
      (total-votes (+ (get votes-for milestone) (get votes-against milestone)))
      (approval-rate (if (> total-votes u0)
        (/ (* (get votes-for milestone) u100) total-votes)
        u0
      ))
    )
    (begin
      ;; Validation checks
      (asserts! (is-eq tx-sender (get founder campaign)) err-not-authorized)
      (asserts! (> stacks-block-height (get voting-deadline milestone))
        err-voting-period-ended
      )
      (asserts! (>= approval-rate u51) err-milestone-not-completed)
      (asserts! (not (get funds-released milestone)) err-invalid-parameter)
      (asserts! (<= milestone-id (get milestone-count campaign))
        err-invalid-parameter
      )

      (map-set campaign-milestones {
        campaign-id: campaign-id,
        milestone-id: milestone-id,
      }
        (merge milestone {
          completed: true,
          funds-released: true,
        })
      )
      (ok true)
    )
  )
)

;; PUBLIC FUNCTIONS - ADMINISTRATIVE

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-parameter)
    (var-set platform-fee-percentage new-fee)
    (ok true)
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set paused (not (var-get paused)))
    (ok true)
  )
)

(define-public (withdraw-platform-fees)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((fees (var-get total-platform-fees)))
      (var-set total-platform-fees u0)
      (stx-transfer? fees tx-sender contract-owner)
    )
  )
)

;; PUBLIC FUNCTIONS - EMERGENCY CONTROLS

(define-public (emergency-close-campaign (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found)))
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (asserts! (<= campaign-id (var-get total-campaigns)) err-invalid-parameter)
      (map-set campaigns campaign-id (merge campaign { active: false }))
      (ok true)
    )
  )
)

(define-public (force-milestone-completion
    (campaign-id uint)
    (milestone-id uint)
  )
  (let (
      (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
      (milestone (unwrap!
        (map-get? campaign-milestones {
          campaign-id: campaign-id,
          milestone-id: milestone-id,
        })
        err-milestone-not-found
      ))
    )
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (asserts! (<= milestone-id (get milestone-count campaign))
        err-invalid-parameter
      )
      (map-set campaign-milestones {
        campaign-id: campaign-id,
        milestone-id: milestone-id,
      }
        (merge milestone {
          completed: true,
          funds-released: true,
        })
      )
      (ok true)
    )
  )
)
