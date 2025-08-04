// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract KGEN is 
    Initializable, 
    ERC20Upgradeable, 
    AccessControlEnumerableUpgradeable
{
    // Role definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant BURN_VAULT_ROLE = keccak256("BURN_VAULT_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // Supply cap
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**8; // 1 billion tokens with 8 decimals
    
    // Whitelist system
    mapping(address => bool) public whitelistedSenders;
    mapping(address => bool) public whitelistedReceivers;

    struct FreezeStatus {
        bool sending;
        bool receiving;
    }

    mapping(address => FreezeStatus) public frozenAccounts;

    address public pendingAdmin;

    // Events
    event MintedToTreasury(address indexed treasury, uint256 amount);
    event UpdatedBurnVault(string role, address indexed updatedAddress);
    event UpdatedAdmin(string role, address indexed addedAdmin);
    event NominatedAdminEvent(string role, address indexed nominatedAdmin);
    event UpdatedMinter(string role, address indexed addedUser);
    event AddedTreasuryAddress(string msg, address indexed addedAddress);
    event RemovedTreasuryAddress(string msg, address indexed removedAddress);
    event AddedSenderAddress(string msg, address indexed addedAddress);
    event RemovedSenderAddress(string msg, address indexed removedAddress);
    event AddedReceiverAddress(string msg, address indexed addedAddress);
    event RemovedReceiverAddress(string msg, address indexed removedAddress);
    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);

    // Custom errors
    error OnlyAdmin();
    error NotAdmin();
    error CannotDeleteTreasuryAddress();
    error InvalidReceiverOrSender();
    error NotBurnVault();
    error NotValidAddress();
    error NotOwner();
    error NoPending();
    error InvalidAmount();
    error CannotNominateSelf();
    error NotNominated();
    error NoPendingNomination();
    error AlreadyMinter();
    error NotMinter();
    error AlreadyBurnVault();
    error AlreadyTreasury();
    error NotTreasury();
    error AlreadyWhitelistedSender();
    error NotWhitelistedSender();
    error AlreadyWhitelistedReceiver();
    error NotWhitelistedReceiver();
    error AccountIsFrozen();
    error CannotTransferToSelf();
    error ExceedsMaxSupply();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address initialAdmin) public initializer {
        __ERC20_init("KGEN", "KGEN");
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(MINTER_ROLE, initialAdmin);
        _grantRole(TREASURY_ROLE, initialAdmin);
        _grantRole(BURN_VAULT_ROLE, initialAdmin);
        _grantRole(UPGRADER_ROLE, initialAdmin);
    }

    // --- Modifiers ---
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert OnlyAdmin();
        _;
    }

    modifier onlyMinter() {
        if (!hasRole(MINTER_ROLE, msg.sender)) revert NotMinter();
        _;
    }

    modifier onlyTreasury() {
        if (!hasRole(TREASURY_ROLE, msg.sender)) revert NotTreasury();
        _;
    }

    modifier onlyBurnVault() {
        if (!hasRole(BURN_VAULT_ROLE, msg.sender)) revert NotBurnVault();
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) revert NotValidAddress();
        _;
    }

    // --- Admin Controls ---

    function transferAdmin(address newAdmin) external onlyAdmin validAddress(newAdmin) {
        if (newAdmin == getRoleMember(DEFAULT_ADMIN_ROLE, 0)) revert CannotNominateSelf();
        pendingAdmin = newAdmin;
        emit NominatedAdminEvent("New Admin Nominated, Now new admin need to accept the role", newAdmin);
    }

    function acceptAdmin() external {
        if (msg.sender != pendingAdmin) revert NotNominated();
        if (pendingAdmin == address(0)) revert NoPendingNomination();
        
        address currentAdmin = getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        _revokeRole(DEFAULT_ADMIN_ROLE, currentAdmin);
        _grantRole(DEFAULT_ADMIN_ROLE, pendingAdmin);
        pendingAdmin = address(0);
        emit UpdatedAdmin("New Admin Added", msg.sender);
    }

    function addMinter(address account) external onlyAdmin validAddress(account) {
        if (hasRole(MINTER_ROLE, account)) revert AlreadyMinter();
        _grantRole(MINTER_ROLE, account);
        emit UpdatedMinter("NewMinter", account);
    }

    function removeMinter(address account) external onlyAdmin {
        if (!hasRole(MINTER_ROLE, account)) revert NotMinter();
        _revokeRole(MINTER_ROLE, account);
        emit UpdatedMinter("Minter Removed", account);
    }

    function addTreasury(address account) external onlyAdmin validAddress(account) {
        if (hasRole(TREASURY_ROLE, account)) revert AlreadyTreasury();
        _grantRole(TREASURY_ROLE, account);
        
        // Automatically add to sender whitelist if not already there
        if (!whitelistedSenders[account]) {
            whitelistedSenders[account] = true;
            emit AddedSenderAddress("New Sender Address Whitelisted", account);
        }
        
        emit AddedTreasuryAddress("New Treasury Address Added", account);
    }

    function removeTreasury(address account) external onlyAdmin {
        if (!hasRole(TREASURY_ROLE, account)) revert NotTreasury();
        _revokeRole(TREASURY_ROLE, account);
        emit RemovedTreasuryAddress("Treasury Address Removed", account);
    }

    function addBurnVault(address account) external onlyAdmin validAddress(account) {
        if (hasRole(BURN_VAULT_ROLE, account)) revert AlreadyBurnVault();
        _grantRole(BURN_VAULT_ROLE, account);
        emit UpdatedBurnVault("Burnable Address Added", account);
    }

    function removeBurnVault(address account) external onlyAdmin {
        if (!hasRole(BURN_VAULT_ROLE, account)) revert NotBurnVault();
        _revokeRole(BURN_VAULT_ROLE, account);
        emit UpdatedBurnVault("Burnable Address Removed", account);
    }

    // --- Whitelist Management ---

    function addWhitelistSender(address account) external onlyAdmin validAddress(account) {
        if (whitelistedSenders[account]) revert AlreadyWhitelistedSender();
        whitelistedSenders[account] = true;
        emit AddedSenderAddress("New Sender Address Whitelisted", account);
    }

    function removeWhitelistSender(address account) external onlyAdmin {
        if (!whitelistedSenders[account]) revert NotWhitelistedSender();
        if (hasRole(TREASURY_ROLE, account)) revert CannotDeleteTreasuryAddress();
        
        whitelistedSenders[account] = false;
        emit RemovedSenderAddress("Sender Address Removed From Whitelist", account);
    }

    function addWhitelistReceiver(address account) external onlyAdmin validAddress(account) {
        if (whitelistedReceivers[account]) revert AlreadyWhitelistedReceiver();
        whitelistedReceivers[account] = true;
        emit AddedReceiverAddress("New Receiver Address Whitelisted", account);
    }

    function removeWhitelistReceiver(address account) external onlyAdmin {
        if (!whitelistedReceivers[account]) revert NotWhitelistedReceiver();
        whitelistedReceivers[account] = false;
        emit RemovedReceiverAddress("Receiver Address Removed From Whitelist", account);
    }

    // --- Freeze Logic ---
    function freezeAccounts(address[] calldata accounts, bool[] calldata sendingFlags, bool[] calldata receivingFlags) external onlyAdmin {
        if (accounts.length != sendingFlags.length || accounts.length != receivingFlags.length) {
            revert("ARGUMENT_VECTORS_LENGTH_MISMATCH");
        }
        for (uint i = 0; i < accounts.length; i++) {
            frozenAccounts[accounts[i]] = FreezeStatus(sendingFlags[i], receivingFlags[i]);
            emit AccountFrozen(accounts[i]);
        }
    }

    function unfreezeAccounts(address[] calldata accounts, bool[] calldata unfreezeSending, bool[] calldata unfreezeReceiving) external onlyAdmin {
        if (accounts.length != unfreezeSending.length || accounts.length != unfreezeReceiving.length) {
            revert("ARGUMENT_VECTORS_LENGTH_MISMATCH");
        }
        for (uint i = 0; i < accounts.length; i++) {
            if (unfreezeSending[i]) frozenAccounts[accounts[i]].sending = false;
            if (unfreezeReceiving[i]) frozenAccounts[accounts[i]].receiving = false;
            emit AccountUnfrozen(accounts[i]);
        }
    }

    // --- Minting/Burning ---

    function mint(address to, uint256 amount) external onlyMinter validAmount(amount) {
        if (!hasRole(TREASURY_ROLE, to)) revert NotTreasury();
        if (frozenAccounts[to].receiving) revert AccountIsFrozen();
        
        // Check supply cap
        if (totalSupply() + amount > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        _mint(to, amount);
        emit MintedToTreasury(to, amount);
    }

    function burn(address from, uint256 amount) external onlyAdmin validAmount(amount) {
        if (!hasRole(BURN_VAULT_ROLE, from)) revert NotBurnVault();
        _burn(from, amount);
    }

    // --- Transfers ---

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (frozenAccounts[msg.sender].sending) revert AccountIsFrozen();
        if (frozenAccounts[to].receiving) revert AccountIsFrozen();
        
        // Check whitelist requirements: either sender must be whitelisted OR receiver must be whitelisted
        if (!whitelistedSenders[msg.sender] && !whitelistedReceivers[to]) {
            revert InvalidReceiverOrSender();
        }
        
        bool success = super.transfer(to, amount);
        if (success) {
            emit Transfer(msg.sender, to, amount);
        }
        return success;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (frozenAccounts[from].sending) revert AccountIsFrozen();
        if (frozenAccounts[to].receiving) revert AccountIsFrozen();
        
        // Check whitelist requirements: either sender must be whitelisted OR receiver must be whitelisted
        if (!whitelistedSenders[from] && !whitelistedReceivers[to]) {
            revert InvalidReceiverOrSender();
        }
        
        bool success = super.transferFrom(from, to, amount);
        if (success) {
            emit Transfer(from, to, amount);
        }
        return success;
    }

    // Admin override transfer
    function adminTransfer(address from, address to, uint256 amount) external onlyAdmin {
        if (!frozenAccounts[from].sending && !frozenAccounts[to].receiving) {
            revert("NOT_FROZEN");
        }
        _transfer(from, to, amount);
        emit Transfer(from, to, amount);
    }

    // --- View Functions ---
    function isFrozen(address account) external view returns (bool sending, bool receiving) {
        FreezeStatus memory status = frozenAccounts[account];
        return (status.sending, status.receiving);
    }

    function isWhitelistedSender(address account) external view returns (bool) {
        return whitelistedSenders[account];
    }

    function isWhitelistedReceiver(address account) external view returns (bool) {
        return whitelistedReceivers[account];
    }

    function isTreasury(address account) external view returns (bool) {
        return hasRole(TREASURY_ROLE, account);
    }

    function isBurnVault(address account) external view returns (bool) {
        return hasRole(BURN_VAULT_ROLE, account);
    }

    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    function getPendingAdmin() external view returns (address) {
        return pendingAdmin;
    }

    function getAdmin() external view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }

    function getMinters() external view returns (address[] memory) {
        uint256 count = getRoleMemberCount(MINTER_ROLE);
        address[] memory minters = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            minters[i] = getRoleMember(MINTER_ROLE, i);
        }
        return minters;
    }

    function getTreasuries() external view returns (address[] memory) {
        uint256 count = getRoleMemberCount(TREASURY_ROLE);
        address[] memory treasuries = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            treasuries[i] = getRoleMember(TREASURY_ROLE, i);
        }
        return treasuries;
    }

    function getBurnVaults() external view returns (address[] memory) {
        uint256 count = getRoleMemberCount(BURN_VAULT_ROLE);
        address[] memory burnVaults = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            burnVaults[i] = getRoleMember(BURN_VAULT_ROLE, i);
        }
        return burnVaults;
    }

    function decimals() public pure override returns (uint8) {
    return 8;
}
}
