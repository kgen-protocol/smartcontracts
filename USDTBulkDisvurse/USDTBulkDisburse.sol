// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256 balance);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract BulkDisburse is ReentrancyGuard {

    address public admin;
    mapping(address => bool) public owners;

    modifier onlyOwner {
        require(owners[msg.sender] == true, "BA: Unauthorised access");
        _;
    }

    event Disburse(address indexed token, address indexed from, address indexed to, uint256 value);

    constructor(address _owner) {
        admin = _owner;
        owners[_owner] = true;
    }

    function updateOwnerStatus(address _owner, bool _status) external {
        require(msg.sender == admin, "BA: Unauthorised access");
        owners[_owner] = _status;
    }

    function _bulkDisburse(IERC20 token, address[] calldata to, uint256[] calldata value) private {
        require(to.length == value.length, "BA: to & value length mismatch");
        // Removed the code to check the allowance to save on the gas
        for(uint256 i; i < to.length;){
            address toAddresses = to[i];
            uint256 totalValue = value[i];
            require(token.transfer(toAddresses, totalValue), "BA: Disburse Failed");
            emit Disburse(address(token), msg.sender, toAddresses, totalValue);
            unchecked {
                ++i;
            }
        }
    }

    function depositForBulkDisburse(IERC20 token, uint256 totalValue) external onlyOwner nonReentrant {
        require(token.transferFrom(msg.sender, address(this), totalValue), "BA: Transfer Failed");
    }

    function bulkDisburse(IERC20 token, address[] calldata to, uint256[] calldata value) external onlyOwner nonReentrant {
        _bulkDisburse(token, to, value);
    }

    function getTokenBalance(IERC20 token) external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function withdrawNativeToken() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(admin).call{ value: balance }("");
        require(success, "BA: Withdraw native token failed");
    }

    function withdrawERC20(IERC20 token) external onlyOwner nonReentrant {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(admin, balance));
    }
}