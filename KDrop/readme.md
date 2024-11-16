# KDrop Contract Documentation

## Overview
KDrop is a Solidity smart contract designed to facilitate token airdrops (KCash, USDT, and other ERC20 tokens) using EIP712 signatures for claim verification. The contract inherits from Ownable2Step for secure ownership management and KDropSigner for signature validation functionality.

## Key Features
- EIP712 signature-based claim verification
- Support for multiple token types (KCash and ERC20)
- Signature tracking to prevent replay attacks
- Owner-controlled token deposit and withdrawal
- Event emission for tracking claims

## Contract Architecture

### Dependencies
- `Ownable2Step`: OpenZeppelin contract for secure ownership transfers
- `IERC20`: Standard ERC20 interface
- `IKCash`: Custom interface for KCash token
- `KDropSigner`: Custom contract implementing EIP712 signature validation

### State Variables
- `designatedSiger`: Address authorized to sign airdrop claims
- `kcash`: Interface to interact with KCash token
- `usedSignatures`: Mapping to track used signatures

## Core Functions

### Constructor
```solidity
constructor(address _designatedSigner, address _kcash)
```
Initializes the contract with the designated signer and KCash token address.

### Administrative Functions
```solidity
setDesignatedSigner(address _designatedSigner)
```
Allows owner to update the designated signer address.

```solidity
depositToken(uint256 _amount, address _rewardToken)
```
Enables owner to deposit ERC20 tokens into the contract.

```solidity
withdrawToken(uint256 _amount, address _rewardToken)
```
Permits owner to withdraw ERC20 tokens from the contract.

```solidity
updateKCash(address _kcash)
```
Allows owner to update the KCash token contract address.

### User-Facing Functions
```solidity
claimAirDrop(Signature calldata _signature)
```
Main function for users to claim airdrops:
- Validates the provided EIP712 signature
- Checks if signature has been used
- Transfers tokens based on token type (KCash or ERC20)
- Emits airdrop claim event

## Events
```solidity
event airdropClaimed(
    address userAddress,
    address rewardToken,
    string userId,
    uint256 rewardAmount,
    string campaignId
)
```
Emitted when an airdrop is successfully claimed, containing claim details.
