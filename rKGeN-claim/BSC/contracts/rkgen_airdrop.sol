// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./ERC2771ContextUpgradeable/ERC2771ContextUpgradable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract RKGENAirdrop is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC2771ContextUpgradeable,
    EIP712Upgradeable
{
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public rewardSigner;
    uint256 public chainId;
    address public nominatedAdmin;

    // user => token => nonce (per-user, per-token nonce tracking like Move implementation)
    mapping(address => mapping(address => uint256)) public nonces;
    mapping(address => bool) public trustedForwarder;
    mapping(address => bool) public whitelistedTokens;

    modifier invalidAddressCheck(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }

    // EIP-712 Type Hash for Claim
    bytes32 public constant CLAIM_TYPEHASH =
        keccak256(
            "Claim(address user,address token,uint256 amount,uint256 nonce,uint256 chainId)"
        );

    // Events for better tracking and debugging
    event Claimed(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 nonce
    );
    event SignerUpdated(address indexed newSigner);
    event AdminNominated(address indexed nominatedAdmin);
    event AdminUpdated(address indexed newAdmin);
    event TokensWithdrawn(
        address indexed admin,
        address indexed token,
        uint256 amount
    );

    struct SignedMessage {
        address user;
        address token;
        uint256 amount;
        uint256 nonce;
        uint256 chainId;
    }

    // Custom errors for better gas efficiency and error handling
    error InvalidSigner();
    error InvalidNonce();
    error InvalidSignature();
    error InvalidAdmin();
    error NoNominatedAdmin();
    error AlreadyExists();
    error NotAdmin();
    error NotWhitelistedToken();
    error InvalidAddress();

    constructor() {
        // _disableInitializers();
    }

    function initialize(
        string memory _name,
        uint256 _chainId
    ) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
        __ReentrancyGuard_init();
        rewardSigner = _msgSender();
        chainId = _chainId;
        __EIP712_init(_name, "1");
    }

    function updateSigner(address newSigner)
        external
        onlyRole(ADMIN_ROLE)
        invalidAddressCheck(newSigner)
    {
        if (newSigner == address(0)) revert InvalidSigner();
        if (rewardSigner == newSigner) revert AlreadyExists();

        rewardSigner = newSigner;
        emit SignerUpdated(newSigner);
    }

    // Admin transfer mechanism similar to Move implementation
    function nominateAdmin(address newAdmin)
        external
        onlyRole(ADMIN_ROLE)
        invalidAddressCheck(newAdmin)
    {
        if (newAdmin == msg.sender) revert AlreadyExists();

        nominatedAdmin = newAdmin;
        emit AdminNominated(newAdmin);
    }

    function acceptAdminRole() external {
        if (nominatedAdmin == address(0)) revert NoNominatedAdmin();
        if (msg.sender != nominatedAdmin) revert InvalidAdmin();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        nominatedAdmin = address(0);

        emit AdminUpdated(msg.sender);
    }

    // Token withdrawal function for admin
    function withdrawTokens(
        address token,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) invalidAddressCheck(token) {
        IERC20(token).safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, token, amount);
    }

    // Get nonce for a specific user and token (view function)
    function getNonce(
        address user,
        address token
    ) public view returns (uint256) {
        return nonces[user][token];
    }

    /**
     * @dev Creates the EIP-712 hash for a claim using EIP712Upgradeable
     */
    function _hashClaim(
        address user,
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 _chainId
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        CLAIM_TYPEHASH,
                        user,
                        token,
                        amount,
                        nonce,
                        _chainId
                    )
                )
            );
    }

    /**
     * @dev Verifies the EIP-712 signature
     */
    function _verifyClaimSignature(
        address user,
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 _chainId,
        bytes calldata signature
    ) public view returns (bool) {
        bytes32 hash = _hashClaim(user, token, amount, nonce, _chainId);
        address recovered = ECDSA.recover(hash, signature);
        return recovered == rewardSigner;
    }

    function claim(
        address user,
        address token,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant invalidAddressCheck(user) {
        if (!whitelistedTokens[token]) revert NotWhitelistedToken();

        // Check if nonce matches current nonce for this user and token
        if (nonce != nonces[user][token]) revert InvalidNonce();

        // Verify EIP-712 signature
        bool isValid = _verifyClaimSignature(
            user,
            token,
            amount,
            nonce,
            chainId,
            signature
        );

        if (!isValid) revert InvalidSignature();

        // Increment nonce for this user and token
        nonces[user][token] += 1;

        // Transfer tokens to claimer
        IERC20(token).safeTransfer(user, amount);
        emit Claimed(user, token, amount, nonce);
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

    // View function to get nominated admin
    function getNominatedAdmin() external view returns (address) {
        return nominatedAdmin;
    }

    // View function to get reward signer
    function getRewardSigner() external view returns (address) {
        return rewardSigner;
    }

    function whitelistToken(address token)
        external
        onlyRole(ADMIN_ROLE)
        invalidAddressCheck(token)
    {
        whitelistedTokens[token] = true;
    }

    function isWhitelistedToken(address token) external view returns (bool) {
        return whitelistedTokens[token];
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
