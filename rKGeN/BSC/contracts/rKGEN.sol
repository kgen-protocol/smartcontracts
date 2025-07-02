// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ERC2771ContextUpgradeable/ERC2771ContextUpgradable.sol";

contract rKGEN is 
    Initializable,
    ERC20Upgradeable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC2771ContextUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURN_VAULT_ROLE = keccak256("BURN_VAULT_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant WHITELIST_SENDER_ROLE = keccak256("WHITELIST_SENDER_ROLE");
    bytes32 public constant WHITELIST_RECEIVER_ROLE = keccak256("WHITELIST_RECEIVER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public nominatedAdmin;
    mapping(address => bool) public frozenAccounts;
    mapping(address => bool) public trustedForwarder;

    
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

    // Custom errors for better gas efficiency and consistency
    error AlreadyExists();
    error NotTreasuryAddress();
    error NotWhitelistSender();
    error NotWhitelistReceiver();
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
    error CannotTransferToSelf();
    error AccountIsFrozen();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAdmin) public initializer {
        __ERC20_init("rKGEN", "rKGEN");
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(MINTER_ROLE, initialAdmin);
        _grantRole(BURN_VAULT_ROLE, initialAdmin);
        _grantRole(UPGRADER_ROLE, initialAdmin);
        
        // Mint initial supply to the admin
        // _mint(initialAdmin, 400_000_000 * 10**decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    /**
     * @dev Modifier to check if the amount is valid
     */
    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    /**
     * @dev Modifier to check if the address is valid
     */
    modifier validAddress(address addr) {
        if (addr == address(0)) revert NotValidAddress();
        _;
    }

    /**
     * @dev Modifier to check if the account is not frozen
     */
    modifier notFrozen(address account) {
        if (frozenAccounts[account]) revert AccountIsFrozen();
        _;
    }

    /**
     * @dev Modifier to check whitelist status
     */
    modifier whitelistedTransfer(address from, address to) {
        if (to == from) revert CannotTransferToSelf();
        if (!hasRole(WHITELIST_SENDER_ROLE, from) && !hasRole(WHITELIST_RECEIVER_ROLE, to)) {
            revert InvalidReceiverOrSender();
        }
        _;
    }

    /**
     * @dev Override transfer function to implement whitelist restrictions
     */
    function transfer(address to, uint256 amount) 
        public 
        override 
        nonReentrant
        validAmount(amount)
        validAddress(to)
        notFrozen(_msgSender())
        notFrozen(to)
        whitelistedTransfer(_msgSender(), to)
        returns (bool) 
    {
        return super.transfer(to, amount);
    }

    /**
     * @dev Override transferFrom function to implement whitelist restrictions
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        nonReentrant
        validAmount(amount)
        validAddress(to)
        notFrozen(from)
        notFrozen(to)
        whitelistedTransfer(from, to)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Mint tokens to any whitelisted receiver address
     */
    function mint(address to, uint256 amount)
        external
        nonReentrant
        onlyRole(MINTER_ROLE)
        validAmount(amount)
        validAddress(to)
    {

        _mint(to, amount);
        emit MintedToTreasury(to, amount);
    }

    /**
     * @dev Burn tokens from the burn vault
     */
    function burn(address from, uint256 amount)
        external
        nonReentrant
        onlyRole(BURN_VAULT_ROLE)
        validAmount(amount)
        validAddress(from)
    {
        _burn(from, amount);
    }

    /**
     * @dev Freeze an account
     */
    function freezeAccount(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(account)
    {
        frozenAccounts[account] = true;
        emit AccountFrozen(account);
    }

    /**
     * @dev Unfreeze an account
     */
    function unfreezeAccount(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(account)
    {
        frozenAccounts[account] = false;
        emit AccountUnfrozen(account);
    }

    /**
     * @dev Nominate a new admin
     */
    function nominateAdmin(address newAdmin)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(newAdmin)
    {
        if (newAdmin == _msgSender()) revert CannotNominateSelf();
        nominatedAdmin = newAdmin;
        emit NominatedAdminEvent("New Admin Nominated, Now new admin need to accept the role", newAdmin);
    }

    /**
     * @dev Accept admin role
     */
    function acceptAdminRole()
        external
        validAddress(_msgSender())
    {
        if (nominatedAdmin != _msgSender()) revert NotNominated();
        
        // Revoke the current admin role - improved role management
        uint256 adminCount = getRoleMemberCount(DEFAULT_ADMIN_ROLE);
        for (uint256 i = 0; i < adminCount; i++) {
            address oldAdmin = getRoleMember(DEFAULT_ADMIN_ROLE, i);
            if (oldAdmin != address(0)) {
                _revokeRole(DEFAULT_ADMIN_ROLE, oldAdmin);
            }
        }
        
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        nominatedAdmin = address(0);
        emit UpdatedAdmin("New Admin Added", _msgSender());
    }

    /**
     * @dev Add minter address
     */
    function addMinter(address newMinter)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(newMinter)
    {
        if (hasRole(MINTER_ROLE, newMinter)) revert AlreadyMinter();
        
        _grantRole(MINTER_ROLE, newMinter);
        emit UpdatedMinter("New Minter Added", newMinter);
    }

    /**
     * @dev Remove minter address
     */
    function removeMinter(address minterAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(minterAddress)
    {
        if (!hasRole(MINTER_ROLE, minterAddress)) revert NotMinter();
        
        _revokeRole(MINTER_ROLE, minterAddress);
        emit UpdatedMinter("Minter Removed", minterAddress);
    }

    /**
     * @dev Add burn vault address
     */
    function addBurnVault(address newBurnVault)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(newBurnVault)
    {
        if (hasRole(BURN_VAULT_ROLE, newBurnVault)) revert AlreadyBurnVault();
        
        _grantRole(BURN_VAULT_ROLE, newBurnVault);
        emit UpdatedBurnVault("New Burn Vault Added", newBurnVault);
    }

    /**
     * @dev Remove burn vault address
     */
    function removeBurnVault(address burnVaultAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(burnVaultAddress)
    {
        if (!hasRole(BURN_VAULT_ROLE, burnVaultAddress)) revert NotBurnVault();
        
        _revokeRole(BURN_VAULT_ROLE, burnVaultAddress);
        emit UpdatedBurnVault("Burn Vault Removed", burnVaultAddress);
    }

    /**
     * @dev Update minter address (legacy function for backward compatibility)
     * @notice This function replaces all existing minters with a single new minter
     */
    function updateMinter(address newMinter)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(newMinter)
    {
        if (hasRole(MINTER_ROLE, newMinter)) revert AlreadyMinter();
        
        // Revoke all existing minter roles
        uint256 minterCount = getRoleMemberCount(MINTER_ROLE);
        for (uint256 i = 0; i < minterCount; i++) {
            address oldMinter = getRoleMember(MINTER_ROLE, i);
            if (oldMinter != address(0)) {
                _revokeRole(MINTER_ROLE, oldMinter);
            }
        }
        
        _grantRole(MINTER_ROLE, newMinter);
        emit UpdatedMinter("Minter Updated (Legacy)", newMinter);
    }

    /**
     * @dev Update burn vault address (legacy function for backward compatibility)
     * @notice This function replaces all existing burn vaults with a single new burn vault
     */
    function updateBurnVault(address newBurnVault)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(newBurnVault)
    {
        if (hasRole(BURN_VAULT_ROLE, newBurnVault)) revert AlreadyBurnVault();
        
        // Revoke all existing burn vault roles
        uint256 burnVaultCount = getRoleMemberCount(BURN_VAULT_ROLE);
        for (uint256 i = 0; i < burnVaultCount; i++) {
            address oldBurnVault = getRoleMember(BURN_VAULT_ROLE, i);
            if (oldBurnVault != address(0)) {
                _revokeRole(BURN_VAULT_ROLE, oldBurnVault);
            }
        }
        
        _grantRole(BURN_VAULT_ROLE, newBurnVault);
        emit UpdatedBurnVault("Burn Vault Updated (Legacy)", newBurnVault);
    }

    /**
     * @dev Add treasury address
     */
    function addTreasuryAddress(address newAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(newAddress)
    {
        if (hasRole(TREASURY_ROLE, newAddress)) revert AlreadyTreasury();
        
        _grantRole(TREASURY_ROLE, newAddress);
        
        // If not already a whitelist sender, add as one
        if (!hasRole(WHITELIST_SENDER_ROLE, newAddress)) {
            _grantRole(WHITELIST_SENDER_ROLE, newAddress);
            emit AddedSenderAddress("New Sender Address Whitelisted", newAddress);
        }
        
        emit AddedTreasuryAddress("New Treasury Address Added", newAddress);
    }

    /**
     * @dev Remove treasury address
     */
    function removeTreasuryAddress(address treasuryAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(treasuryAddress)
    {
        if (!hasRole(TREASURY_ROLE, treasuryAddress)) revert NotTreasury();
        
        _revokeRole(TREASURY_ROLE, treasuryAddress);
        emit RemovedTreasuryAddress("Treasury Address Removed", treasuryAddress);
    }

    /**
     * @dev Add whitelist sender
     */
    function addWhitelistSender(address newAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(newAddress)
    {
        if (hasRole(WHITELIST_SENDER_ROLE, newAddress)) revert AlreadyWhitelistedSender();
        
        _grantRole(WHITELIST_SENDER_ROLE, newAddress);
        emit AddedSenderAddress("New Sender Address Whitelisted", newAddress);
    }

    /**
     * @dev Remove whitelist sender
     */
    function removeWhitelistSender(address senderAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(senderAddress)
    {
        if (!hasRole(WHITELIST_SENDER_ROLE, senderAddress)) revert NotWhitelistedSender();
        if (hasRole(TREASURY_ROLE, senderAddress)) revert CannotDeleteTreasuryAddress();
        
        _revokeRole(WHITELIST_SENDER_ROLE, senderAddress);
        emit RemovedSenderAddress("Sender Address Removed From Whitelist", senderAddress);
    }

    /**
     * @dev Add whitelist receiver
     */
    function addWhitelistReceiver(address newAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(newAddress)
    {
        if (hasRole(WHITELIST_RECEIVER_ROLE, newAddress)) revert AlreadyWhitelistedReceiver();
        
        _grantRole(WHITELIST_RECEIVER_ROLE, newAddress);
        emit AddedReceiverAddress("New Receiver Address Whitelisted", newAddress);
    }

    /**
     * @dev Remove whitelist receiver
     */
    function removeWhitelistReceiver(address receiverAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(receiverAddress)
    {
        if (!hasRole(WHITELIST_RECEIVER_ROLE, receiverAddress)) revert NotWhitelistedReceiver();
        
        _revokeRole(WHITELIST_RECEIVER_ROLE, receiverAddress);
        emit RemovedReceiverAddress("Receiver Address Removed From Whitelist", receiverAddress);
    }

    function setTrustedForwarder(
        address _trustedForwarder,
        bool _isTrusted
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
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
} 