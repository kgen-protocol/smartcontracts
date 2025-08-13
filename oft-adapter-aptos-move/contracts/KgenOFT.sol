// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title KGENOFT
 * @dev  Omnichain Fungible Token (OFT) implementation
 * @notice This contract extends LayerZero's OFT with additional security features:
 *         - Access control for different roles
 *         - ERC2771 meta-transaction support with trusted forwarder management
 *         - Blacklist functionality for compliance
 *         - Emergency pause mechanism
 *         - Token recovery functionality
 * @author KGEN Development Team
 */
contract KgenOFT is OFT, AccessControl, ERC2771Context, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // =============================================================
    //                           CONSTANTS
    // =============================================================
    
    /// @notice Role for managing trusted forwarders
    bytes32 public constant FORWARDER_MANAGER_ROLE = keccak256("FORWARDER_MANAGER_ROLE");
    
    /// @notice Role for managing blacklist
    bytes32 public constant BLACKLIST_MANAGER_ROLE = keccak256("BLACKLIST_MANAGER_ROLE");
    
    /// @notice Role for pausing/unpausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    /// @notice Maximum number of trusted forwarders allowed
    uint256 public constant MAX_TRUSTED_FORWARDERS = 10;
   address public FEE_VAULT;
    
    // =============================================================
    //                            STORAGE
    // =============================================================
    
    /// @notice Set of trusted forwarders for gas optimization
    EnumerableSet.AddressSet private _trustedForwardersSet;
    
    /// @notice Mapping to track blacklisted addresses
    mapping(address => bool) public isBlackListed;

    
    /// @notice Emergency stop flag for cross-chain operations only
    bool public crossChainPaused;
    
    /// @notice Contract version for upgrades tracking
    string public constant VERSION = "1.0.0";

    // =============================================================
    //                            EVENTS
    // =============================================================
    
    /// @notice Emitted when a trusted forwarder is added
    event TrustedForwarderAdded(address indexed forwarder);
    
    /// @notice Emitted when a trusted forwarder is removed  
    event TrustedForwarderRemoved(address indexed forwarder);
    
    /// @notice Emitted when blacklist status changes
    event BlacklistStatusChanged(address indexed account, bool isBlacklisted);
    
    /// @notice Emitted when pause status changes
    event PauseStatusChanged(bool isPaused);
    
    /// @notice Emitted when cross-chain pause status changes
    event CrossChainPauseStatusChanged(bool isPaused);
    
    /// @notice Emitted when tokens are recovered
    event TokenRecovered(address indexed token, address indexed to, uint256 amount);
    
    /// @notice Emitted when rate limit is hit
    event RateLimitExceeded(address indexed user, uint32 indexed dstEid, uint256 amount, uint256 limit);
    event UpdateFeeVault(address  new_fee_vault,address  old_fee_vault);
    // =============================================================
    //                           ERRORS
    // =============================================================
    
    error ZeroAddress();
    error AlreadyTrustedForwarder();
    error NotTrustedForwarder();
    error MaxTrustedForwardersExceeded();
    error BlacklistedAddress(address account);
    error CrossChainOperationsPaused();
    error InvalidAmount();
    error TokenRecoveryFailed();

    // =============================================================
    //                         MODIFIERS
    // =============================================================
    
    /// @notice Ensures address is not blacklisted
    modifier notBlacklisted(address account) {
        if (isBlackListed[account]) revert BlacklistedAddress(account);
        _;
    }
    
    /// @notice Ensures cross-chain operations are not paused
    modifier whenCrossChainNotPaused() {
        if (crossChainPaused) revert CrossChainOperationsPaused();
        _;
    }

    // =============================================================
    //                        CONSTRUCTOR
    // =============================================================
    
    /**
     * @notice Initializes the KGENOFT contract
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _lzEndpoint LayerZero endpoint address
     * @param _delegate Address that will receive admin roles
     * @param _trustedForwarder Initial trusted forwarder for meta-transactions
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate,
        address _trustedForwarder
    ) 
        OFT(_name, _symbol, _lzEndpoint, _delegate) 
        Ownable(_delegate) 
        ERC2771Context(_trustedForwarder)
    {
        if (_delegate == address(0)) revert ZeroAddress();
        
        // Grant roles to the delegate
        _grantRole(DEFAULT_ADMIN_ROLE, _delegate);
        _grantRole(FORWARDER_MANAGER_ROLE, _delegate);
        _grantRole(BLACKLIST_MANAGER_ROLE, _delegate);
        _grantRole(PAUSER_ROLE, _delegate);
        // Set initial trusted forwarder
        if (_trustedForwarder != address(0)) {
            _trustedForwardersSet.add(_trustedForwarder);
            emit TrustedForwarderAdded(_trustedForwarder);
        }
    }

    // =============================================================
    //                      ADMIN FUNCTIONS
    // =============================================================
    
    /**
     * @notice Pauses or unpauses all contract operations
     * @param _paused True to pause, false to unpause
     */
    function setPaused(bool _paused) external onlyRole(PAUSER_ROLE) {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
        emit PauseStatusChanged(_paused);
    }

    function updateFeeVault(address  new_fee_vault) external onlyRole(DEFAULT_ADMIN_ROLE){
        emit UpdateFeeVault(new_fee_vault,FEE_VAULT);
        FEE_VAULT = new_fee_vault;
    }

    /**
     * @notice Pauses or unpauses only cross-chain operations
     * @param _paused True to pause cross-chain, false to unpause
     */
    function setCrossChainPaused(bool _paused) external onlyRole(PAUSER_ROLE) {
        crossChainPaused = _paused;
        emit CrossChainPauseStatusChanged(_paused);
    }
    
    /**
     * @notice Recovers accidentally sent ERC20 tokens
     * @dev Should not be used to recover the native token of this contract
     * @param token Address of the token to recover
     * @param to Address to send recovered tokens to
     * @param amount Amount of tokens to recover
     */
    function recoverERC20(
        address token, 
        address to, 
        uint256 amount
    ) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        
        try IERC20(token).transfer(to, amount) {
            emit TokenRecovered(token, to, amount);
        } catch {
            revert TokenRecoveryFailed();
        }
    }
    
    /**
     * @notice Recovers native ETH accidentally sent to contract
     * @param to Address to send recovered ETH to
     * @param amount Amount of ETH to recover
     */
    function recoverETH(address payable to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0 || amount > address(this).balance) revert InvalidAmount();
        
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH recovery failed");
        
        emit TokenRecovered(address(0), to, amount);
    }

    // =============================================================
    //                   BLACKLIST FUNCTIONS
    // =============================================================
    
    /**
     * @notice Adds or removes an address from blacklist
     * @param account Address to modify blacklist status for
     * @param blacklisted True to blacklist, false to remove from blacklist
     */
    function setBlacklistStatus(
        address account, 
        bool blacklisted
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        
        isBlackListed[account] = blacklisted;
        emit BlacklistStatusChanged(account, blacklisted);
    }
    
    /**
     * @notice Batch blacklist operation for efficiency
     * @param accounts Array of addresses to modify
     * @param blacklisted True to blacklist all, false to remove all from blacklist
     */
    function batchSetBlacklistStatus(
        address[] calldata accounts, 
        bool blacklisted
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == address(0)) revert ZeroAddress();
            isBlackListed[accounts[i]] = blacklisted;
            emit BlacklistStatusChanged(accounts[i], blacklisted);
        }
    }

    // =============================================================
    //                ERC2771 CONTEXT OVERRIDES
    // =============================================================
    
    /**
     * @notice Override _msgSender to support ERC2771 meta-transactions
     * @return Original sender address from meta-transaction data
     */
    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    /**
     * @notice Override _msgData to support ERC2771 meta-transactions
     * @return Original calldata from meta-transaction data
     */
    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @notice Override _contextSuffixLength to support ERC2771 meta-transactions
     * @return Context suffix length for meta-transactions
     */
    function _contextSuffixLength() internal view virtual override(Context, ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }

    // =============================================================
    //               TRUSTED FORWARDER MANAGEMENT
    // =============================================================
    
    /**
     * @notice Checks if an address is a trusted forwarder
     * @param forwarder Address to check
     * @return True if the forwarder is trusted
     */
    function isTrustedForwarder(address forwarder) public view virtual override returns (bool) {
        return _trustedForwardersSet.contains(forwarder);
    }

    /**
     * @notice Adds a trusted forwarder for meta-transactions
     * @param forwarder Address of the forwarder to add
     */
    function addTrustedForwarder(address forwarder) external onlyRole(FORWARDER_MANAGER_ROLE) {
        if (forwarder == address(0)) revert ZeroAddress();
        if (_trustedForwardersSet.contains(forwarder)) revert AlreadyTrustedForwarder();
        if (_trustedForwardersSet.length() >= MAX_TRUSTED_FORWARDERS) {
            revert MaxTrustedForwardersExceeded();
        }
        
        _trustedForwardersSet.add(forwarder);
        emit TrustedForwarderAdded(forwarder);
    }

    /**
     * @notice Removes a trusted forwarder
     * @param forwarder Address of the forwarder to remove
     */
    function removeTrustedForwarder(address forwarder) external onlyRole(FORWARDER_MANAGER_ROLE) {
        if (!_trustedForwardersSet.contains(forwarder)) revert NotTrustedForwarder();
        
        _trustedForwardersSet.remove(forwarder);
        emit TrustedForwarderRemoved(forwarder);
    }

    /**
     * @notice Gets all trusted forwarders
     * @return Array of trusted forwarder addresses
     */
    function getTrustedForwarders() external view returns (address[] memory) {
        return _trustedForwardersSet.values();
    }

    /**
     * @notice Gets the number of trusted forwarders
     * @return Number of trusted forwarders
     */
    function getTrustedForwardersCount() external view returns (uint256) {
        return _trustedForwardersSet.length();
    }


    /**
     * @notice Emergency function to update trusted forwarder
     * @dev Atomically removes old and adds new forwarder
     * @param oldForwarder Address of forwarder to remove
     * @param newForwarder Address of forwarder to add
     */
    function updateTrustedForwarder(
        address oldForwarder, 
        address newForwarder
    ) external onlyRole(FORWARDER_MANAGER_ROLE) {
        if (newForwarder == address(0)) revert ZeroAddress();
        if (!_trustedForwardersSet.contains(oldForwarder)) revert NotTrustedForwarder();
        if (_trustedForwardersSet.contains(newForwarder)) revert AlreadyTrustedForwarder();
        
        _trustedForwardersSet.remove(oldForwarder);
        _trustedForwardersSet.add(newForwarder);
        
        emit TrustedForwarderRemoved(oldForwarder);
        emit TrustedForwarderAdded(newForwarder);
    }


    // =============================================================
    //                   LAYERZERO OVERRIDES
    // =============================================================
    
    /**
     * @notice Override _send to add security checks
     * @param _sendParam Send parameters
     * @param _fee Messaging fee
     * @param _refundAddress Address to receive refund
     * @return msgReceipt Messaging receipt
     * @return oftReceipt OFT receipt
     */
    function _send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        internal
        override
        whenNotPaused
        whenCrossChainNotPaused
        notBlacklisted(_msgSender())
        nonReentrant
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        (uint256 amountSentLD, uint256 amountReceivedLD) = _debit(
            _msgSender(),
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.dstEid
        );

        (bytes memory message, bytes memory options) =
            _buildMsgAndOptions(_sendParam, amountReceivedLD);

        msgReceipt = _lzSend(_sendParam.dstEid, message, options, _fee, _refundAddress);
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);

        emit OFTSent(msgReceipt.guid, _sendParam.dstEid, _msgSender(), amountSentLD, amountReceivedLD);
    }
    function sendFrom(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress,
        uint256 gasFeeAmount 
    ) public payable returns  (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        transferFrom(_msgSender(), FEE_VAULT, gasFeeAmount); // amount should be > 0 only when we paying the gas fee for the user else it could be zero  if user is using eoa 
        (msgReceipt, oftReceipt) = _send(
            _sendParam,
            _fee,
            _refundAddress
        );
        return (msgReceipt, oftReceipt);
    }
    /**
     * @notice Override _credit to add blacklist check for recipients
     * @param _to Address to credit tokens to
     * @param _amountLD Amount in local decimals
     * @param _srcEid Source endpoint ID
     * @return amountReceivedLD Amount received in local decimals
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 _srcEid
    ) internal virtual override notBlacklisted(_to) returns (uint256 amountReceivedLD) {
        return super._credit(_to, _amountLD, _srcEid);
    }

    // =============================================================
    //                    TOKEN OVERRIDES
    // =============================================================
    
    /**
     * @notice Override transfer to add blacklist checks
     */
    function transfer(address to, uint256 amount) 
        public 
        virtual 
        override 
        whenNotPaused
        notBlacklisted(_msgSender())
        notBlacklisted(to)
        returns (bool) 
    {
        return super.transfer(to, amount);
    }

    /**
     * @notice Override transferFrom to add blacklist checks
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        virtual 
        override 
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
        returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }

    // =============================================================
    //                   INTERFACE SUPPORT
    // =============================================================
    
    /**
     * @notice Override supportsInterface to include all inherited interfaces
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }


}