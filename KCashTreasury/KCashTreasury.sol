//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces/IKCash.sol";

contract KCashTreasury is Ownable2Step {
    IKCash public kcash;
    uint8 public treasuryType;

    constructor(address _kcash, address _owner, uint8 _treasuryType) {
        kcash = IKCash(_kcash);
        treasuryType = _treasuryType;
        _transferOwnership(_owner);
    }

    function updateKcash(address _kcash) external onlyOwner {
        kcash = IKCash(_kcash);
    }

    function withdraw() external onlyOwner {
        kcash.transfer(owner(), kcash.balanceOf(address(this)));
    }

    function addReward3(uint256 _amount) external onlyOwner {
       kcash.adminTransferFrom(msg.sender, address(this), IKCash.Bucket(0,0,_amount));
    }

    function bulkDisburse(
        address[] calldata _to,
        uint256[] calldata _amounts
    ) external onlyOwner {
        require(_to.length == _amounts.length, "Array length mismatch");
        if (treasuryType == 1) {
            kcash.adminTransferFromReward3ToReward1Bulk(_to, _amounts);
        } else if (treasuryType == 2) {
            kcash.adminTransferFromReward3ToReward2Bulk(_to, _amounts);
        } else {
            kcash.transferReward3ToReward3Bulk(_to, _amounts);
        }
    }

    function setTreasuryType(uint8 _treasuryType) external onlyOwner {
        treasuryType = _treasuryType;
    }
}
