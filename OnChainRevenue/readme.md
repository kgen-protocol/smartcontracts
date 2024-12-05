# OnChainRevenue

## Overview

OnChainRevenue is a smart contract solution for managing B2B revenue streams on the Ethereum blockchain. It provides a secure and flexible way to handle payments in both ERC20 tokens and native ETH.

## Features

- **Multi-Token Support**: Accept payments in whitelisted ERC20 tokens
- **Native ETH Support**: Handle native ETH transactions
- **Role-Based Access Control**: Secure administration and withdrawal permissions
- **Reentrancy Protection**: Built-in security against reentrancy attacks
- **Token Whitelist Management**: Flexible control over accepted tokens
- **Event Logging**: Comprehensive event emission for all important actions

## Smart Contracts

### B2BRevenue.sol

The main contract that handles all revenue operations. It implements:

- Token deposits and withdrawals
- Native ETH withdrawals
- Token whitelist management
- Role-based access control
- Balance checking functionality

## Security Features

- OpenZeppelin's `AccessControl` for role management
- OpenZeppelin's `ReentrancyGuard` for transaction safety
- OpenZeppelin's `SafeERC20` for secure token transfers
- Custom error handling for clear error messages
- Token validation before whitelisting
- Zero-address checks
- Balance verification

## Roles

- **DEFAULT_ADMIN_ROLE**: Can manage token whitelist and assign roles
- **WITHDRAW_ROLE**: Can withdraw tokens and ETH from the contract

## Events

- `TokenDeposited`: Emitted when tokens are deposited
- `TokenWithdrawn`: Emitted when tokens are withdrawn
- `NativeWithdrawn`: Emitted when ETH is withdrawn
- `TokenWhitelistStatusChanged`: Emitted when token whitelist status changes





