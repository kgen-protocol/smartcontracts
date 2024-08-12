// SPDX-License-Identifier: MIT

// ██╗   ██╗███████╗██████╗ ████████╗    ██████╗ ██╗███████╗██████╗ ██╗   ██╗██████╗ ███████╗███████╗
// ██║   ██║██╔════╝██╔══██╗╚══██╔══╝    ██╔══██╗██║██╔════╝██╔══██╗██║   ██║██╔══██╗██╔════╝██╔════╝
// ██║   ██║███████╗██║  ██║   ██║       ██║  ██║██║███████╗██████╔╝██║   ██║██████╔╝███████╗█████╗
// ██║   ██║╚════██║██║  ██║   ██║       ██║  ██║██║╚════██║██╔══██╗██║   ██║██╔══██╗╚════██║██╔══╝
// ╚██████╔╝███████║██████╔╝   ██║       ██████╔╝██║███████║██████╔╝╚██████╔╝██║  ██║███████║███████╗
//  ╚═════╝ ╚══════╝╚═════╝    ╚═╝       ╚═════╝ ╚═╝╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Interfaces/IKCash.sol";

/**
 * @title USDTDisburse
 * @dev This contract handles the disbursement of USDT tokens according to specified distribution percentages.
 */
contract USDTDisburse is AccessControl {
    // Contract variables
    IERC20 public usdt;
    IKCash public kcash;
    address public KCashTreasury;
    address public USDTMarginWallet;
    address public USDTLockingWallet;
    uint256 public marginPercentage;
    uint256 public lockingPercentage;
    uint256 public treasuryPercentage;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @dev Initializes the USDTDisburse contract with the specified parameters.
     * @param _owner The address of the contract owner.
     * @param _usdt The address of the USDT token contract.
     * @param _kcash The address of the KCash token contract.
     * @param _KCashTreasury The address of the KCash treasury contract.
     * @param _USDTMarginWallet The address of the USDT margin wallet.
     * @param _USDTLockingWallet The address of the USDT locking wallet.
     */
    constructor(
        address _owner,
        address _usdt,
        address _kcash,
        address _KCashTreasury,
        address _USDTMarginWallet,
        address _USDTLockingWallet
    ) {
        usdt = IERC20(_usdt);
        kcash = IKCash(_kcash);
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(ADMIN_ROLE, _owner);
        marginPercentage = 25;
        lockingPercentage = 75;
        treasuryPercentage = 75;
        KCashTreasury = _KCashTreasury;
        USDTMarginWallet = _USDTMarginWallet;
        USDTLockingWallet = _USDTLockingWallet;
    }

    /**
     * @dev Sets the distribution percentages for USDT & KCash disbursement.
     * @param _marginPercentage The percentage of USDT to be sent to the margin wallet.
     * @param _lockingPercentage The percentage of USDT to be sent to the locking wallet.
     * @param _treasuryPercentage The percentage of KCash to be sent to the KCash treasury.
     */
    function setDistributionPercentages(
        uint256 _marginPercentage,
        uint256 _lockingPercentage,
        uint256 _treasuryPercentage
    ) external onlyRole(ADMIN_ROLE) {
        require(
            _marginPercentage + _lockingPercentage == 100,
            "Invalid distribution percentage"
        );
        marginPercentage = _marginPercentage;
        lockingPercentage = _lockingPercentage;
        treasuryPercentage = _treasuryPercentage;
    }

    /**
     * @dev Sets the wallet addresses for USDT disbursement.
     * @param _KCashTreasury The address of the KCash treasury.
     * @param _USDTMarginWallet The address of the USDT margin wallet.
     * @param _USDTLockingWallet The address of the USDT locking wallet.
     */
    function setWallets(
        address _KCashTreasury,
        address _USDTMarginWallet,
        address _USDTLockingWallet
    ) external onlyRole(ADMIN_ROLE) {
        KCashTreasury = _KCashTreasury;
        USDTMarginWallet = _USDTMarginWallet;
        USDTLockingWallet = _USDTLockingWallet;
    }

    /**
     * @dev Disburses USDT tokens according to the specified distribution percentagesa and mint Kcash.
     * @param amount The amount of USDT tokens to be disbursed.
     */
    function depositForBulkDisburse(
        uint256 amount
    ) public onlyRole(ADMIN_ROLE) {
        usdt.transferFrom(msg.sender, address(this), amount * 10 ** 6);
        uint256 amountLocking = (((amount * 10 ** 6) * lockingPercentage) /
            100);
        uint256 amountMargin = (((amount * 10 ** 6) * marginPercentage) / 100);
        uint256 amountTreasury = amount * treasuryPercentage * 10;
        usdt.transfer(USDTLockingWallet, amountLocking);
        usdt.transfer(USDTMarginWallet, amountMargin);
        kcash.mint(
            KCashTreasury,
            amountTreasury,
            IKCash.Bucket(0, 0, amountTreasury)
        );
    }

    /**
     * @dev Withdraws a specified amount of USDT tokens to a specified address.
     * @param amount The amount of USDT tokens to be withdrawn.
     * @param to The address to which the USDT tokens will be transferred.
     */
    function withDrawUSDT(
        uint256 amount,
        address to
    ) public onlyRole(ADMIN_ROLE) {
        require(
            usdt.balanceOf(address(this)) >= amount,
            "Insufficient USDT balance"
        );
        usdt.transfer(to, amount);
    }

    /**
     * @dev Withdraws a specified amount of native currency to a specified address.
     * @param to The address to which the native currency will be transferred.
     * @param amount The amount of native currency to be withdrawn.
     */
    function withDrawNative(
        address payable to,
        uint256 amount
    ) public onlyRole(ADMIN_ROLE) {
        require(address(this).balance >= amount, "Insufficient balance");
        to.transfer(amount);
    }
}
