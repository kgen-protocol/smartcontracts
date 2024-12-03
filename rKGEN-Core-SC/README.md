## Aptos Move Project: Building rKGEN Fungible Asset

Welcome to the Aptos Move Project! In this project, we are building a rKGEN fungible asset.

#### Overview

The rKGEN token is designed to represent a fungible asset on the Aptos blockchain. The token will comply with the Aptos Fungible Asset (FA) Standard and include mechanisms for controlled minting, burning, and transferability. The contract leverages Move language features, role-based access control (RBAC), and multisig wallet security.

### Installation

##### For use in Node.js or a web application

Install with your favorite package manager such as npm, yarn, or pnpm:

Here 'npm' is used

1. Navigate to the typescript directory and Install there as well.

   ```bash
   cd rKGEN-Core-SC
   ```

   ```bash
   npm install
   ```

To install Jest for testing, run below command:

```bash
cd test
npm test
```

## Token Deployment

To deploy or publish your token, follow these steps:

- Navigate :

```bash
cd rKGEN-Core-SC
```

- Run script file:

```bash
npx ts-node rKGEN.ts
```

## Creating Keys

To generate keys including public key, private key, and address for all users including admins, run the following command:

```bash
cd rKGEN-Core-SC
```

```bash
npx ts-node createKeys.ts
```

## Creating new Multisig Address

To generate keys including public key, private key, and address for all users including admins, run the following command:

```bash
cd rKGEN-Core-SC
```

```bash
npx ts-node multisig.ts
```

## Testing

1. Navigate to the typescript folder.

```bash
cd rKGEN-Core-SC
```

2. Run the following command to test:

```bash
cd test
npm test
```

## Update Network

1. Also Update in Typescript file.
   ```bash
   // Setup the client
   const APTOS_NETWORK: Network = NetworkToNetworkName[Network.DEVNET];
   ```
   And update Devnet with Testnet or Mainnet.
   ```bash
   // Setup the client
   const APTOS_NETWORK: Network = NetworkToNetworkName[Network.TESTNET];
   ```

## Compiling the code

1. Navigate to the facoin folder using following command.

   ```bash
   cd rKGEN-Core-SC/move
   ```

2. Now run the command, here you can use any address of user.

   ```bash
   aptos move compile --dev
   ```

# rKGEN Module Functions

## Functions to Fetch On-Chain Data

1. **`get_admin()`**  
   Fetches the admin address from the Move smart contract.

2. **`get_minter()`**  
   Fetches the minter address from the Move smart contract.

3. **`getTreasuryAddress()`**  
   Fetches the treasury addresses in a vector from the Move smart contract.

4. **`getWhitelistedSender()`**  
   Fetches the list of whitelisted senders from the Move smart contract.

5. **`getWhitelistedReceiver()`**  
   Fetches the list of whitelisted receivers from the Move smart contract.

6. **`getMetadata()`**  
   Fetches metadata from the Move smart contract.

## Admin-Only Functions

1. **`update_admin(admin_addr: &signer, new_admin: address)`**  
   Updates the admin of the module.

2. **`update_minter(admin: &signer, new_minter: address)`**  
   Updates the minter address.

3. **`add_treasury_address(admin: &signer, new_address: address)`**  
   Adds a new address to the treasury.

4. **`remove_treasury_address(admin: &signer, treasury_address: address)`**  
   Removes an existing address from the treasury.

5. **`add_whitelist_sender(admin: &signer, new_address: address)`**  
   Adds a new address to the whitelist of senders.

6. **`remove_whitelist_sender(admin: &signer, sender_address: address)`**  
   Removes an existing address from the whitelist of senders.

7. **`add_whitelist_receiver(admin: &signer, new_address: address)`**  
   Adds a new address to the whitelist of receivers.

8. **`remove_whitelist_receiver(admin: &signer, receiver_address: address)`**  
   Removes an existing address from the whitelist of receivers.

9. **`freeze_account(admin: &signer, account: address)`**  
   Freezes an account, preventing it from transferring or receiving fungible assets.

10. **`unfreeze_account(admin: &signer, account: address)`**  
    Unfreezes an account, allowing it to transfer or receive fungible assets.

11. **`burn(admin: &signer, from: address, amount: u64)`**  
    Burns fungible assets from a specified address.

## Other Entry Functions

1. **`mint(admin: &signer, to: address, amount: u64)`**  
   Mints tokens as the minter role and deposits them into a specified account. Only a multisig wallet can invoke this function.

2. **`transfer_from_whitelist_sender(sender_address: &signer, receiver: address, amount: u64)`**  
   Transfers tokens from a whitelisted sender. Only addresses in the sender whitelist can perform this action.

3. **`transfer_to_whitelist_receiver(sender_address: &signer, receiver: address, amount: u64)`**  
   Transfers tokens to a whitelisted receiver. Anyone can invoke this function, but the receiver must be in the whitelist.

4. **`transfer(sender: &signer, receiver: address, amount: u64)`**  
   Performs a generic transfer. The function checks if the sender or receiver is in the whitelist before executing the transfer.
