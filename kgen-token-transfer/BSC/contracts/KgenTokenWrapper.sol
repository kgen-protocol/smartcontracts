// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin Upgradeable imports
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ERC2771Context/ERC2771ContextUpgradable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KgenTokenWrapper is
    Initializable,
    ReentrancyGuardUpgradeable,
    ERC2771ContextUpgradable,
    AccessControlUpgradeable
{
    // ------------------------------- Roles -------------------------------
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    // ------------------------------- Errors ------------------------------
    error TokenNotWhitelisted();
    error InsufficientBalance();
    error InvalidAddress();
    error ZeroAmount();
    error TokenAlreadyWhitelisted();
    error  InvalidFee();

    // ------------------------------ Storage ------------------------------
    address public KGEN_TDS_FEE_TREASURY_ADDRESS;
    address public KGEN_GAS_FEE_TREASURY_ADDRESS;

    // ------------------------------- Events ------------------------------
    event TokenTransferred(
        address indexed sender,
        address indexed recipient,
        address indexed treasury,
        address tokenAddress,
        uint256 amount,
        uint256 gasFee
    );
    event TokenTransferredWithTDS(
    address indexed sender,
    address indexed recipient,
    address indexed token,
    uint256 grossAmount,     // total amount user intended to spend
    uint256 gasFee,          // deducted as gas fee
    uint256 tdsFee,          // deducted as TDS fee
    uint256 netAmount        // actually received by recipient
);

    event KgenTdsFeeTreasuryUpdated(address indexed previous, address indexed current);
    event KgenGasFeeTreasuryUpdated(address indexed previous, address indexed current);
    event TokenWhitelisted(address indexed tokenAddress);
    event TokenRemovedFromWhitelist(address indexed tokenAddress);
    event TrustedForwarderUpdated(address indexed newForwarder);

    // ---------------------------- Initializer ----------------------------
    /// @notice Initialize the proxy (instead of a constructor)
    /// @param _trustedForwarder ERC-2771 trusted forwarder
    /// @param admin            Address to be granted admin roles
    function initialize(address _trustedForwarder, address admin, address tsddFeeTreasuryAddress,address gasFeeTreasuryAddress) public initializer {
        if (admin == address(0)) revert InvalidAddress();
        if (_trustedForwarder == address(0)) revert InvalidAddress();
        if (tsddFeeTreasuryAddress == address(0)) revert InvalidAddress();
        if (gasFeeTreasuryAddress == address(0)) revert InvalidAddress();
        __ReentrancyGuard_init();
        __AccessControl_init();
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(WITHDRAWER_ROLE, admin);
        // FIX: actually set the trusted forwarder
       KGEN_TDS_FEE_TREASURY_ADDRESS = tsddFeeTreasuryAddress;
       KGEN_GAS_FEE_TREASURY_ADDRESS = gasFeeTreasuryAddress;
        trustedForwarder[_trustedForwarder] = true;
        emit TrustedForwarderUpdated(_trustedForwarder);
    }

    // ------------------------ Core token transfer ------------------------
    /**
     * @dev Transfer KGEN (or any ERC20) with a gas/treasury fee deduction.
     *      The caller must have approved this contract to spend `amount + gasFee`.
     */
    function transferKgenToken(
        address tokenAddress,
        address treasury,
        address recipientAddress,
        uint256 gasFee,
        uint256 amount
    ) external nonReentrant {
        if (tokenAddress == address(0)) revert InvalidAddress();
        if (treasury == address(0)) revert InvalidAddress();
        if (recipientAddress == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAmount();

        IERC20 token = IERC20(tokenAddress);
        address sender = _msgSender();

        uint256 totalRequired = amount + gasFee;
        if (token.balanceOf(sender) < totalRequired) revert InsufficientBalance();

        // NB: The user must pre-approve this contract for `totalRequired`.
        require(token.transferFrom(sender, recipientAddress, amount), "Transfer failed");

        if (gasFee > 0) {
            require(token.transferFrom(sender, treasury, gasFee), "Gas fee transfer failed");
        }

        emit TokenTransferred(sender, recipientAddress, treasury, tokenAddress, amount, gasFee);
    }

function transferKgenTokenWithTDS(
    address tokenAddress,
    address recipientAddress,
    uint256 gasFee,
    uint256 tdsFee,
    uint256 amount
) external nonReentrant {
    if (tokenAddress == address(0)) revert InvalidAddress();
    if (recipientAddress == address(0)) revert InvalidAddress();
    if (amount == 0) revert ZeroAmount();

    IERC20 token = IERC20(tokenAddress);
    address sender = _msgSender();

    // Ensure fees are valid
    if (gasFee + tdsFee > amount) revert InvalidFee();

    // Net amount to recipient
    uint256 amountToTransfer = amount - gasFee - tdsFee;

    // Require sender has at least total (gross) amount
    if (token.balanceOf(sender) < amount) revert InsufficientBalance();

    // Require correct approvals (sender must approve at least `amount`)
    // Perform transfers
    if (gasFee > 0) {
        if (KGEN_GAS_FEE_TREASURY_ADDRESS == address(0)) revert InvalidAddress();
        require(
            token.transferFrom(sender, KGEN_GAS_FEE_TREASURY_ADDRESS, gasFee),
            "Gas fee transfer failed"
        );
    }

    if (tdsFee > 0) {
        if (KGEN_TDS_FEE_TREASURY_ADDRESS == address(0)) revert InvalidAddress();
        require(
            token.transferFrom(sender, KGEN_TDS_FEE_TREASURY_ADDRESS, tdsFee),
            "TDS fee transfer failed"
        );
    }

    if (amountToTransfer > 0) {
        require(
            token.transferFrom(sender, recipientAddress, amountToTransfer),
            "Recipient transfer failed"
        );
    }

    emit TokenTransferredWithTDS(
        sender,
        recipientAddress,
        tokenAddress,
        amount,          
        gasFee,
        tdsFee,
        amountToTransfer 
    );
}

    function setKgenTdsFeeTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        if (newTreasury == address(0)) revert InvalidAddress();
        address prev = KGEN_TDS_FEE_TREASURY_ADDRESS;
        KGEN_TDS_FEE_TREASURY_ADDRESS = newTreasury;
        emit KgenTdsFeeTreasuryUpdated(prev, newTreasury);
    }

    function setKgenGasFeeTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        if (newTreasury == address(0)) revert InvalidAddress();
        address prev = KGEN_GAS_FEE_TREASURY_ADDRESS;
        KGEN_GAS_FEE_TREASURY_ADDRESS = newTreasury;
        emit KgenGasFeeTreasuryUpdated(prev, newTreasury);
    }

    // ---------------------------- ERC-2771 Hooks -------------------------
    function setTrustedForwarder(
        address _trustedForwarder,
        bool _isTrusted
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        trustedForwarder[_trustedForwarder] = _isTrusted;
        emit TrustedForwarderUpdated(_trustedForwarder);
    }

    function isTrustedForwarder(address forwarder)
        public
        view
        override
        returns (bool)
    {
        return trustedForwarder[forwarder];
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradable)
        returns (address)
    {
        return ERC2771ContextUpgradable._msgSender();
    }

    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradable._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradable)
        returns (uint256)
    {
        return ERC2771ContextUpgradable._contextSuffixLength();
    }

    // ------------------------------ Storage gap --------------------------
    mapping (address => bool) public trustedForwarder;
    uint256[50] private __gap;
}
