//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BulkNative is Ownable {
    function bulkSend(
        address[] calldata _recipients,
        uint256[] calldata _amounts
    ) external payable {
        require(
            _recipients.length == _amounts.length,
            "BulkNative: Invalid input"
        );
        for (uint256 i = 0; i < _recipients.length; i++) {
            payable(_recipients[i]).transfer(_amounts[i]);
        }
        uint balanceAfterTransfer = address(this).balance;
        if (balanceAfterTransfer > 0) {
            payable(owner()).transfer(balanceAfterTransfer);
        }
    }

    function bulkFetch(
        address[] calldata _recipients
    ) external view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](_recipients.length);
        for (uint256 i = 0; i < _recipients.length; i++) {
            balances[i] = _recipients[i].balance;
        }
        return balances;
    }

    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}
