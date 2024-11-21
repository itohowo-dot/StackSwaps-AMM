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
