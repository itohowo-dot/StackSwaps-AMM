;; ft-trait.clar
;; This implements the SIP-010 Fungible Token standard trait
(define-trait ft-trait
    (
        ;; Transfer from the caller to a new principal
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))

        ;; Get total supply of token
        (get-total-supply () (response uint uint))

        ;; Get token balance for a specified principal
        (get-balance (principal) (response uint uint))

        ;; Get human-readable name of token
        (get-name () (response (string-ascii 32) uint))

        ;; Get token symbol
        (get-symbol () (response (string-ascii 32) uint))

        ;; Get number of decimals used by token
        (get-decimals () (response uint uint))

        ;; Get token URI for metadata
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)