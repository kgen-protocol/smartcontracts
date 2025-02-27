//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUSDTTreasury {
    /// @notice The USDT token contract
    /// @return The IERC20 interface of the USDT token
    function usdt() external view returns (IERC20);

    /// @notice The role hash for withdrawal permissions
    /// @return The bytes32 hash representing the WITHDRAW_ROLE
    function WITHDRAW_ROLE() external view returns (bytes32);

    /// @notice Deposits USDT into the treasury
    /// @param _amount The amount of USDT to deposit
    /// @dev Requires approval for the USDT transfer
    function deposit(uint256 _amount) external;

    /// @notice Withdraws USDT from the treasury to a specified address
    /// @param _amount The amount of USDT to withdraw
    /// @param _to The address to receive the USDT
    /// @dev Only callable by addresses with WITHDRAW_ROLE
    function withdraw(uint256 _amount, address _to) external;

    /// @notice Recovers any ERC20 tokens accidentally sent to the contract
    /// @param _token The address of the ERC20 token to recover
    /// @param _amount The amount of tokens to recover
    /// @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
    function recoverERC20(address _token, uint256 _amount) external;

    /// @notice Recovers any native tokens (ETH) accidentally sent to the contract
    /// @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
    function recoverNative() external;
}