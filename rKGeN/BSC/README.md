# rKGEN Token Smart Contract

This is the EVM implementation of the rKGEN token, originally deployed on Aptos blockchain. The contract implements a role-based access control system with whitelist functionality for transfers.

## Features

- ERC20 token with 8 decimals
- Role-based access control
- Whitelist system for transfers
- Treasury management
- Admin nomination system
- Account freezing capability
- Burn functionality
- Upgradeable contract (UUPS pattern)

## Roles

1. **Admin**: Primary controller of the contract
2. **Minter**: Can mint new tokens (multisig wallet)
3. **BurnVault**: Special address that can burn tokens
4. **Treasury**: Can receive minted tokens
5. **Whitelist Sender**: Can send tokens to anyone
6. **Whitelist Receiver**: Can receive tokens from anyone
7. **Upgrader**: Can upgrade the contract implementation

## Contract Functions

### Token Management
- `mint(address to, uint256 amount)`: Mint tokens to a treasury address
- `burn(address from, uint256 amount)`: Burn tokens from the burn vault
- `transfer(address to, uint256 amount)`: Transfer tokens with whitelist restrictions
- `transferFrom(address from, address to, uint256 amount)`: Transfer tokens with whitelist restrictions

### Role Management
- `nominateAdmin(address newAdmin)`: Nominate a new admin
- `acceptAdminRole()`: Accept admin role
- `updateMinter(address newMinter)`: Update minter address
- `updateBurnVault(address newBurnVault)`: Update burn vault address

### Treasury Management
- `addTreasuryAddress(address newAddress)`: Add new treasury address
- `removeTreasuryAddress(address treasuryAddress)`: Remove treasury address

### Whitelist Management
- `addWhitelistSender(address newAddress)`: Add whitelist sender
- `removeWhitelistSender(address senderAddress)`: Remove whitelist sender
- `addWhitelistReceiver(address newAddress)`: Add whitelist receiver
- `removeWhitelistReceiver(address receiverAddress)`: Remove whitelist receiver

### Account Management
- `freezeAccount(address account)`: Freeze an account
- `unfreezeAccount(address account)`: Unfreeze an account

## Installation

1. Clone the repository
2. Install dependencies:
```bash
npm install
```

## Testing

Run the test suite:
```bash
npm test
```

## Deployment

1. Configure your network settings in `hardhat.config.js`
2. Deploy the contract:
```bash
npm run deploy
```

## Upgrading

To upgrade the contract:

1. Make your changes to the contract code
2. Set the PROXY_ADDRESS environment variable:
```bash
export PROXY_ADDRESS=<your-proxy-address>
```
3. Run the upgrade script:
```bash
npx hardhat run scripts/upgrade.js --network <network-name>
```

## Security

The contract implements several security features:
- Role-based access control
- Input validation
- Reentrancy protection
- Account freezing capability
- Whitelist restrictions
- Upgradeable with UUPS pattern
- Initialization protection

## License

MIT
