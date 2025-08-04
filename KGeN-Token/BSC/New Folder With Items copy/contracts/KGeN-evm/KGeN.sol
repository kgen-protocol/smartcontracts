// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "contracts/ERC2771ContextUpgradeable/ERC2771ContextUpgradable.sol";

/**
 * @title KGEN Token Contract
 * @dev Upgradeable ERC20 token with role-based access control, whitelist system, and freeze functionality
 * @notice This contract implements a sophisticated token system with:
 *         - Treasury-only minting (tokens can only be minted to treasury addresses)
 *         - Whitelist-based transfers (only whitelisted addresses can send/receive)
 *         - Account freezing (admin can freeze accounts from sending/receiving)
 *         - Admin-controlled burning (two-step process: transfer to burn vault, then burn)
 *         - ERC2771 meta-transaction support
 */
contract KGEN is 
    Initializable, 
    ERC20Upgradeable, 
    AccessControlEnumerableUpgradeable,
    ERC2771ContextUpgradeable
{
    // ============ ROLE DEFINITIONS ============
    /// @dev Role for addresses that can mint new tokens (treasury addresses only)
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @dev Role for addresses that can receive minted tokens
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    /// @dev Role for addresses that can have tokens burned from them
    bytes32 public constant BURN_VAULT_ROLE = keccak256("BURN_VAULT_ROLE");
    /// @dev Role for addresses that can upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // ============ SUPPLY MANAGEMENT ============
    /// @dev Maximum total supply of tokens (1 billion with 8 decimals)
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**8; // 1 billion tokens with 8 decimals
    
    // ============ WHITELIST SYSTEM ============
    /// @dev Mapping of addresses that are whitelisted to send tokens
    mapping(address => bool) public whitelistedSenders;
    /// @dev Mapping of addresses that are whitelisted to receive tokens
    mapping(address => bool) public whitelistedReceivers;
    /// @dev Mapping of trusted forwarder addresses for ERC2771 meta-transactions
    mapping(address => bool) public trustedForwarder;

    // ============ FREEZE SYSTEM ============
    /// @dev Structure to track freeze status for sending and receiving separately
    struct FreezeStatus {
        bool sending;    /// @dev Whether the account is frozen from sending tokens
        bool receiving;  /// @dev Whether the account is frozen from receiving tokens
    }

    /// @dev Mapping of account addresses to their freeze status
    mapping(address => FreezeStatus) public frozenAccounts;

    // ============ ADMIN MANAGEMENT ============
    /// @dev Address of the pending admin (for admin transfer process)
    address public pendingAdmin;

    // ============ CUSTOM MODIFIERS ============
    /// @dev Modifier to check if an address is valid (not zero address)
    modifier invalidAddressCheck(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }

    // ============ EVENTS ============
    /// @dev Emitted when tokens are minted to a treasury address
    event MintedToTreasury(address indexed treasury, uint256 amount);
    /// @dev Emitted when burn vault address is updated
    event UpdatedBurnVault(string role, address indexed updatedAddress);
    /// @dev Emitted when admin is updated
    event UpdatedAdmin(string role, address indexed addedAdmin);
    /// @dev Emitted when a new admin is nominated
    event NominatedAdminEvent(string role, address indexed nominatedAdmin);
    /// @dev Emitted when minter is updated
    event UpdatedMinter(string role, address indexed addedUser);
    /// @dev Emitted when a treasury address is added
    event AddedTreasuryAddress(string msg, address indexed addedAddress);
    /// @dev Emitted when a treasury address is removed
    event RemovedTreasuryAddress(string msg, address indexed removedAddress);
    /// @dev Emitted when a sender address is added to whitelist
    event AddedSenderAddress(string msg, address indexed addedAddress);
    /// @dev Emitted when a sender address is removed from whitelist
    event RemovedSenderAddress(string msg, address indexed removedAddress);
    /// @dev Emitted when a receiver address is added to whitelist
    event AddedReceiverAddress(string msg, address indexed addedAddress);
    /// @dev Emitted when a receiver address is removed from whitelist
    event RemovedReceiverAddress(string msg, address indexed removedAddress);
    /// @dev Emitted when an account is frozen
    event AccountFrozen(address indexed account);
    /// @dev Emitted when an account is unfrozen
    event AccountUnfrozen(address indexed account);

    // ============ CUSTOM ERRORS ============
    /// @dev Thrown when a function is called by someone who is not an admin
    error OnlyAdmin();
    /// @dev Thrown when trying to perform an admin action without admin privileges
    error NotAdmin();
    /// @dev Thrown when trying to delete a treasury address from whitelist
    error CannotDeleteTreasuryAddress();
    /// @dev Thrown when transfer fails whitelist requirements
    error InvalidReceiverOrSender();
    /// @dev Thrown when trying to burn from an address that is not a burn vault
    error NotBurnVault();
    /// @dev Thrown when an invalid address is provided
    error NotValidAddress();
    /// @dev Thrown when caller is not the contract owner
    error NotOwner();
    /// @dev Thrown when there is no pending operation
    error NoPending();
    /// @dev Thrown when amount is zero or invalid
    error InvalidAmount();
    /// @dev Thrown when trying to nominate self as admin
    error CannotNominateSelf();
    /// @dev Thrown when caller is not nominated for admin role
    error NotNominated();
    /// @dev Thrown when there is no pending admin nomination
    error NoPendingNomination();
    /// @dev Thrown when trying to add an address that is already a minter
    error AlreadyMinter();
    /// @dev Thrown when caller is not a minter
    error NotMinter();
    /// @dev Thrown when trying to add an address that is already a burn vault
    error AlreadyBurnVault();
    /// @dev Thrown when trying to add an address that is already a treasury
    error AlreadyTreasury();
    /// @dev Thrown when address is not a treasury
    error NotTreasury();
    /// @dev Thrown when trying to add an address that is already a whitelisted sender
    error AlreadyWhitelistedSender();
    /// @dev Thrown when address is not a whitelisted sender
    error NotWhitelistedSender();
    /// @dev Thrown when trying to add an address that is already a whitelisted receiver
    error AlreadyWhitelistedReceiver();
    /// @dev Thrown when address is not a whitelisted receiver
    error NotWhitelistedReceiver();
    /// @dev Thrown when account is frozen and cannot perform the operation
    error AccountIsFrozen();
    /// @dev Thrown when trying to transfer tokens to self
    error CannotTransferToSelf();
    /// @dev Thrown when minting would exceed maximum supply
    error ExceedsMaxSupply();
    /// @dev Thrown when an invalid address is provided
    error InvalidAddress();
    // ============ CONSTRUCTOR & INITIALIZATION ============
    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @dev Constructor disables initializers to prevent implementation contract from being initialized
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initializes the contract with the initial admin
     * @param initialAdmin The address that will be granted all roles initially
     * @notice This function can only be called once during contract deployment
     * @notice The initial admin is granted all roles: DEFAULT_ADMIN_ROLE, MINTER_ROLE, TREASURY_ROLE, BURN_VAULT_ROLE, UPGRADER_ROLE
     */
    function initialize(address initialAdmin) public initializer {
        __ERC20_init("KGEN", "KGEN");
        __AccessControlEnumerable_init();

        // Grant all roles to the initial admin
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(MINTER_ROLE, initialAdmin);
        _grantRole(TREASURY_ROLE, initialAdmin);
        _grantRole(BURN_VAULT_ROLE, initialAdmin);
        _grantRole(UPGRADER_ROLE, initialAdmin);
    }

    // ============ ACCESS CONTROL MODIFIERS ============
    /// @dev Modifier to restrict function access to admin only
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) revert OnlyAdmin();
        _;
    }

    /// @dev Modifier to restrict function access to minters only
    modifier onlyMinter() {
        if (!hasRole(MINTER_ROLE, _msgSender())) revert NotMinter();
        _;
    }

    /// @dev Modifier to restrict function access to treasury addresses only
    modifier onlyTreasury() {
        if (!hasRole(TREASURY_ROLE, _msgSender())) revert NotTreasury();
        _;
    }

    /// @dev Modifier to restrict function access to burn vault addresses only
    modifier onlyBurnVault() {
        if (!hasRole(BURN_VAULT_ROLE, _msgSender())) revert NotBurnVault();
        _;
    }

    // ============ VALIDATION MODIFIERS ============
    /// @dev Modifier to ensure amount is greater than zero
    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    /// @dev Modifier to ensure address is not zero address
    modifier validAddress(address addr) {
        if (addr == address(0)) revert NotValidAddress();
        _;
    }

    // ============ ADMIN MANAGEMENT FUNCTIONS ============
    /**
     * @dev Nominates a new admin for the contract
     * @param newAdmin The address to nominate as the new admin
     * @notice Only the current admin can nominate a new admin
     * @notice The nominated admin must accept the role by calling acceptAdmin()
     * @notice Cannot nominate self as admin
     */
    function transferAdmin(address newAdmin) external onlyAdmin validAddress(newAdmin) {
        if (newAdmin == getRoleMember(DEFAULT_ADMIN_ROLE, 0)) revert CannotNominateSelf();
        pendingAdmin = newAdmin;
        emit NominatedAdminEvent("New Admin Nominated, Now new admin need to accept the role", newAdmin);
    }

    /**
     * @dev Accepts the admin role if nominated
     * @notice Only the nominated address can call this function
     * @notice This function transfers admin role from current admin to nominated admin
     * @notice Clears the pending admin after successful transfer
     */
    function acceptAdmin() external {
        if (_msgSender() != pendingAdmin) revert NotNominated();
        if (pendingAdmin == address(0)) revert NoPendingNomination();
        
        address currentAdmin = getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        _revokeRole(DEFAULT_ADMIN_ROLE, currentAdmin);
        _grantRole(DEFAULT_ADMIN_ROLE, pendingAdmin);
        pendingAdmin = address(0);
        emit UpdatedAdmin("New Admin Added", _msgSender());
    }

    // ============ ROLE MANAGEMENT FUNCTIONS ============
    /**
     * @dev Adds a new minter to the contract
     * @param account The address to grant minter role to
     * @notice Only admin can add minters
     * @notice Minters can mint tokens to treasury addresses only
     */
    function addMinter(address account) external onlyAdmin validAddress(account) {
        if (hasRole(MINTER_ROLE, account)) revert AlreadyMinter();
        _grantRole(MINTER_ROLE, account);
        emit UpdatedMinter("NewMinter", account);
    }

    /**
     * @dev Removes a minter from the contract
     * @param account The address to revoke minter role from
     * @notice Only admin can remove minters
     */
    function removeMinter(address account) external onlyAdmin {
        if (!hasRole(MINTER_ROLE, account)) revert NotMinter();
        _revokeRole(MINTER_ROLE, account);
        emit UpdatedMinter("Minter Removed", account);
    }

    /**
     * @dev Adds a new treasury address to the contract
     * @param account The address to grant treasury role to
     * @notice Only admin can add treasury addresses
     * @notice Treasury addresses can receive minted tokens
     * @notice Automatically adds the address to sender whitelist if not already there
     */
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

    /**
     * @dev Removes a treasury address from the contract
     * @param account The address to revoke treasury role from
     * @notice Only admin can remove treasury addresses
     */
    function removeTreasury(address account) external onlyAdmin {
        if (!hasRole(TREASURY_ROLE, account)) revert NotTreasury();
        _revokeRole(TREASURY_ROLE, account);
        emit RemovedTreasuryAddress("Treasury Address Removed", account);
    }

    /**
     * @dev Adds a new burn vault address to the contract
     * @param account The address to grant burn vault role to
     * @notice Only admin can add burn vault addresses
     * @notice Burn vault addresses can have tokens burned from them
     */
    function addBurnVault(address account) external onlyAdmin validAddress(account) {
        if (hasRole(BURN_VAULT_ROLE, account)) revert AlreadyBurnVault();
        _grantRole(BURN_VAULT_ROLE, account);
        emit UpdatedBurnVault("Burnable Address Added", account);
    }

    /**
     * @dev Removes a burn vault address from the contract
     * @param account The address to revoke burn vault role from
     * @notice Only admin can remove burn vault addresses
     */
    function removeBurnVault(address account) external onlyAdmin {
        if (!hasRole(BURN_VAULT_ROLE, account)) revert NotBurnVault();
        _revokeRole(BURN_VAULT_ROLE, account);
        emit UpdatedBurnVault("Burnable Address Removed", account);
    }

    // ============ WHITELIST MANAGEMENT FUNCTIONS ============
    /**
     * @dev Adds an address to the sender whitelist
     * @param account The address to add to sender whitelist
     * @notice Only admin can add sender addresses
     * @notice Whitelisted senders can transfer tokens to any address
     */
    function addWhitelistSender(address account) external onlyAdmin validAddress(account) {
        if (whitelistedSenders[account]) revert AlreadyWhitelistedSender();
        whitelistedSenders[account] = true;
        emit AddedSenderAddress("New Sender Address Whitelisted", account);
    }

    /**
     * @dev Removes an address from the sender whitelist
     * @param account The address to remove from sender whitelist
     * @notice Only admin can remove sender addresses
     * @notice Cannot remove treasury addresses from sender whitelist
     */
    function removeWhitelistSender(address account) external onlyAdmin {
        if (!whitelistedSenders[account]) revert NotWhitelistedSender();
        if (hasRole(TREASURY_ROLE, account)) revert CannotDeleteTreasuryAddress();
        
        whitelistedSenders[account] = false;
        emit RemovedSenderAddress("Sender Address Removed From Whitelist", account);
    }

    /**
     * @dev Adds an address to the receiver whitelist
     * @param account The address to add to receiver whitelist
     * @notice Only admin can add receiver addresses
     * @notice Whitelisted receivers can receive tokens from any address
     */
    function addWhitelistReceiver(address account) external onlyAdmin validAddress(account) {
        if (whitelistedReceivers[account]) revert AlreadyWhitelistedReceiver();
        whitelistedReceivers[account] = true;
        emit AddedReceiverAddress("New Receiver Address Whitelisted", account);
    }

    /**
     * @dev Removes an address from the receiver whitelist
     * @param account The address to remove from receiver whitelist
     * @notice Only admin can remove receiver addresses
     */
    function removeWhitelistReceiver(address account) external onlyAdmin {
        if (!whitelistedReceivers[account]) revert NotWhitelistedReceiver();
        whitelistedReceivers[account] = false;
        emit RemovedReceiverAddress("Receiver Address Removed From Whitelist", account);
    }

    // ============ FREEZE MANAGEMENT FUNCTIONS ============
    /**
     * @dev Freezes accounts with specified sending and receiving restrictions
     * @param accounts Array of account addresses to freeze
     * @param sendingFlags Array of flags indicating whether to freeze sending for each account
     * @param receivingFlags Array of flags indicating whether to freeze receiving for each account
     * @notice Only admin can freeze accounts
     * @notice Arrays must have the same length
     * @notice Frozen accounts cannot perform the restricted operations
     */
    function freezeAccounts(address[] calldata accounts, bool[] calldata sendingFlags, bool[] calldata receivingFlags) external onlyAdmin {
        if (accounts.length != sendingFlags.length || accounts.length != receivingFlags.length) {
            revert("ARGUMENT_VECTORS_LENGTH_MISMATCH");
        }
        for (uint i = 0; i < accounts.length; i++) {
            frozenAccounts[accounts[i]] = FreezeStatus(sendingFlags[i], receivingFlags[i]);
            emit AccountFrozen(accounts[i]);
        }
    }

    /**
     * @dev Unfreezes accounts with specified sending and receiving restrictions
     * @param accounts Array of account addresses to unfreeze
     * @param unfreezeSending Array of flags indicating whether to unfreeze sending for each account
     * @param unfreezeReceiving Array of flags indicating whether to unfreeze receiving for each account
     * @notice Only admin can unfreeze accounts
     * @notice Arrays must have the same length
     * @notice Only specified restrictions are unfrozen
     */
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

    // ============ MINTING & BURNING FUNCTIONS ============
    /**
     * @dev Mints new tokens to a treasury address
     * @param to The treasury address to mint tokens to
     * @param amount The amount of tokens to mint
     * @notice Only minters can call this function
     * @notice Tokens can only be minted to treasury addresses
     * @notice Cannot mint to frozen receiving accounts
     * @notice Cannot exceed maximum supply
     */
    function mint(address to, uint256 amount) external onlyMinter validAmount(amount) {
        if (!hasRole(TREASURY_ROLE, to)) revert NotTreasury();
        if (frozenAccounts[to].receiving) revert AccountIsFrozen();
        
        // Check supply cap
        if (totalSupply() + amount > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        _mint(to, amount);
        emit MintedToTreasury(to, amount);
    }

    /**
     * @dev Burns tokens using a two-step process
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     * @notice Only admin can call this function
     * @notice If from is not a burn vault: transfers tokens to burn vault first
     * @notice If from is a burn vault: burns tokens directly
     * @notice Requires at least one burn vault to exist
     */
    function burn(address from, uint256 amount) external onlyAdmin validAmount(amount) {
        // If from is not a burn vault, transfer tokens to burn vault first
        if (!hasRole(BURN_VAULT_ROLE, from)) {
            // Find the first burn vault address
            uint256 burnVaultCount = getRoleMemberCount(BURN_VAULT_ROLE);
            if (burnVaultCount == 0) revert NotBurnVault();
            
            address burnVault = getRoleMember(BURN_VAULT_ROLE, 0);
            
            // Transfer tokens from the specified address to burn vault
            _transfer(from, burnVault, amount);
            
        } else {
            // If from is already a burn vault, burn directly
            _burn(from, amount);
        }
    }

    // ============ TRANSFER FUNCTIONS ============
    /**
     * @dev Overrides ERC20 transfer function with whitelist and freeze checks
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return success Whether the transfer was successful
     * @notice Checks if sender is frozen from sending
     * @notice Checks if receiver is frozen from receiving
     * @notice Requires either sender or receiver to be whitelisted
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (frozenAccounts[_msgSender()].sending) revert AccountIsFrozen();
        if (frozenAccounts[to].receiving) revert AccountIsFrozen();
        
        // Check whitelist requirements: either sender must be whitelisted OR receiver must be whitelisted
        if (!whitelistedSenders[_msgSender()] && !whitelistedReceivers[to]) {
            revert InvalidReceiverOrSender();
        }
        
        bool success = super.transfer(to, amount);
        if (success) {
            emit Transfer(_msgSender(), to, amount);
        }
        return success;
    }

    /**
     * @dev Overrides ERC20 transferFrom function with whitelist and freeze checks
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return success Whether the transfer was successful
     * @notice Checks if from address is frozen from sending
     * @notice Checks if to address is frozen from receiving
     * @notice Requires either from or to address to be whitelisted
     */
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

    /**
     * @dev Admin override transfer function for emergency situations
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @notice Only admin can call this function
     * @notice Bypasses whitelist restrictions
     * @notice Requires at least one account to be frozen
     * @notice Used for emergency transfers when normal transfers are blocked
     */
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
    function setTrustedForwarder(
        address _trustedForwarder,
        bool _isTrusted
    ) external onlyRole(DEFAULT_ADMIN_ROLE) invalidAddressCheck(_trustedForwarder) {
        trustedForwarder[_trustedForwarder] = _isTrusted;
    }

    function isTrustedForwarder(
        address forwarder
    ) public view override returns (bool) {
        return trustedForwarder[forwarder];
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    function decimals() public pure override returns (uint8) {
    return 8;
}
}
