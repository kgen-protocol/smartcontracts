//SPDX-License-Identifier: MIT

// ██████╗ ██████╗ ██████╗ ██████╗ ███████╗██╗   ██╗███████╗███╗   ██╗██╗   ██╗███████╗
// ██╔══██╗╚════██╗██╔══██╗██╔══██╗██╔════╝██║   ██║██╔════╝████╗  ██║██║   ██║██╔════╝
// ██████╔╝ █████╔╝██████╔╝██████╔╝█████╗  ██║   ██║█████╗  ██╔██╗ ██║██║   ██║█████╗
// ██╔══██╗██╔═══╝ ██╔══██╗██╔══██╗██╔══╝  ╚██╗ ██╔╝██╔══╝  ██║╚██╗██║██║   ██║██╔══╝
// ██████╔╝███████╗██████╔╝██║  ██║███████╗ ╚████╔╝ ███████╗██║ ╚████║╚██████╔╝███████╗
// ╚═════╝ ╚══════╝╚═════╝ ╚═╝  ╚═╝╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title B2BRevenue
/// @notice A contract for managing B2B revenue streams using whitelisted ERC20 tokens and ETH
/// @dev Implements role-based access control and reentrancy protection using OpenZeppelin contracts
contract B2BRevenue is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error TokenNotWhitelisted(address token);
    error TokenAlreadyWhitelisted(address token);
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientBalance(uint256 requested, uint256 available);
    error InvalidRecipient();

    /// @notice Emitted when tokens are deposited into the contract
    /// @param token The address of the deposited token
    /// @param from The address that deposited the tokens
    /// @param amount The amount of tokens deposited
    event TokenDeposited(
        address indexed token,
        address indexed from,
        uint256 amount
    );

    /// @notice Emitted when tokens are withdrawn from the contract
    /// @param token The address of the withdrawn token
    /// @param to The recipient address
    /// @param amount The amount of tokens withdrawn
    event TokenWithdrawn(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /// @notice Emitted when ETH is withdrawn from the contract
    /// @param to The recipient address
    /// @param amount The amount of ETH withdrawn in wei
    event NativeWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when a token's whitelist status is changed
    /// @param token The address of the token
    /// @param status The new whitelist status (true = whitelisted, false = not whitelisted)
    event TokenWhitelistStatusChanged(address indexed token, bool status);

    /// @notice Role identifier for addresses authorized to withdraw funds
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");

    /// @notice Mapping of token addresses to their whitelist status
    mapping(address => bool) public whitelistedTokens;

    /// @notice Sets up the contract with initial admin and withdrawal permissions
    /// @param _owner Address that will receive both admin and withdrawal rights
    /// @dev The owner address cannot be zero
    constructor(address _owner) payable {
        if (_owner == address(0)) revert ZeroAddress();
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(WITHDRAW_ROLE, _owner);
    }

    /// @notice Deposits whitelisted ERC20 tokens into the contract
    /// @param _token The address of the whitelisted ERC20 token
    /// @param _amount The amount of tokens to deposit
    /// @dev Requires prior token approval from the sender
    function depositToken(address _token, uint256 _amount) external {
        if (!whitelistedTokens[_token]) revert TokenNotWhitelisted(_token);
        if (_amount == 0) revert InvalidAmount();
        if (msg.sender == address(0)) revert ZeroAddress();
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit TokenDeposited(_token, msg.sender, _amount);
    }

    /// @notice Withdraws whitelisted ERC20 tokens from the contract
    /// @param _token The address of the whitelisted ERC20 token
    /// @param _to The recipient address
    /// @param _amount The amount of tokens to withdraw
    /// @dev Only callable by addresses with WITHDRAW_ROLE. Protected against reentrancy
    function withdrawToken(
        address _token,
        address _to,
        uint256 _amount
    ) external nonReentrant onlyRole(WITHDRAW_ROLE) {
        if (_token == address(0)) revert ZeroAddress();
        if (!whitelistedTokens[_token]) revert TokenNotWhitelisted(_token);
        if (_to == address(0)) revert InvalidRecipient();
        if (_amount == 0) revert InvalidAmount();
        IERC20(_token).safeTransfer(_to, _amount);
        emit TokenWithdrawn(_token, _to, _amount);
    }

    /// @notice Withdraws ETH from the contract
    /// @param to The recipient address
    /// @param amount The amount of ETH to withdraw in wei
    /// @dev Only callable by addresses with WITHDRAW_ROLE. Protected against reentrancy
    function withdrawNative(
        address payable to,
        uint256 amount
    ) public nonReentrant onlyRole(WITHDRAW_ROLE) {
        if (to == address(0)) revert InvalidRecipient();
        if (address(this).balance < amount)
            revert InsufficientBalance(amount, address(this).balance);
        (bool success, ) = to.call{value: amount}("");
        require(success, "Native transfer failed");
        emit NativeWithdrawn(to, amount);
    }

    /// @notice Adds an ERC20 token to the whitelist
    /// @param _token The address of the ERC20 token to whitelist
    /// @dev Only callable by addresses with DEFAULT_ADMIN_ROLE. Validates token contract by checking totalSupply
    function addWhitelistedToken(
        address _token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (whitelistedTokens[_token]) revert TokenAlreadyWhitelisted(_token);
        if (_token == address(0)) revert ZeroAddress();
        
        // Add basic token validation
        try IERC20(_token).totalSupply() returns (uint256) {
            // Continue only if the call succeeds
            whitelistedTokens[_token] = true;
            emit TokenWhitelistStatusChanged(_token, true);
        } catch {
            revert("Invalid token contract");
        }
    }

    /// @notice Removes an ERC20 token from the whitelist
    /// @param _token The address of the ERC20 token to remove
    /// @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
    function removeWhitelistedToken(
        address _token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!whitelistedTokens[_token]) revert TokenNotWhitelisted(_token);
        whitelistedTokens[_token] = false;
        emit TokenWhitelistStatusChanged(_token, false);
    }

    /// @notice Gets the balance of a specified token held by this contract
    /// @param _token The address of the ERC20 token
    /// @return The balance of tokens held by this contract
    function getTokenBalance(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}
