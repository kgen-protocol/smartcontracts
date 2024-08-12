//SPDX-License-Identifier: UNLICENSED

//  $$$$$$\  $$\                         $$\ $$\  $$$$$$\  $$\                 $$\             $$$$$$$\                                                        $$\
// $$  __$$\ \__|                        $$ |\__|$$  __$$\ \__|                $$ |            $$  __$$\                                                       $$ |
// $$ /  \__|$$\ $$$$$$\$$$$\   $$$$$$\  $$ |$$\ $$ /  \__|$$\  $$$$$$\   $$$$$$$ |            $$ |  $$ |$$$$$$\  $$\   $$\ $$$$$$\$$$$\   $$$$$$\  $$$$$$$\ $$$$$$\
// \$$$$$$\  $$ |$$  _$$  _$$\ $$  __$$\ $$ |$$ |$$$$\     $$ |$$  __$$\ $$  __$$ |            $$$$$$$  |\____$$\ $$ |  $$ |$$  _$$  _$$\ $$  __$$\ $$  __$$\\_$$  _|
//  \____$$\ $$ |$$ / $$ / $$ |$$ /  $$ |$$ |$$ |$$  _|    $$ |$$$$$$$$ |$$ /  $$ |            $$  ____/ $$$$$$$ |$$ |  $$ |$$ / $$ / $$ |$$$$$$$$ |$$ |  $$ | $$ |
// $$\   $$ |$$ |$$ | $$ | $$ |$$ |  $$ |$$ |$$ |$$ |      $$ |$$   ____|$$ |  $$ |            $$ |     $$  __$$ |$$ |  $$ |$$ | $$ | $$ |$$   ____|$$ |  $$ | $$ |$$\
// \$$$$$$  |$$ |$$ | $$ | $$ |$$$$$$$  |$$ |$$ |$$ |      $$ |\$$$$$$$\ \$$$$$$$ |            $$ |     \$$$$$$$ |\$$$$$$$ |$$ | $$ | $$ |\$$$$$$$\ $$ |  $$ | \$$$$  |
//  \______/ \__|\__| \__| \__|$$  ____/ \__|\__|\__|      \__| \_______| \_______|            \__|      \_______| \____$$ |\__| \__| \__| \_______|\__|  \__|  \____/
//                             $$ |                                                                               $$\   $$ |
//                             $$ |                                                                               \$$$$$$  |
//                             \__|                                                                                \______/

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces/IKCash.sol";

contract SimplifiedPayment is AccessControl {
    event KCashPayment(string entityName, uint256 totalAmount);
    event USDTPayment(string entityName, uint256 totalAmount);

    bytes32 public constant ANDMIN_TRANSFER_ROLE =
        keccak256("ANDMIN_TRANSFER_ROLE");
    IKCash public kcash;
    IERC20 public usdt;
    uint8 public treasuryType;
    address public treasury;

    constructor(
        address _kcash,
        address _usdt,
        address _owner,
        address _treasury,
        uint8 _treasuryType
    ) {
        kcash = IKCash(_kcash);
        usdt = IERC20(_usdt);
        treasury = _treasury;
        treasuryType = _treasuryType;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ANDMIN_TRANSFER_ROLE, _owner);
    }

    function updateKcash(address _kcash) external onlyRole(DEFAULT_ADMIN_ROLE) {
        kcash = IKCash(_kcash);
    }

    function updateUsdt(address _usdt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        usdt = IERC20(_usdt);
    }

    function updateTreasury(
        address _treasury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = _treasury;
    }

    function updateTreasuryType(
        uint8 _treasuryType
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasuryType = _treasuryType;
    }

    function withdrawKcash() external onlyRole(DEFAULT_ADMIN_ROLE) {
        kcash.transfer(msg.sender, kcash.balanceOf(address(this)));
    }

    function withdrawUsdt() external onlyRole(DEFAULT_ADMIN_ROLE) {
        usdt.transfer(msg.sender, usdt.balanceOf(address(this)));
    }

    function withdrawNativeBalance() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function addReward3(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        kcash.adminTransferFrom(
            msg.sender,
            address(this),
            IKCash.Bucket(0, 0, _amount)
        );
    }

    function addUsdt(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        usdt.transferFrom(msg.sender, address(this), _amount);
    }

    function bulkDisburseKCash(
        address[] calldata _to,
        uint256[] calldata _amounts,
        string calldata _entityName,
        uint256 _totalAmount
    ) external onlyRole(ANDMIN_TRANSFER_ROLE) {
        require(_to.length == _amounts.length, "Array length mismatch");
        kcash.adminTransferFrom(
            treasury,
            address(this),
            IKCash.Bucket(0, 0, _totalAmount)
        );
        if (treasuryType == 1) {
            kcash.adminTransferFromReward3ToReward1Bulk(_to, _amounts);
        } else if (treasuryType == 2) {
            kcash.adminTransferFromReward3ToReward2Bulk(_to, _amounts);
        } else {
            kcash.transferReward3ToReward3Bulk(_to, _amounts);
        }
        emit KCashPayment(_entityName, _totalAmount);
    }

    function bulkDiburseUSDT(
        address[] calldata _to,
        uint256[] calldata _amounts,
        string calldata _entityName,
        uint256 _totalAmount
    ) external onlyRole(ANDMIN_TRANSFER_ROLE) {
        require(_to.length == _amounts.length, "Array length mismatch");
        usdt.transferFrom(treasury, address(this), _totalAmount);
        for (uint256 i; i < _to.length; ) {
            usdt.transfer(_to[i], _amounts[i]);
            unchecked {
                ++i;
            }
        }
        emit USDTPayment(_entityName, _totalAmount);
    }
}
