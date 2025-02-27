//SPDX-License-Identifier: MIT

//   _  __ _____ _                   _    _  _____ _____ _______   _______                                  
//  | |/ // ____| |                 | |  | |/ ____|  __ \__   __| |__   __|                                 
//  | ' /| (___ | |_ ___  _ __ ___  | |  | | (___ | |  | | | |       | |_ __ ___  __ _ ___ _   _ _ __ _   _ 
//  |  <  \___ \| __/ _ \| '__/ _ \ | |  | |\___ \| |  | | | |       | | '__/ _ \/ _` / __| | | | '__| | | |
//  | . \ ____) | || (_) | | |  __/ | |__| |____) | |__| | | |       | | | |  __/ (_| \__ \ |_| | |  | |_| |
//  |_|\_\_____/ \__\___/|_|  \___|  \____/|_____/|_____/  |_|       |_|_|  \___|\__,_|___/\__,_|_|   \__, |
//                                                                                                     __/ |
//                                                                                                    |___/ 


pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title USDTTreasury
/// @notice A contract for managing USDT deposits and withdrawals
/// @dev Implements AccessControl for role-based authorization
contract USDTTreasury is AccessControl {
    using SafeERC20 for IERC20;
    IERC20 public usdt;
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");

    /// @notice Constructor initializes the contract with USDT token address
    /// @param _usdt The address of the USDT token contract
    constructor(address _usdt) {
        require(_usdt != address(0), "Zero address not allowed");
        usdt = IERC20(_usdt);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(WITHDRAW_ROLE, msg.sender);
    }

    /// @notice Allows users to deposit USDT into the treasury
    /// @param _amount The amount of USDT to deposit
    /// @dev Requires prior approval of USDT token
    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        usdt.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Allows authorized users to withdraw USDT from the treasury
    /// @param _amount The amount of USDT to withdraw
    /// @param _to The address to receive the withdrawn USDT
    /// @dev Only accounts with WITHDRAW_ROLE can call this function
    function withdraw(
        uint256 _amount,
        address _to
    ) external onlyRole(WITHDRAW_ROLE) {
        require(_amount > 0, "Amount must be greater than 0");
        require(_to != address(0), "Cannot withdraw to zero address");
        require(usdt.balanceOf(address(this)) >= _amount, "Insufficient balance");
        usdt.safeTransfer(_to, _amount);
    }

    function setUSDT(address _usdt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        usdt = IERC20(_usdt);
    }
    

    /// @notice Recovers any ERC20 tokens accidentally sent to the contract
    /// @param _token The address of the ERC20 token to recover
    /// @param _amount The amount of tokens to recover
    /// @dev Only callable by admin role
    function recoverERC20(
        address _token,
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    /// @notice Recovers any native tokens (ETH) accidentally sent to the contract
    /// @dev Only callable by admin role
    function recoverNative() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Failed to send Ether");
    }
}
