//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import "./KCashTreasury.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract KCashTreasuryFactory is Ownable2Step {
    struct TreasuryData {
        string name;
        address deployedAddress;
    }

    TreasuryData[] public treasuries;

    event TreasuryCreated(address indexed treasury, address indexed kcash);

    function createTreasury(
        string calldata _name,
        address _kcash,
        uint8 _treasuryType
    ) external onlyOwner returns (address) {
        KCashTreasury treasury = new KCashTreasury(
            _kcash,
            msg.sender,
            _treasuryType
        );
        treasuries.push(TreasuryData(_name, address(treasury)));
        emit TreasuryCreated(address(treasury), _kcash);
        return address(treasury);
    }

    function getTreasuryCount() external view returns (uint256) {
        return treasuries.length;
    }

    function getTreasury(
        uint256 _index
    ) external view returns (TreasuryData memory) {
        return treasuries[_index];
    }

    function getTreasuryPage(
        uint256 _page,
        uint256 _perPage
    ) external view returns (TreasuryData[] memory) {
        TreasuryData[] memory page = new TreasuryData[](_perPage);
        uint256 start = _page * _perPage;
        uint256 end = start + _perPage;
        if (end > treasuries.length) {
            end = treasuries.length;
        }
        for (uint256 i = start; i < end; i++) {
            page[i - start] = treasuries[i];
        }
        return page;
    }
}
