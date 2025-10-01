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