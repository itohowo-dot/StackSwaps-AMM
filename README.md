# StackSwaps AMM Smart Contract

## Overview

StackSwaps is a decentralized Automated Market Maker (AMM) smart contract built for the Stacks blockchain. It enables users to create liquidity pools, provide liquidity, perform token swaps, and participate in yield farming. The contract implements a Constant Product Market Maker formula (x \* y = k) similar to Uniswap v2's core mechanics.

## Features

- **Liquidity Pool Management**

  - Create new liquidity pools
  - Add liquidity to existing pools
  - Remove liquidity from pools
  - Automatic price discovery based on token reserves

- **Token Swapping**

  - Swap between any two supported tokens
  - Constant product formula with 0.3% swap fee
  - Automatic price impact calculation

- **Yield Farming**

  - Reward distribution for liquidity providers
  - Configurable reward rates
  - Minimum liquidity requirements for rewards

- **Governance**
  - Token allowlist management
  - Adjustable reward rates
  - Contract owner privileges

## Technical Specifications

### Constants

```clarity
REWARD-RATE-PER-BLOCK: u10
MIN-LIQUIDITY-FOR-REWARDS: u100
MAX-TOKENS-PER-POOL: u2
MAX-REWARD-RATE: u1000000
MAX-UINT: u340282366920938463463374607431768211455
```

### Error Codes

- `ERR-INSUFFICIENT-FUNDS (u1)`: Insufficient balance for operation
- `ERR-INVALID-AMOUNT (u2)`: Invalid amount specified
- `ERR-POOL-NOT-EXISTS (u3)`: Liquidity pool doesn't exist
- `ERR-UNAUTHORIZED (u4)`: Unauthorized access
- `ERR-TRANSFER-FAILED (u5)`: Token transfer failed
- `ERR-INVALID-TOKEN (u6)`: Invalid token address
- `ERR-INVALID-PAIR (u7)`: Invalid token pair
- `ERR-ZERO-AMOUNT (u8)`: Zero amount specified
- `ERR-MAX-AMOUNT-EXCEEDED (u9)`: Maximum amount exceeded
- `ERR-SAME-TOKEN (u10)`: Same token addresses provided

## Core Functions

### Pool Management

#### create-pool

```clarity
(define-public (create-pool (token1 <ft-trait>) (token2 <ft-trait>) (initial-amount1 uint) (initial-amount2 uint))
```

Creates a new liquidity pool with initial liquidity.

#### add-liquidity

```clarity
(define-public (add-liquidity (token1 <ft-trait>) (token2 <ft-trait>) (amount1 uint) (amount2 uint))
```

Adds liquidity to an existing pool.

#### remove-liquidity

```clarity
(define-public (remove-liquidity (token1 <ft-trait>) (token2 <ft-trait>) (shares-to-remove uint))
```

Removes liquidity from a pool.

### Trading

#### swap-tokens

```clarity
(define-public (swap-tokens (token-in <ft-trait>) (token-out <ft-trait>) (amount-in uint))
```

Executes a token swap using the AMM formula.

### Yield Farming

#### claim-yield-rewards

```clarity
(define-public (claim-yield-rewards (token1 <ft-trait>) (token2 <ft-trait>))
```

Claims accumulated yield farming rewards.

### Governance

#### add-allowed-token

```clarity
(define-public (add-allowed-token (token principal))
```

Adds a token to the allowlist (owner only).

#### set-reward-rate

```clarity
(define-public (set-reward-rate (new-rate uint))
```

Updates the yield farming reward rate (owner only).

## Usage Examples

### Creating a New Pool

```clarity
(contract-call? .stackswaps-amm create-pool token-a token-b u1000000 u1000000)
```

### Adding Liquidity

```clarity
(contract-call? .stackswaps-amm add-liquidity token-a token-b u100000 u100000)
```

### Performing a Swap

```clarity
(contract-call? .stackswaps-amm swap-tokens token-a token-b u10000)
```

## Security Considerations

1. **Validation Checks**

   - All input amounts are validated
   - Token pairs are verified against allowlist
   - Overflow protection implemented

2. **Access Control**

   - Owner-only functions for critical operations
   - Protected governance functions

3. **Safety Mechanisms**
   - Maximum limits on various parameters
   - Minimum liquidity requirements
   - Constant product formula maintains price stability

## Deployment Prerequisites

1. Stacks blockchain environment
2. Fungible tokens implementing the `ft-trait`
3. Contract owner address

## Known Limitations

1. Fixed 0.3% swap fee
2. Two tokens per pool maximum
3. No flash loan protection
4. Basic yield farming mechanism

## Contributing

To contribute to StackSwaps:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with detailed description
4. Ensure all tests pass
5. Follow the coding style guidelines

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
