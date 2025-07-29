# KGEN Token Contract

KGEN token implementation on Aptos that follows the latest fungible asset standard, with features for freezing, minting, burning, and admin control.

## Token Information

- **Name**: KGEN
- **Symbol**: KGEN
- **Decimals**: 8
- **Max Supply**: 1,000,000,000 (1 billion)

## Architecture Overview

The KGEN token is built using Aptos's modern fungible asset framework with the following key components:

### Core Resources

1. **KgenManagement**: The main resource that stores all administrative controls and references
   - Contains mint, burn, transfer, and metadata mutation references
   - Manages admin, pending admin, and burn vault addresses
   - Tracks frozen accounts for sending and receiving
   - Maintains lists of treasury and minter addresses
   - Controls pause state

### Key Features

- **Multi-level Access Control**: Admin, minters, and treasury addresses with distinct permissions
- **Account Freezing**: Granular control over account sending and receiving capabilities
- **Pause Mechanism**: Global pause functionality for emergency situations
- **Burn Vault**: Dedicated address for token burning operations
- **Metadata Management**: Ability to update project and icon URIs
- **Primary Store Support**: Fungible Asset with Primary Store Support. When users transfer fungible assets to each other, their primary stores will be created automatically if they don't exist.

## Function Documentation

### View Functions

#### `kgen_address(): address`
Returns the address of the KGEN token object.

#### `metadata(): Object<Metadata>`
Returns the metadata object of the KGEN token.

#### `admin(): address`
Returns the current admin address.

#### `is_paused(): bool`
Returns whether the token is currently paused.

#### `is_frozen(account: address): (bool, bool)`
Returns a tuple indicating if an account is frozen for sending (first bool) and receiving (second bool).

#### `burn_vault(): address`
Returns the current burn vault address.

### Administrative Functions

#### `mint(minter: &signer, to: address, amount: u64)`
Mints new tokens to a treasury address.
- **Requirements**: Caller must be a minter, recipient must be a treasury address
- **Events**: Emits `Mint` event

#### `mutate_project_and_icon_uri(admin: &signer, project_uri: String, icon_uri: String)`
Updates the project and icon URIs of the token.
- **Requirements**: Caller must be admin

#### `transfer_admin(admin: &signer, new_admin: address)`
Initiates admin transfer to a new address.
- **Requirements**: Caller must be current admin, new admin must be different
- **Events**: Emits `TransferAdmin` event

#### `accept_admin(pending_admin: &signer)`
Accepts the admin role by the pending admin.
- **Requirements**: Caller must be the pending admin
- **Events**: Emits `AcceptAdmin` event

#### `set_pause(admin: &signer, is_paused: bool)`
Sets the global pause state of the token.
- **Requirements**: Caller must be admin
- **Events**: Emits `UpdatePause` event

### Treasury Management

#### `add_treasury_address(admin: &signer, new_treasury_addr: address)`
Adds a new address to the treasury list.
- **Requirements**: Caller must be admin, address must not already exist
- **Events**: Emits `AddTreasuryAddress` event

#### `remove_treasury_address(admin: &signer, treasury_addr: address)`
Removes an address from the treasury list.
- **Requirements**: Caller must be admin, address must be in treasury list
- **Events**: Emits `RemoveTreasuryAddress` event

### Minter Management

#### `add_minter(admin: &signer, new_minter_addr: address)`
Adds a new address to the minter list.
- **Requirements**: Caller must be admin, address must not already exist
- **Events**: Emits `AddMinterAddress` event

#### `remove_minter_address(admin: &signer, minter_addr: address)`
Removes an address from the minter list.
- **Requirements**: Caller must be admin, address must be in minter list
- **Events**: Emits `RemoveMinterAddress` event

### Account Freezing

#### `freeze_accounts(admin: &signer, accounts: vector<address>, sending_flags: vector<bool>, receiving_flags: vector<bool>)`
Freezes multiple accounts for sending and/or receiving.
- **Requirements**: Caller must be admin, all vectors must have same length
- **Events**: Emits `Freeze` event for each account

#### `unfreeze_accounts(admin: &signer, accounts: vector<address>, unfreeze_sending: vector<bool>, unfreeze_receiving: vector<bool>)`
Unfreezes multiple accounts for sending and/or receiving.
- **Requirements**: Caller must be admin, all vectors must have same length
- **Events**: Emits `Unfreeze` event for each account

### Transfer Functions

#### `transfer(admin: &signer, from: address, to: address, amount: u64)`
Transfers tokens from a frozen account (admin override).
- **Requirements**: Caller must be admin, from account must be frozen

#### `transfer_store(admin: &signer, from_store: Object<FungibleStore>, to: address, amount: u64)`
Transfers tokens from a specific store of a frozen account.
- **Requirements**: Caller must be admin, store owner must be frozen

### Burning Functions

#### `burn(admin: &signer, account: address, amount: u64)`
Burns tokens from the burn vault account.
- **Requirements**: Caller must be admin, account must be burn vault
- **Events**: Emits `Burn` event

#### `burn_store(admin: &signer, store: Object<FungibleStore>, amount: u64)`
Burns tokens from a specific store.
- **Requirements**: Caller must be admin, store owner must be burn vault
- **Events**: Emits `Burn` event

### Configuration

#### `update_burn_vault(admin: &signer, new_burn_vault: address)`
Updates the burn vault address.
- **Requirements**: Caller must be admin
- **Events**: Emits `UpdateBurnVault` event

### Override Functions

#### `deposit<T: key>(store: Object<T>, fa: FungibleAsset, transfer_ref: &TransferRef)`
Override of the default FA deposit function to enforce pause and freeze checks.
- **Requirements**: Token must not be paused, recipient must not be frozen for receiving

#### `withdraw<T: key>(store: Object<T>, amount: u64, transfer_ref: &TransferRef): FungibleAsset`
Override of the default FA withdraw function to enforce pause and freeze checks.
- **Requirements**: Token must not be paused, sender must not be frozen for sending

## Error Codes

- `EUNAUTHORIZED (1)`: Caller is not authorized
- `EFROZEN (2)`: Account is frozen
- `EFROZEN_SENDING (3)`: Account is frozen for sending
- `EFROZEN_RECEIVING (4)`: Account is frozen for receiving
- `ENOT_FROZEN (5)`: Account is not frozen
- `EARGUMENT_VECTORS_LENGTH_MISMATCH (6)`: Vector length mismatch
- `ESAME_ADMIN (7)`: Cannot transfer admin to same address
- `EINVALID_ASSET (8)`: Invalid asset
- `ENOT_BURNVAULT (9)`: Address is not burn vault
- `EALREADY_EXIST (10)`: Address already exists
- `ENOT_TREASURY_ADDRESS (11)`: Address is not treasury
- `ENOT_MINTER_ADDRESS (12)`: Address is not minter
- `EPAUSED (13)`: Token is paused

## Events

The contract emits comprehensive events for all major operations:
- `Mint`: When tokens are minted
- `Burn`: When tokens are burned
- `Freeze`: When accounts are frozen
- `Unfreeze`: When accounts are unfrozen
- `TransferAdmin`: When admin transfer is initiated
- `AcceptAdmin`: When admin transfer is accepted
- `AddTreasuryAddress`: When treasury address is added
- `RemoveTreasuryAddress`: When treasury address is removed
- `AddMinterAddress`: When minter address is added
- `RemoveMinterAddress`: When minter address is removed
- `UpdateBurnVault`: When burn vault is updated
- `UpdatePause`: When pause state is updated