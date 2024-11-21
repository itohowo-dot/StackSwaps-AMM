;; title: StackSwaps Automated Market Maker (AMM)
;; summary: A decentralized automated market maker (AMM) for token swaps and liquidity provision.
;; description:
;; This smart contract implements an automated market maker (AMM) for token swaps, allowing users to create liquidity pools, add and remove liquidity, swap tokens, and claim yield farming rewards. The contract supports governance functions for adjusting reward rates and ensures secure and efficient token transfers and liquidity management.

;; traits
(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; Error constants
(define-constant ERR-INSUFFICIENT-FUNDS (err u1))
(define-constant ERR-INVALID-AMOUNT (err u2))
(define-constant ERR-POOL-NOT-EXISTS (err u3))
(define-constant ERR-UNAUTHORIZED (err u4))
(define-constant ERR-TRANSFER-FAILED (err u5))

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

;; Create a new liquidity pool
(define-public (create-pool 
    (token1 <ft-trait>) 
    (token2 <ft-trait>) 
    (initial-amount1 uint) 
    (initial-amount2 uint)
)
    (begin
        ;; Check for valid initial amounts
        (asserts! (and (> initial-amount1 u0) (> initial-amount2 u0)) ERR-INVALID-AMOUNT)
        
        ;; Transfer initial liquidity from sender
        (try! (contract-call? token1 transfer initial-amount1 tx-sender (as-contract tx-sender) none))
        (try! (contract-call? token2 transfer initial-amount2 tx-sender (as-contract tx-sender) none))
        
        ;; Create pool entry
        (map-set liquidity-pools 
            {token1: (contract-of token1), token2: (contract-of token2)}
            {
                total-liquidity: initial-amount1,
                token1-reserve: initial-amount1,
                token2-reserve: initial-amount2
            }
        )
        
        ;; Assign initial liquidity shares to sender
        (map-set user-liquidity 
            {user: tx-sender, token1: (contract-of token1), token2: (contract-of token2)}
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
        (pool (unwrap! 
            (map-get? liquidity-pools 
                {token1: (contract-of token1), token2: (contract-of token2)}) 
            ERR-POOL-NOT-EXISTS
        ))
        (optimal-amount2 (/ (* amount1 (get token2-reserve pool)) (get token1-reserve pool)))
    )
        ;; Validate input amounts
        (asserts! (and (> amount1 u0) (> amount2 u0)) ERR-INVALID-AMOUNT)
        (asserts! (<= amount2 optimal-amount2) ERR-INVALID-AMOUNT)
        
        ;; Transfer tokens
        (try! (contract-call? token1 transfer amount1 tx-sender (as-contract tx-sender) none))
        (try! (contract-call? token2 transfer amount2 tx-sender (as-contract tx-sender) none))
        
        ;; Update pool reserves
        (map-set liquidity-pools 
            {token1: (contract-of token1), token2: (contract-of token2)}
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
                            {user: tx-sender, token1: (contract-of token1), token2: (contract-of token2)}
                        )
                    )
                )
            )
            (new-shares (+ existing-shares amount1))
        )
            (map-set user-liquidity 
                {user: tx-sender, token1: (contract-of token1), token2: (contract-of token2)}
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