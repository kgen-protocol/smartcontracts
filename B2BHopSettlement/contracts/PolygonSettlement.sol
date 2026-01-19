// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @notice Interface to your B2BRevenue contract
/// @dev Assumes the Revenue contract has a function to pull funds using transferFrom
interface IB2BRevenue {
    function depositToken(address _token, uint256 _amount) external;
}

contract B2BSettlementV2 is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// ================================
    /// EVENTS
    /// ================================
    event PartnerCreated(uint256 indexed dpId, uint256 timestamp);
    event BankCreated(bytes32 indexed bankId, uint256 timestamp);
    
    event SettlementExecuted(
        bytes32 indexed orderId,
        uint256 indexed dpId,
        uint256 amount,
        bytes32 indexed bankId,
        address token,
        uint256 timestamp
    );
    
    event RevenueDeposited(
        address indexed revenueContract,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    event BankWithdrawal(
        bytes32 indexed bankId, 
        address recipient, 
        uint256 amount, 
        address token
    );
    
    event SuperAdminTransferred(address indexed oldAdmin, address indexed newAdmin);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event RevenueContractUpdated(address indexed oldContract, address indexed newContract);
    event PartnerStatusChanged(uint256 indexed dpId, bool status);
    event BankStatusChanged(bytes32 indexed bankId, bool status);
    event BankFunded(bytes32 indexed bankId, address indexed token, uint256 amount);

    /// ================================
    /// STRUCTS
    /// ================================
    struct PartnerInfo {
        bool exists;
        bool isActive;
    }

    struct BankInfo {
        bool exists;
        bool isActive;
    }

    /// ================================
    /// STATE VARIABLES
    /// ================================
    address public superAdmin;      // multisig wallet
    address public admin;           // operator (cron job)
    IB2BRevenue public revenueContract; 

    // BankId => Token => Balance
    mapping(bytes32 => mapping(address => uint256)) public bankBalances;
    
    mapping(uint256 => PartnerInfo) public partners; 
    mapping(bytes32 => BankInfo) public banks;
    
    // Prevent double-spending of Order IDs
    mapping(bytes32 => bool) public processedOrders;

    /// ================================
    /// MODIFIERS
    /// ================================
    modifier onlyAdmin() {
        require(msg.sender == admin, "NotAdmin");
        _;
    }

    modifier onlySuperAdmin() {
        require(msg.sender == superAdmin, "NotSuperAdmin");
        _;
    }

    /// ================================
    /// CONSTRUCTOR
    /// ================================
    constructor(address _revenueContract, address _superAdmin) {
        require(_revenueContract != address(0), "Revenue contract zero");
        require(_superAdmin != address(0), "SuperAdmin zero");

        revenueContract = IB2BRevenue(_revenueContract);
        superAdmin = _superAdmin;
        admin = msg.sender;

        emit SuperAdminTransferred(address(0), _superAdmin);
        emit AdminUpdated(address(0), msg.sender);
    }

    /// ================================
    /// ADMIN FUNCTIONS
    /// ================================
    function updateAdmin(address newAdmin) external onlySuperAdmin {
        require(newAdmin != address(0), "Invalid address");
        emit AdminUpdated(admin, newAdmin);
        admin = newAdmin;
    }

    function updateRevenueContract(address _newRevenue) external onlySuperAdmin {
        require(_newRevenue != address(0), "Invalid address");
        emit RevenueContractUpdated(address(revenueContract), _newRevenue);
        revenueContract = IB2BRevenue(_newRevenue);
    }

    function transferSuperAdmin(address newSuperAdmin) external onlySuperAdmin {
        require(newSuperAdmin != address(0), "Invalid address");
        emit SuperAdminTransferred(superAdmin, newSuperAdmin);
        superAdmin = newSuperAdmin;
    }

    function pause() external onlySuperAdmin {
        _pause();
    }

    function unpause() external onlySuperAdmin {
        _unpause();
    }

    /// ================================
    /// REGISTRATION
    /// ================================
    function createPartner(uint256 dpId) external onlyAdmin {
        require(!partners[dpId].exists, "Partner already exists");
        partners[dpId] = PartnerInfo(true, true);
        emit PartnerCreated(dpId, block.timestamp);
    }

    function createBank(string calldata bankId) external onlyAdmin {
        bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
        require(!banks[bankIdHash].exists, "Bank already exists");
        banks[bankIdHash] = BankInfo(true, true);
        emit BankCreated(bankIdHash, block.timestamp);
    }

    function setPartnerStatus(uint256 dpId, bool status) external onlyAdmin {
        require(partners[dpId].exists, "Partner does not exist");
        partners[dpId].isActive = status;
        emit PartnerStatusChanged(dpId, status);
    }

    function setBankStatus(string calldata bankId, bool status) external onlyAdmin {
        bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
        require(banks[bankIdHash].exists, "Bank does not exist");
        banks[bankIdHash].isActive = status;
        emit BankStatusChanged(bankIdHash, status);
    }

    /// ================================
    /// FUND BANK (DEPOSIT)
    /// ================================
    function fundBank(string calldata bankId, uint256 amount, IERC20 token)
        external
        nonReentrant
        whenNotPaused
    {
        bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
        BankInfo storage bank = banks[bankIdHash];
        require(bank.exists && bank.isActive, "Bank not found or inactive");
        require(amount > 0, "InvalidAmount");

        token.safeTransferFrom(msg.sender, address(this), amount);
        bankBalances[bankIdHash][address(token)] += amount;

        emit BankFunded(bankIdHash, address(token), amount);
    }

    /// ================================
    /// SETTLEMENT (CORE LOGIC)
    /// ================================
    function executeSingleSettlement(
        string calldata orderId,
        uint256 dpId,
        uint256 amount,
        string calldata bankId,
        IERC20 token
    )
        external
        onlyAdmin
        nonReentrant
        whenNotPaused
    {
        require(amount > 0, "InvalidAmount");

        bytes32 orderIdHash = keccak256(abi.encodePacked(orderId));
        require(!processedOrders[orderIdHash], "Order already processed");

        bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
        BankInfo storage bank = banks[bankIdHash];
        require(bank.exists && bank.isActive, "Bank not found or inactive");

        PartnerInfo storage partner = partners[dpId];
        require(partner.exists && partner.isActive, "Partner not found or inactive");

        require(bankBalances[bankIdHash][address(token)] >= amount, "InsufficientBalance");


        processedOrders[orderIdHash] = true;
        bankBalances[bankIdHash][address(token)] -= amount;

        token.safeApprove(address(revenueContract), 0);
        token.safeApprove(address(revenueContract), amount);

        revenueContract.depositToken(address(token), amount);

        emit SettlementExecuted(
            orderIdHash,
            dpId,
            amount,
            bankIdHash,
            address(token),
            block.timestamp
        );
        
        emit RevenueDeposited(address(revenueContract), address(token), amount, block.timestamp);
    }

    /// ================================
    /// BANK WITHDRAWAL 
    /// ================================
    function withdrawFromBank(
        string calldata bankId,
        IERC20 token,
        uint256 amount,
        address recipient
    )
        external
        onlySuperAdmin
        nonReentrant
    {
        require(recipient != address(0), "Invalid recipient");

        bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
        BankInfo storage bank = banks[bankIdHash];
        require(bank.exists, "Bank not found");
        require(bankBalances[bankIdHash][address(token)] >= amount, "InsufficientBalance");

        bankBalances[bankIdHash][address(token)] -= amount;
        token.safeTransfer(recipient, amount);

        emit BankWithdrawal(bankIdHash, recipient, amount, address(token));
    }

    /// ================================
    /// VIEW FUNCTIONS
    /// ================================
    function getBankBalance(string calldata bankId, address token) external view returns (uint256) {
        bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
        return bankBalances[bankIdHash][token];
    }

    function isBankActive(string calldata bankId) external view returns (bool) {
        bytes32 bankIdHash = keccak256(abi.encodePacked(bankId));
        return banks[bankIdHash].exists && banks[bankIdHash].isActive;
    }

    function isPartnerActive(uint256 dpId) external view returns (bool) {
        return partners[dpId].exists && partners[dpId].isActive;
    }

    function isOrderProcessed(string calldata orderId) external view returns (bool) {
        bytes32 orderIdHash = keccak256(abi.encodePacked(orderId));
        return processedOrders[orderIdHash];
    }
}