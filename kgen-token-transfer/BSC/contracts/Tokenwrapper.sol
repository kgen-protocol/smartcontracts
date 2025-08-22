// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
contract KgenAdminTokenWrapper is ReentrancyGuard, ERC2771Context, AccessControl {
    
    // Roles - similar to Aptos resource-based permissions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
    
    // Error codes
    error TokenNotWhitelisted();
    error InsufficientBalance();
    error InvalidAddress();
    error ZeroAmount();
    error TokenAlreadyWhitelisted();
    

    
    /**
     * @dev Constructor
     * @param trustedForwarder The address of the trusted forwarder for meta transactions
     */
    constructor(address trustedForwarder) 
        ERC2771Context(trustedForwarder) 
    {
        address deployer = _msgSender();
        
        // Grant all roles to deployer (similar to Aptos initial capabilities)
        _grantRole(DEFAULT_ADMIN_ROLE, deployer);
        _grantRole(ADMIN_ROLE, deployer);
        _grantRole(WITHDRAWER_ROLE, deployer);
    }
    
    /**
     * @dev Transfer KGEN tokens with gas fee deduction - supports meta transactions
     * Core logic from original Aptos function
     */
    function transferKgenToken(
        address tokenAddress,
        address treasury,
        address recipientAddress,
        uint256 gasFee,
        uint256 amount
    ) 
        external 
        nonReentrant 
    {
        if (tokenAddress == address(0)) revert InvalidAddress();
        if (treasury == address(0)) revert InvalidAddress();
        if (recipientAddress == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAmount();
        
        IERC20 token = IERC20(tokenAddress);
        address sender = _msgSender(); // ERC2771 compatible
        
        // Check balance (like Aptos balance check)
        uint256 totalRequired = amount + gasFee;
        if (token.balanceOf(sender) < totalRequired) revert InsufficientBalance();
        
        // Core transfer logic - matches Aptos withdraw/deposit pattern
        require(token.transferFrom(_msgSender(),recipientAddress, amount), "Transfer failed");
        
        if (gasFee > 0) {
            require(token.transferFrom(_msgSender(),treasury, gasFee), "Gas fee transfer failed");
        }
        
        emit TokenTransferred(sender, recipientAddress, treasury, tokenAddress, amount, gasFee);
    }
    

 
    
      /**
     * @notice Override _msgSender to support ERC2771 meta-transactions
     * @return Original sender address from meta-transaction data
     */
    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    /**
     * @notice Override _msgData to support ERC2771 meta-transactions
     * @return Original calldata from meta-transaction data
     */
    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @notice Override _contextSuffixLength to support ERC2771 meta-transactions
     * @return Context suffix length for meta-transactions
     */
    function _contextSuffixLength() internal view virtual override(Context, ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
    // Events
    event TokenTransferred(
        address indexed sender,
        address indexed recipient,
        address indexed treasury,
        address tokenAddress,
        uint256 amount,
        uint256 gasFee
    );
    
    event TokenWhitelisted(address indexed tokenAddress);
    event TokenRemovedFromWhitelist(address indexed tokenAddress);
    event TrustedForwarderUpdated(address indexed newForwarder);
}