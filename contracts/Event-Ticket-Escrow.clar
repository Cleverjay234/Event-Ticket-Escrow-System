;; title: Event-Ticket-Escrow
;; version: 1.0
;; summary: Escrow system for event tickets with automated fund release
;; description: Smart contract that holds ticket funds until event verification

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-event-past (err u105))
(define-constant err-event-not-past (err u106))
(define-constant err-already-purchased (err u107))
(define-constant err-not-purchased (err u108))
(define-constant err-event-cancelled (err u109))
(define-constant err-insufficient-funds (err u110))
(define-constant err-event-verified (err u111))
(define-constant err-verification-period-ended (err u112))
(define-constant err-auction-not-found (err u113))
(define-constant err-auction-ended (err u114))
(define-constant err-bid-too-low (err u115))
(define-constant err-auction-active (err u116))

;; data vars
(define-data-var next-event-id uint u1)
(define-data-var platform-fee-rate uint u250)
(define-data-var next-auction-id uint u1)

;; data maps
(define-map events
  { event-id: uint }
  {
    organizer: principal,
    name: (string-utf8 100),
    description: (string-utf8 500),
    ticket-price: uint,
    max-tickets: uint,
    sold-tickets: uint,
    event-date: uint,
    verification-deadline: uint,
    is-cancelled: bool,
    is-verified: bool,
    funds-released: bool
  }
)

(define-map tickets
  { event-id: uint, buyer: principal }
  {
    purchase-block: uint,
    is-refunded: bool,
    is-transferred: bool,
    current-owner: principal
  }
)

(define-map event-funds
  { event-id: uint }
  { total-escrowed: uint }
)

(define-map verifiers
  { event-id: uint, verifier: principal }
  { verified: bool }
)

(define-map organizer-reputation
  { organizer: principal }
  { events-created: uint, events-completed: uint, total-revenue: uint }
)

(define-map event-verification-counts
  { event-id: uint }
  { total-verifications: uint }
)

(define-map ticket-auctions
  { auction-id: uint }
  {
    event-id: uint,
    seller: principal,
    original-buyer: principal,
    starting-price: uint,
    current-bid: uint,
    current-bidder: (optional principal),
    end-block: uint,
    is-settled: bool
  }
)

(define-map auction-bids
  { auction-id: uint, bidder: principal }
  { bid-amount: uint, bid-block: uint }
)

;; public functions

(define-public (create-event (name (string-utf8 100)) (description (string-utf8 500)) (ticket-price uint) (max-tickets uint) (event-date uint) (verification-deadline uint))
  (let
    (
      (event-id (var-get next-event-id))
      (current-block burn-block-height)
    )
    (asserts! (> ticket-price u0) err-invalid-amount)
    (asserts! (> max-tickets u0) err-invalid-amount)
    (asserts! (> event-date current-block) err-event-past)
    (asserts! (> verification-deadline event-date) err-event-past)
    
    (map-set events
      { event-id: event-id }
      {
        organizer: tx-sender,
        name: name,
        description: description,
        ticket-price: ticket-price,
        max-tickets: max-tickets,
        sold-tickets: u0,
        event-date: event-date,
        verification-deadline: verification-deadline,
        is-cancelled: false,
        is-verified: false,
        funds-released: false
      }
    )
    
    (map-set event-funds
      { event-id: event-id }
      { total-escrowed: u0 }
    )
    
    (map-set event-verification-counts
      { event-id: event-id }
      { total-verifications: u0 }
    )
    
    (var-set next-event-id (+ event-id u1))
    
    (match (map-get? organizer-reputation { organizer: tx-sender })
      existing-rep
        (map-set organizer-reputation
          { organizer: tx-sender }
          {
            events-created: (+ (get events-created existing-rep) u1),
            events-completed: (get events-completed existing-rep),
            total-revenue: (get total-revenue existing-rep)
          }
        )
      (map-set organizer-reputation
        { organizer: tx-sender }
        { events-created: u1, events-completed: u0, total-revenue: u0 }
      )
    )
    
    (ok event-id)
  )
)

(define-public (purchase-ticket (event-id uint))
  (let
    (
      (event-info (unwrap! (map-get? events { event-id: event-id }) err-not-found))
      (ticket-price (get ticket-price event-info))
      (current-block burn-block-height)
      (funds-info (unwrap! (map-get? event-funds { event-id: event-id }) err-not-found))
    )
    (asserts! (not (get is-cancelled event-info)) err-event-cancelled)
    (asserts! (< (get sold-tickets event-info) (get max-tickets event-info)) err-invalid-amount)
    (asserts! (< current-block (get event-date event-info)) err-event-past)
    (asserts! (is-none (map-get? tickets { event-id: event-id, buyer: tx-sender })) err-already-purchased)
    
    (try! (stx-transfer? ticket-price tx-sender (as-contract tx-sender)))
    
    (map-set tickets
      { event-id: event-id, buyer: tx-sender }
      {
        purchase-block: current-block,
        is-refunded: false,
        is-transferred: false,
        current-owner: tx-sender
      }
    )
    
    (map-set events
      { event-id: event-id }
      (merge event-info { sold-tickets: (+ (get sold-tickets event-info) u1) })
    )
    
    (map-set event-funds
      { event-id: event-id }
      { total-escrowed: (+ (get total-escrowed funds-info) ticket-price) }
    )
    
    (ok true)
  )
)

(define-public (verify-event (event-id uint))
  (let
    (
      (event-info (unwrap! (map-get? events { event-id: event-id }) err-not-found))
      (current-block burn-block-height)
    )
    (asserts! (>= current-block (get event-date event-info)) err-event-not-past)
    (asserts! (<= current-block (get verification-deadline event-info)) err-verification-period-ended)
    (asserts! (not (get is-cancelled event-info)) err-event-cancelled)
    (asserts! (is-some (map-get? tickets { event-id: event-id, buyer: tx-sender })) err-not-purchased)
    
    (map-set verifiers
      { event-id: event-id, verifier: tx-sender }
      { verified: true }
    )
    
    (let
      ((current-count (default-to u0 (get total-verifications (map-get? event-verification-counts { event-id: event-id })))))
      (map-set event-verification-counts
        { event-id: event-id }
        { total-verifications: (+ current-count u1) }
      )
    )
    
    (ok true)
  )
)

(define-public (claim-funds (event-id uint))
  (let
    (
      (event-info (unwrap! (map-get? events { event-id: event-id }) err-not-found))
      (funds-info (unwrap! (map-get? event-funds { event-id: event-id }) err-not-found))
      (current-block burn-block-height)
      (verification-count (get-verification-count event-id))
      (required-verifications (/ (get sold-tickets event-info) u2))
      (platform-fee (/ (* (get total-escrowed funds-info) (var-get platform-fee-rate)) u10000))
      (organizer-amount (- (get total-escrowed funds-info) platform-fee))
    )
    (asserts! (is-eq tx-sender (get organizer event-info)) err-unauthorized)
    (asserts! (not (get funds-released event-info)) err-already-exists)
    (asserts! (not (get is-cancelled event-info)) err-event-cancelled)
    (asserts! (> current-block (get verification-deadline event-info)) err-event-not-past)
    (asserts! (>= verification-count required-verifications) err-unauthorized)
    
    (try! (as-contract (stx-transfer? organizer-amount tx-sender (get organizer event-info))))
    (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
    
    (map-set events
      { event-id: event-id }
      (merge event-info { is-verified: true, funds-released: true })
    )
    
    (match (map-get? organizer-reputation { organizer: (get organizer event-info) })
      existing-rep
        (map-set organizer-reputation
          { organizer: (get organizer event-info) }
          {
            events-created: (get events-created existing-rep),
            events-completed: (+ (get events-completed existing-rep) u1),
            total-revenue: (+ (get total-revenue existing-rep) organizer-amount)
          }
        )
      false
    )
    
    (ok organizer-amount)
  )
)

(define-public (request-refund (event-id uint))
  (let
    (
      (event-info (unwrap! (map-get? events { event-id: event-id }) err-not-found))
      (ticket-info (unwrap! (map-get? tickets { event-id: event-id, buyer: tx-sender }) err-not-purchased))
      (current-block burn-block-height)
      (refund-amount (get ticket-price event-info))
    )
    (asserts! (not (get is-refunded ticket-info)) err-already-exists)
    (asserts! (not (get funds-released event-info)) err-event-verified)
    (asserts! 
      (or 
        (get is-cancelled event-info)
        (and 
          (> current-block (get verification-deadline event-info))
          (< (get-verification-count event-id) (/ (get sold-tickets event-info) u2))
        )
      ) 
      err-unauthorized
    )
    
    (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
    
    (map-set tickets
      { event-id: event-id, buyer: tx-sender }
      (merge ticket-info { is-refunded: true })
    )
    
    (ok refund-amount)
  )
)

(define-public (cancel-event (event-id uint))
  (let
    (
      (event-info (unwrap! (map-get? events { event-id: event-id }) err-not-found))
      (current-block burn-block-height)
    )
    (asserts! (is-eq tx-sender (get organizer event-info)) err-unauthorized)
    (asserts! (not (get is-cancelled event-info)) err-already-exists)
    (asserts! (< current-block (get event-date event-info)) err-event-past)
    
    (map-set events
      { event-id: event-id }
      (merge event-info { is-cancelled: true })
    )
    
    (ok true)
  )
)

(define-public (transfer-ticket (event-id uint) (new-owner principal))
  (let
    (
      (event-info (unwrap! (map-get? events { event-id: event-id }) err-not-found))
      (ticket-info (unwrap! (map-get? tickets { event-id: event-id, buyer: tx-sender }) err-not-purchased))
      (current-block burn-block-height)
    )
    (asserts! (not (get is-cancelled event-info)) err-event-cancelled)
    (asserts! (< current-block (get event-date event-info)) err-event-past)
    (asserts! (not (get is-refunded ticket-info)) err-already-exists)
    (asserts! (is-eq (get current-owner ticket-info) tx-sender) err-unauthorized)
    
    (map-delete tickets { event-id: event-id, buyer: tx-sender })
    
    (map-set tickets
      { event-id: event-id, buyer: new-owner }
      (merge ticket-info { current-owner: new-owner, is-transferred: true })
    )
    
    (ok true)
  )
)

(define-public (create-ticket-auction (event-id uint) (starting-price uint) (duration-blocks uint))
  (let
    (
      (event-info (unwrap! (map-get? events { event-id: event-id }) err-not-found))
      (ticket-info (unwrap! (map-get? tickets { event-id: event-id, buyer: tx-sender }) err-not-purchased))
      (auction-id (var-get next-auction-id))
      (current-block burn-block-height)
      (end-block (+ current-block duration-blocks))
    )
    (asserts! (not (get is-cancelled event-info)) err-event-cancelled)
    (asserts! (< current-block (get event-date event-info)) err-event-past)
    (asserts! (not (get is-refunded ticket-info)) err-already-exists)
    (asserts! (is-eq (get current-owner ticket-info) tx-sender) err-unauthorized)
    (asserts! (> starting-price u0) err-invalid-amount)
    (asserts! (> duration-blocks u0) err-invalid-amount)
    
    (map-set ticket-auctions
      { auction-id: auction-id }
      {
        event-id: event-id,
        seller: tx-sender,
        original-buyer: tx-sender,
        starting-price: starting-price,
        current-bid: u0,
        current-bidder: none,
        end-block: end-block,
        is-settled: false
      }
    )
    
    (var-set next-auction-id (+ auction-id u1))
    (ok auction-id)
  )
)

(define-public (place-bid (auction-id uint) (bid-amount uint))
  (let
    (
      (auction-info (unwrap! (map-get? ticket-auctions { auction-id: auction-id }) err-auction-not-found))
      (current-block burn-block-height)
    )
    (asserts! (< current-block (get end-block auction-info)) err-auction-ended)
    (asserts! (not (get is-settled auction-info)) err-auction-ended)
    (asserts! (>= bid-amount (get starting-price auction-info)) err-bid-too-low)
    (asserts! (> bid-amount (get current-bid auction-info)) err-bid-too-low)
    
    (match (get current-bidder auction-info)
      previous-bidder
        (try! (as-contract (stx-transfer? (get current-bid auction-info) tx-sender previous-bidder)))
      true
    )
    
    (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
    
    (map-set auction-bids
      { auction-id: auction-id, bidder: tx-sender }
      { bid-amount: bid-amount, bid-block: current-block }
    )
    
    (map-set ticket-auctions
      { auction-id: auction-id }
      (merge auction-info {
        current-bid: bid-amount,
        current-bidder: (some tx-sender)
      })
    )
    
    (ok true)
  )
)

(define-public (settle-auction (auction-id uint))
  (let
    (
      (auction-info (unwrap! (map-get? ticket-auctions { auction-id: auction-id }) err-auction-not-found))
      (current-block burn-block-height)
      (winning-bid (get current-bid auction-info))
      (platform-fee (/ (* winning-bid (var-get platform-fee-rate)) u10000))
      (seller-payment (- winning-bid platform-fee))
    )
    (asserts! (>= current-block (get end-block auction-info)) err-auction-active)
    (asserts! (not (get is-settled auction-info)) err-already-exists)
    
    (match (get current-bidder auction-info)
      winner
        (begin
          (try! (as-contract (stx-transfer? seller-payment tx-sender (get seller auction-info))))
          (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
          
          (map-delete tickets { event-id: (get event-id auction-info), buyer: (get seller auction-info) })
          
          (map-set tickets
            { event-id: (get event-id auction-info), buyer: winner }
            {
              purchase-block: current-block,
              is-refunded: false,
              is-transferred: true,
              current-owner: winner
            }
          )
        )
      (begin
        true
      )
    )
    
    (map-set ticket-auctions
      { auction-id: auction-id }
      (merge auction-info { is-settled: true })
    )
    
    (ok true)
  )
)

;; read only functions

(define-read-only (get-event (event-id uint))
  (map-get? events { event-id: event-id })
)

(define-read-only (get-ticket (event-id uint) (buyer principal))
  (map-get? tickets { event-id: event-id, buyer: buyer })
)

(define-read-only (get-event-funds (event-id uint))
  (map-get? event-funds { event-id: event-id })
)

(define-read-only (get-organizer-reputation (organizer principal))
  (map-get? organizer-reputation { organizer: organizer })
)

(define-read-only (get-verification-count (event-id uint))
  (default-to u0 (get total-verifications (map-get? event-verification-counts { event-id: event-id })))
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-next-event-id)
  (var-get next-event-id)
)

(define-read-only (get-auction (auction-id uint))
  (map-get? ticket-auctions { auction-id: auction-id })
)

(define-read-only (get-auction-bid (auction-id uint) (bidder principal))
  (map-get? auction-bids { auction-id: auction-id, bidder: bidder })
)

(define-read-only (get-next-auction-id)
  (var-get next-auction-id)
)

;; private functions
