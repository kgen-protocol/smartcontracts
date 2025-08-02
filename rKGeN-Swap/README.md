# rKGEN Swap Contract

A decentralized token swap contract on Aptos that enables swapping of rKGEN input tokens for KGEN output tokens with configurable fees and ratios.

## Contract Information

- **Module**: `rkgen::swap`
- **Network**: Aptos
- **Input Token**: rKGEN 
- **Output Token**: KGEN 
- **Fee Structure**: Variable basis points (0-100%)
- **Swap Ratio**: Configurable (0.01% to 100% = 0.0001:1 to 1:1)

## Architecture Overview

The rKGEN swap contract implements a single-direction token swap mechanism with administrative controls, fee collection, and sponsored transaction support.

### Core Resources

1. **Admin**: Global administrative control resource
    - Stores the current admin address
    - Required for all administrative operations

2. **SwapPool**: Main pool resource containing swap configuration and state
    - Token metadata references for input and output tokens
    - Swap parameters (fee rate, swap ratio)
    - Pool state (pause status, statistics)
    - Fee recipient configuration
    - Output token store for liquidity management

### Key Features

- **Configurable Swap Ratio**: Flexible ratio from 0.0001:1 to 1:1 (input:output)
- **Dynamic Fee Structure**: Adjustable fees from 0% to 100% in basis points
- **Sponsored Swaps**: Gas fee sponsorship with separate fee handling
- **Pause Mechanism**: Emergency pause functionality for security
- **Liquidity Management**: Admin-controlled deposit and withdrawal of output tokens
- **Comprehensive Statistics**: Tracking of all swap activities and fees

## Function Documentation

### View Functions

#### `get_admin(): address`
Returns the current admin address.
- **Requirements**: Contract must be initialized

#### `get_pool_balance(): u64`
Returns the current output token balance in the pool.
- **Requirements**: Pool must exist

#### `get_swap_fee_rate(): u64`
Returns the current swap fee rate in basis points (e.g., 300 = 3%).
- **Requirements**: Pool must exist

#### `get_swap_ratio(): u64`
Returns the current swap ratio in basis points (e.g., 8000 = 80% = 0.8:1).
- **Requirements**: Pool must exist

#### `get_fee_recipient(): address`
Returns the address that receives swap fees.
- **Requirements**: Pool must exist

#### `is_swap_paused(): bool`
Returns whether swapping is currently paused.
- **Requirements**: Pool must exist

#### `get_total_input_token_swapped(): u64`
Returns the total amount of input tokens swapped since pool creation.
- **Requirements**: Pool must exist

#### `get_total_output_token_swapped(): u64`
Returns the total amount of output tokens distributed since pool creation.
- **Requirements**: Pool must exist

#### `get_total_fee_collected(): u64`
Returns the total fees collected since pool creation.
- **Requirements**: Pool must exist

#### `get_swap_stats(): (u64, u64, u64, u64, u64, bool)`
Returns comprehensive swap statistics as a tuple:
- Total input tokens swapped
- Total output tokens swapped
- Total fees collected
- Current fee rate
- Current swap ratio
- Pause status
- **Requirements**: Pool must exist

#### `get_swap_preview(amount_in: u64): (u64, u64)`
Calculates the expected output amount and fees for a given input amount.
- **Returns**: (amount_out, fee_amount)
- **Requirements**: Pool must exist, amount > 0

#### `get_sponser_swap_preview(amount_in: u64, gas_fee_amount: u64): (u64, u64, u64)`
Calculates the expected output amount and fees for a sponsored swap.
- **Returns**: (amount_out, swap_fee_amount, total_fee_amount)
- **Requirements**: Pool must exist, amount > 0, gas_fee_amount > 0

### Administrative Functions

#### `create_pool(admin: &signer, input_token_metadata: Object<Metadata>, output_token_metadata: Object<Metadata>, initial_fee_rate: u64, initial_swap_ratio: u64, fee_recipient: address)`
Creates a new swap pool with specified parameters.
- **Requirements**:
    - Caller must be admin
    - Fee rate must be ≤ 10000 (100%)
    - Swap ratio must be between 1 and 10000
    - Pool must not already exist
- **Events**: Emits `CreatePool` event

#### `pause_swap(admin: &signer, pause: bool)`
Pauses or unpauses swap functionality.
- **Requirements**: Caller must be admin, pool must exist
- **Events**: Emits `SwapPauseStatisChanges` event

#### `update_admin(admin: &signer, new_admin: address)`
Transfers admin role to a new address.
- **Requirements**: Caller must be current admin
- **Events**: Emits `AdminUpdated` event

#### `update_swap_fee_rate(admin: &signer, new_swap_fee_rate: u64)`
Updates the swap fee rate.
- **Requirements**: Caller must be admin, fee rate must be ≤ 10000
- **Events**: Emits `SwapFeeRateUpdated` event

#### `update_swap_ratio(admin: &signer, new_swap_ratio: u64)`
Updates the swap ratio.
- **Requirements**: Caller must be admin, ratio must be between 1 and 10000
- **Events**: Emits `SwapRatioUpdated` event

#### `update_fee_recipient(admin: &signer, new_fee_recipient: address)`
Updates the fee recipient address.
- **Requirements**: Caller must be admin, pool must exist
- **Events**: Emits `FeeRecipientUpdated` event

### Liquidity Management

#### `deposit(admin: &signer, amount: u64)`
Deposits output tokens into the pool for swap liquidity.
- **Requirements**: Caller must be admin, amount > 0, pool must exist
- **Events**: Emits `OutputTokenDeposited` event

#### `withdraw(admin: &signer, amount: u64)`
Withdraws output tokens from the pool.
- **Requirements**:
    - Caller must be admin
    - Amount > 0
    - Pool must have sufficient balance
- **Events**: Emits `OutputTokenWithdraw` event

### Swap Functions

#### `swap(user: &signer, amount: u64)`
Performs a standard token swap.
- **Process**:
    1. Transfers input tokens from user to admin
    2. Calculates output amount based on swap ratio
    3. Deducts fees and transfers to fee recipient
    4. Transfers remaining output tokens to user
- **Requirements**:
    - Amount > 0
    - Pool must exist and not be paused
    - Pool must have sufficient output token balance
- **Events**: Emits `Swap` event

#### `swap_sponsor(user: &signer, admin: &signer, amount: u64, swap_gas_fee_amount: u64)`
Performs a sponsored token swap where admin covers transaction costs.
- **Process**:
    1. Same as regular swap
    2. Additionally charges gas fee to cover transaction costs
    3. Both swap fee and gas fee sent to fee recipient
- **Requirements**:
    - Caller must be admin
    - Amount > 0
    - Gas fee amount > 0
    - Pool must exist and not be paused
    - Pool must have sufficient output token balance
    - Total fees must not exceed output amount
- **Events**: Emits `SponsoredSwap` event

## Configuration Constants

- **MAX_FEE_RATE**: 10000 (100%)
- **FEE_PRECISION**: 10000 (basis points)
- **FEE_RATIO_PRECISION**: 10000 (basis points)
- **MAX_SWAP_RATIO**: 10000 (100% = 1:1)
- **MIN_SWAP_RATIO**: 1 (0.01% = 0.0001:1)

## Error Codes

- `EUNAUTHORIZED (1)`: Caller is not authorized
- `EINVALID_FEE_RATE (2)`: Fee rate exceeds maximum (100%)
- `EINSUFFICIENT_BALANCE (3)`: Insufficient pool or user balance
- `EINVALID_AMOUNT (4)`: Amount must be greater than 0
- `EPOOL_NOT_EXISTS (5)`: Swap pool does not exist
- `ENOT_INITIALIZED (6)`: Contract not initialized
- `ESWAP_PAUSED (7)`: Swap functionality is paused
- `EINVALID_GAS_FEE (8)`: Gas fee amount is invalid
- `EFEES_EXCEED_AMOUNT (9)`: Total fees exceed swap output amount
- `EINVALID_SWAP_RATIO (10)`: Swap ratio outside valid range

## Events

The contract emits comprehensive events for all operations:

- **CreatePool**: Pool creation with initial parameters
- **Swap**: Standard swap execution details
- **SponsoredSwap**: Sponsored swap with gas fee details
- **SwapFeeRateUpdated**: Fee rate changes
- **FeeRecipientUpdated**: Fee recipient address changes
- **AdminUpdated**: Admin role transfers
- **OutputTokenDeposited**: Liquidity deposits
- **OutputTokenWithdraw**: Liquidity withdrawals
- **SwapPauseStatisChanges**: Pause state changes
- **SwapRatioUpdated**: Swap ratio modifications

## Usage Examples

### Creating a Pool
```move
// Create pool with 3% fee and 80% swap ratio (0.8:1)
swap::create_pool(
    &admin,
    input_token_metadata,
    output_token_metadata,
    300,  // 3% fee
    8000, // 80% ratio
    fee_recipient_address
);
```

### Adding Liquidity
```move
// Deposit 10,000 output tokens for swapping
swap::deposit(&admin, 10000);
```

### Performing a Swap
```move
// Swap 1,000 input tokens
swap::swap(&user, 1000);
```

### Sponsored Swap
```move
// Admin sponsors user's swap with 50 token gas fee
swap::swap_sponsor(&user, &admin, 1000, 50);
```

### Checking Swap Preview
```move
// Preview swap of 1,000 tokens
let (output_amount, fee_amount) = swap::get_swap_preview(1000);
```
proper # rKGEN Swap Contract

A decentralized token swap contract on Aptos that enables swapping of rKGEN input tokens for KGEN output tokens with configurable fees and ratios.

## Contract Information

- **Module**: `rkgen::swap`
- **Network**: Aptos
- **Input Token**: rKGEN (reward tokens)
- **Output Token**: KGEN (utility tokens)
- **Fee Structure**: Variable basis points (0-100%)
- **Swap Ratio**: Configurable (0.01% to 100% = 0.0001:1 to 1:1)

## Architecture Overview

The rKGEN swap contract implements a single-direction token swap mechanism with administrative controls, fee collection, and sponsored transaction support.

### Core Resources

1. **Admin**: Global administrative control resource
    - Stores the current admin address
    - Required for all administrative operations

2. **SwapPool**: Main pool resource containing swap configuration and state
    - Token metadata references for input and output tokens
    - Swap parameters (fee rate, swap ratio)
    - Pool state (pause status, statistics)
    - Fee recipient configuration
    - Output token store for liquidity management

### Key Features

- **Configurable Swap Ratio**: Flexible ratio from 0.0001:1 to 1:1 (input:output)
- **Dynamic Fee Structure**: Adjustable fees from 0% to 100% in basis points
- **Sponsored Swaps**: Gas fee sponsorship with separate fee handling
- **Pause Mechanism**: Emergency pause functionality for security
- **Liquidity Management**: Admin-controlled deposit and withdrawal of output tokens
- **Comprehensive Statistics**: Tracking of all swap activities and fees
- **Event Emission**: Complete audit trail of all operations

## Function Documentation

### View Functions

#### `get_admin(): address`
Returns the current admin address.
- **Requirements**: Contract must be initialized

#### `get_pool_balance(): u64`
Returns the current output token balance in the pool.
- **Requirements**: Pool must exist

#### `get_swap_fee_rate(): u64`
Returns the current swap fee rate in basis points (e.g., 300 = 3%).
- **Requirements**: Pool must exist

#### `get_swap_ratio(): u64`
Returns the current swap ratio in basis points (e.g., 8000 = 80% = 0.8:1).
- **Requirements**: Pool must exist

#### `get_fee_recipient(): address`
Returns the address that receives swap fees.
- **Requirements**: Pool must exist

#### `is_swap_paused(): bool`
Returns whether swapping is currently paused.
- **Requirements**: Pool must exist

#### `get_total_input_token_swapped(): u64`
Returns the total amount of input tokens swapped since pool creation.
- **Requirements**: Pool must exist

#### `get_total_output_token_swapped(): u64`
Returns the total amount of output tokens distributed since pool creation.
- **Requirements**: Pool must exist

#### `get_total_fee_collected(): u64`
Returns the total fees collected since pool creation.
- **Requirements**: Pool must exist

#### `get_swap_stats(): (u64, u64, u64, u64, u64, bool)`
Returns comprehensive swap statistics as a tuple:
- Total input tokens swapped
- Total output tokens swapped
- Total fees collected
- Current fee rate
- Current swap ratio
- Pause status
- **Requirements**: Pool must exist

#### `get_swap_preview(amount_in: u64): (u64, u64)`
Calculates the expected output amount and fees for a given input amount.
- **Returns**: (amount_out, fee_amount)
- **Requirements**: Pool must exist, amount > 0

#### `get_sponser_swap_preview(amount_in: u64, gas_fee_amount: u64): (u64, u64, u64)`
Calculates the expected output amount and fees for a sponsored swap.
- **Returns**: (amount_out, swap_fee_amount, total_fee_amount)
- **Requirements**: Pool must exist, amount > 0, gas_fee_amount > 0

### Administrative Functions

#### `create_pool(admin: &signer, input_token_metadata: Object<Metadata>, output_token_metadata: Object<Metadata>, initial_fee_rate: u64, initial_swap_ratio: u64, fee_recipient: address)`
Creates a new swap pool with specified parameters.
- **Requirements**:
    - Caller must be admin
    - Fee rate must be ≤ 10000 (100%)
    - Swap ratio must be between 1 and 10000
    - Pool must not already exist
- **Events**: Emits `CreatePool` event

#### `pause_swap(admin: &signer, pause: bool)`
Pauses or unpauses swap functionality.
- **Requirements**: Caller must be admin, pool must exist
- **Events**: Emits `SwapPauseStatisChanges` event

#### `update_admin(admin: &signer, new_admin: address)`
Transfers admin role to a new address.
- **Requirements**: Caller must be current admin
- **Events**: Emits `AdminUpdated` event

#### `update_swap_fee_rate(admin: &signer, new_swap_fee_rate: u64)`
Updates the swap fee rate.
- **Requirements**: Caller must be admin, fee rate must be ≤ 10000
- **Events**: Emits `SwapFeeRateUpdated` event

#### `update_swap_ratio(admin: &signer, new_swap_ratio: u64)`
Updates the swap ratio.
- **Requirements**: Caller must be admin, ratio must be between 1 and 10000
- **Events**: Emits `SwapRatioUpdated` event

#### `update_fee_recipient(admin: &signer, new_fee_recipient: address)`
Updates the fee recipient address.
- **Requirements**: Caller must be admin, pool must exist
- **Events**: Emits `FeeRecipientUpdated` event

### Liquidity Management

#### `deposit(admin: &signer, amount: u64)`
Deposits output tokens into the pool for swap liquidity.
- **Requirements**: Caller must be admin, amount > 0, pool must exist
- **Events**: Emits `OutputTokenDeposited` event

#### `withdraw(admin: &signer, amount: u64)`
Withdraws output tokens from the pool.
- **Requirements**:
    - Caller must be admin
    - Amount > 0
    - Pool must have sufficient balance
- **Events**: Emits `OutputTokenWithdraw` event

### Swap Functions

#### `swap(user: &signer, amount: u64)`
Performs a standard token swap.
- **Process**:
    1. Transfers input tokens from user to admin
    2. Calculates output amount based on swap ratio
    3. Deducts fees and transfers to fee recipient
    4. Transfers remaining output tokens to user
- **Requirements**:
    - Amount > 0
    - Pool must exist and not be paused
    - Pool must have sufficient output token balance
- **Events**: Emits `Swap` event

#### `swap_sponsor(user: &signer, admin: &signer, amount: u64, swap_gas_fee_amount: u64)`
Performs a sponsored token swap where admin covers transaction costs.
- **Process**:
    1. Same as regular swap
    2. Additionally charges gas fee to cover transaction costs
    3. Both swap fee and gas fee sent to fee recipient
- **Requirements**:
    - Caller must be admin
    - Amount > 0
    - Gas fee amount > 0
    - Pool must exist and not be paused
    - Pool must have sufficient output token balance
    - Total fees must not exceed output amount
- **Events**: Emits `SponsoredSwap` event

## Configuration Constants

- **MAX_FEE_RATE**: 10000 (100%)
- **FEE_PRECISION**: 10000 (basis points)
- **FEE_RATIO_PRECISION**: 10000 (basis points)
- **MAX_SWAP_RATIO**: 10000 (100% = 1:1)
- **MIN_SWAP_RATIO**: 1 (0.01% = 0.0001:1)

## Error Codes

- `EUNAUTHORIZED (1)`: Caller is not authorized
- `EINVALID_FEE_RATE (2)`: Fee rate exceeds maximum (100%)
- `EINSUFFICIENT_BALANCE (3)`: Insufficient pool or user balance
- `EINVALID_AMOUNT (4)`: Amount must be greater than 0
- `EPOOL_NOT_EXISTS (5)`: Swap pool does not exist
- `ENOT_INITIALIZED (6)`: Contract not initialized
- `ESWAP_PAUSED (7)`: Swap functionality is paused
- `EINVALID_GAS_FEE (8)`: Gas fee amount is invalid
- `EFEES_EXCEED_AMOUNT (9)`: Total fees exceed swap output amount
- `EINVALID_SWAP_RATIO (10)`: Swap ratio outside valid range

## Events

The contract emits comprehensive events for all operations:

- **CreatePool**: Pool creation with initial parameters
- **Swap**: Standard swap execution details
- **SponsoredSwap**: Sponsored swap with gas fee details
- **SwapFeeRateUpdated**: Fee rate changes
- **FeeRecipientUpdated**: Fee recipient address changes
- **AdminUpdated**: Admin role transfers
- **OutputTokenDeposited**: Liquidity deposits
- **OutputTokenWithdraw**: Liquidity withdrawals
- **SwapPauseStatisChanges**: Pause state changes
- **SwapRatioUpdated**: Swap ratio modifications
