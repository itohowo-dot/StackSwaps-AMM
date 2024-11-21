;; title: StackSwaps Automated Market Maker (AMM)
;; summary: A decentralized automated market maker (AMM) for token swaps and liquidity provision.
;; description:
;; This smart contract implements an automated market maker (AMM) for token swaps, allowing users to create liquidity pools, add and remove liquidity, swap tokens, and claim yield farming rewards. The contract supports governance functions for adjusting reward rates and ensures secure and efficient token transfers and liquidity management.

;; Import the FT trait from the correct contract
(use-trait ft-trait .ft-trait.ft-trait)

;; Error constants
(define-constant ERR-INSUFFICIENT-FUNDS (err u1))
(define-constant ERR-INVALID-AMOUNT (err u2))
(define-constant ERR-POOL-NOT-EXISTS (err u3))
(define-constant ERR-UNAUTHORIZED (err u4))
(define-constant ERR-TRANSFER-FAILED (err u5))
(define-constant ERR-INVALID-TOKEN (err u6))

;; Allowed tokens list
(define-map allowed-tokens 
  principal 
  bool
)

;; Storage for liquidity pools
(define-map liquidity-pools 
    {token1: principal, token2: principal} 
    {
        total-liquidity: uint,
        token1-reserve: uint,
        token2-reserve: uint
    }
)

;; Mapping to track user liquidity positions
(define-map user-liquidity 
    {user: principal, token1: principal, token2: principal} 
    {liquidity-shares: uint}
)

;; Mapping to track yield farming rewards
(define-map yield-rewards 
    {user: principal, token: principal} 
    {pending-rewards: uint}
)

;; Constants for yield farming
(define-constant REWARD-RATE-PER-BLOCK u10)
(define-constant MIN-LIQUIDITY-FOR-REWARDS u100)
(define-constant MAX-TOKENS-PER-POOL u2)

;; Add allowed token
(define-public (add-allowed-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (map-set allowed-tokens token true)
    (ok true)
  )
)

;; Create a new liquidity pool
(define-public (create-pool 
    (token1 <ft-trait>) 
    (token2 <ft-trait>) 
    (initial-amount1 uint) 
    (initial-amount2 uint)
)
    (let (
        (token1-principal (contract-of token1))
        (token2-principal (contract-of token2))
    )
        ;; Validate tokens
        (asserts! (is-valid-token token1-principal) ERR-INVALID-TOKEN)
        (asserts! (is-valid-token token2-principal) ERR-INVALID-TOKEN)
        
        ;; Check for valid initial amounts
        (asserts! (and (> initial-amount1 u0) (> initial-amount2 u0)) ERR-INVALID-AMOUNT)
        
        ;; Transfer initial liquidity from sender
        (try! (contract-call? token1 transfer initial-amount1 tx-sender (as-contract tx-sender) none))
        (try! (contract-call? token2 transfer initial-amount2 tx-sender (as-contract tx-sender) none))
        
        ;; Create pool entry
        (map-set liquidity-pools 
            {token1: token1-principal, token2: token2-principal}
            {
                total-liquidity: initial-amount1,
                token1-reserve: initial-amount1,
                token2-reserve: initial-amount2
            }
        )
        
        ;; Assign initial liquidity shares to sender
        (map-set user-liquidity 
            {user: tx-sender, token1: token1-principal, token2: token2-principal}
            {liquidity-shares: initial-amount1}
        )
        
        (ok true)
    )
)

;; Add liquidity to an existing pool
(define-public (add-liquidity 
    (token1 <ft-trait>) 
    (token2 <ft-trait>) 
    (amount1 uint) 
    (amount2 uint)
)
    (let (
        (token1-principal (contract-of token1))
        (token2-principal (contract-of token2))
        (pool (unwrap! 
            (map-get? liquidity-pools 
                {token1: token1-principal, token2: token2-principal}) 
            ERR-POOL-NOT-EXISTS
        ))
        (optimal-amount2 (/ (* amount1 (get token2-reserve pool)) (get token1-reserve pool)))
    )
        ;; Validate tokens
        (asserts! (is-valid-token token1-principal) ERR-INVALID-TOKEN)
        (asserts! (is-valid-token token2-principal) ERR-INVALID-TOKEN)
        
        ;; Validate input amounts
        (asserts! (and (> amount1 u0) (> amount2 u0)) ERR-INVALID-AMOUNT)
        (asserts! (<= amount2 optimal-amount2) ERR-INVALID-AMOUNT)
        
        ;; Transfer tokens
        (try! (contract-call? token1 transfer amount1 tx-sender (as-contract tx-sender) none))
        (try! (contract-call? token2 transfer amount2 tx-sender (as-contract tx-sender) none))
        
        ;; Update pool reserves
        (map-set liquidity-pools 
            {token1: token1-principal, token2: token2-principal}
            {
                total-liquidity: (+ (get total-liquidity pool) amount1),
                token1-reserve: (+ (get token1-reserve pool) amount1),
                token2-reserve: (+ (get token2-reserve pool) amount2)
            }
        )
        
        ;; Update user's liquidity shares
        (let (
            (existing-shares 
                (default-to u0 
                    (get liquidity-shares 
                        (map-get? user-liquidity 
                            {user: tx-sender, token1: token1-principal, token2: token2-principal}
                        )
                    )
                )
            )
            (new-shares (+ existing-shares amount1))
        )
            (map-set user-liquidity 
                {user: tx-sender, token1: token1-principal, token2: token2-principal}
                {liquidity-shares: new-shares}
            )
        )
        
        (ok true)
    )
)

;; Remove liquidity from a pool
(define-public (remove-liquidity 
    (token1 <ft-trait>) 
    (token2 <ft-trait>) 
    (shares-to-remove uint)
)
    (let (
        (user-position (unwrap! 
            (map-get? user-liquidity 
                {user: tx-sender, token1: (contract-of token1), token2: (contract-of token2)}) 
            ERR-UNAUTHORIZED
        ))
        (pool (unwrap! 
            (map-get? liquidity-pools 
                {token1: (contract-of token1), token2: (contract-of token2)}) 
            ERR-POOL-NOT-EXISTS
        ))
    )
        ;; Validate shares
        (asserts! (<= shares-to-remove (get liquidity-shares user-position)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Calculate proportional token amounts to withdraw
        (let (
            (total-pool-liquidity (get total-liquidity pool))
            (token1-amount (/ (* shares-to-remove (get token1-reserve pool)) total-pool-liquidity))
            (token2-amount (/ (* shares-to-remove (get token2-reserve pool)) total-pool-liquidity))
        )
            ;; Transfer tokens back to user
            (try! (as-contract (contract-call? token1 transfer token1-amount tx-sender tx-sender none)))
            (try! (as-contract (contract-call? token2 transfer token2-amount tx-sender tx-sender none)))
            
            ;; Update pool and user liquidity
            (map-set liquidity-pools 
                {token1: (contract-of token1), token2: (contract-of token2)}
                {
                    total-liquidity: (- (get total-liquidity pool) shares-to-remove),
                    token1-reserve: (- (get token1-reserve pool) token1-amount),
                    token2-reserve: (- (get token2-reserve pool) token2-amount)
                }
            )
            
            (map-set user-liquidity 
                {user: tx-sender, token1: (contract-of token1), token2: (contract-of token2)}
                {liquidity-shares: (- (get liquidity-shares user-position) shares-to-remove)}
            )
            
            (ok true)
        )
    )
)

;; Swap tokens using AMM
(define-public (swap-tokens 
    (token-in <ft-trait>) 
    (token-out <ft-trait>) 
    (amount-in uint)
)
    (let (
        (pool (unwrap! 
            (map-get? liquidity-pools 
                {token1: (contract-of token-in), token2: (contract-of token-out)}) 
            ERR-POOL-NOT-EXISTS
        ))
        (constant-product (* (get token1-reserve pool) (get token2-reserve pool)))
    )
        ;; Transfer input tokens from user
        (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
        
        ;; Calculate output amount with 0.3% fee
        (let (
            (amount-in-with-fee (* amount-in u997))
            (new-token-in-reserve (+ (get token1-reserve pool) amount-in))
            (new-token-out-reserve (/ constant-product new-token-in-reserve))
            (amount-out (- (get token2-reserve pool) new-token-out-reserve))
        )
            ;; Transfer output tokens to user
            (try! (as-contract (contract-call? token-out transfer amount-out tx-sender tx-sender none)))
            
            ;; Update pool reserves
            (map-set liquidity-pools 
                {token1: (contract-of token-in), token2: (contract-of token-out)}
                {
                    total-liquidity: (get total-liquidity pool),
                    token1-reserve: new-token-in-reserve,
                    token2-reserve: new-token-out-reserve
                }
            )
            
            (ok amount-out)
        )
    )
)

;; Claim yield farming rewards
(define-public (claim-yield-rewards 
    (token1 <ft-trait>) 
    (token2 <ft-trait>)
)
    (let (
        (user-position (unwrap! 
            (map-get? user-liquidity 
                {user: tx-sender, token1: (contract-of token1), token2: (contract-of token2)}) 
            ERR-UNAUTHORIZED
        ))
        (current-block block-height)
    )
        ;; Check minimum liquidity for rewards
        (asserts! (>= (get liquidity-shares user-position) MIN-LIQUIDITY-FOR-REWARDS) ERR-INSUFFICIENT-FUNDS)
        
        ;; Calculate and distribute rewards
        (let (
            (reward-amount (* (get liquidity-shares user-position) REWARD-RATE-PER-BLOCK))
        )
            ;; Update reward mapping
            (map-set yield-rewards 
                {user: tx-sender, token: (contract-of token1)}
                {pending-rewards: reward-amount}
            )
            
            (ok reward-amount)
        )
    )
)

;; Governance function to adjust reward rate (only owner)
(define-public (set-reward-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set reward-rate new-rate)
        (ok true)
    )
)

;; Validate token
(define-private (is-valid-token (token principal))
  (default-to false (map-get? allowed-tokens token))
)

;; Owner variable
(define-data-var contract-owner principal tx-sender)
(define-data-var reward-rate uint REWARD-RATE-PER-BLOCK)

;; Initial setup - owner adds initial allowed tokens
(map-set allowed-tokens (var-get contract-owner) true)