//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FundDistributor is AccessControl {
    using SafeERC20 for IERC20;
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    function bulkDisburse(
        address[] calldata to,
        uint256[] calldata value,
        address token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to.length == value.length, "FD: to & value length mismatch");
        IERC20 tokenInstance = IERC20(token);
        for (uint256 i; i < to.length; ) {
            address toAddresses = to[i];
            uint256 totalValue = value[i];
            tokenInstance.safeTransfer(toAddresses, totalValue);
            unchecked {
                ++i;
            }
        }
    }

    function withdrawToken(
        IERC20 token,
        uint256 totalValue
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token.safeTransfer(msg.sender, totalValue);
    }
}
