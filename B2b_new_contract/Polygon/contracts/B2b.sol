// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import "./ERC2771Context/ERC2771ContextUpgradable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    
    function balanceOf(address account) external view returns (uint256);
}

contract B2bContract is ERC2771ContextUpgradable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    struct Order {
        string orderId;
        string dpIdentifier;
        string productIdentifier;
        string purchaseUtr;
        string purchaseDate;
        uint256 quantity;
        uint256 orderValue;
        address customer;
    }
    
    mapping(address => bool) public trustedForwarder;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // === Added: withdrawal role + whitelist ===
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
    mapping(address => bool) public withdrawalWhitelist;
    event WhitelistUpdated(address indexed addr, bool isWhitelisted);
    event WithdrawerRoleUpdated(address indexed account, bool isWithdrawer);
    // =========================================

    mapping(string => Order) public orders;
    uint256 public totalOrders;
    
    event OrderPlaced(
        string orderId,
        string dpId,
        string productId,
        string purchaseUtr,
        string purchaseDate,
        uint256 quantity,
        uint256 amount,
        address customer
    );
    event USDTWithdrawn(address to, uint256 amount);
    event USDTAddressUpdated(address oldAddress, address newAddress);
    
    address public usdtAddress;

    // NOTE: storage layout change—added two mappings above. If upgrading a deployed proxy,
    // adjust carefully. For fresh deployments this is fine.
    uint256[48] private __gap; // was 50; now 48 after adding 2 new state vars

    function initialize(address _usdtAddress) public initializer {
        require(_usdtAddress != address(0), "Invalid USDT address");
        __AccessControl_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
        usdtAddress = _usdtAddress;
        totalOrders = 0;
    }

    function depositOrder(
        string memory orderId,
        string memory dpId,
        string memory productId,
        string memory purchaseUtr,
        string memory purchaseDate,
        uint256 quantity,
        uint256 amount
    ) public nonReentrant {
        require(bytes(orderId).length > 0, "Order ID is required");
        require(bytes(dpId).length > 0, "DP Identifier is required");
        require(bytes(productId).length > 0, "Product Identifier is required");
        require(bytes(purchaseUtr).length > 0, "Purchase UTR is required");
        require(quantity > 0, "Quantity must be greater than zero");
        require(amount > 0, "Amount must be greater than zero");
        require(
            bytes(orders[orderId].orderId).length == 0,
            "Order with this Order ID already exists"
        );
        
        require(
            IERC20(usdtAddress).transferFrom(_msgSender(), address(this), amount),
            "USDT transfer failed"
        );
        
        Order memory newOrder = Order({
            orderId: orderId,
            dpIdentifier: dpId,
            productIdentifier: productId,
            purchaseUtr: purchaseUtr,
            purchaseDate: purchaseDate,
            quantity: quantity,
            orderValue: amount,
            customer: _msgSender()
        });
        orders[orderId] = newOrder;
        totalOrders++;
        
        emit OrderPlaced(
            orderId,
            dpId,
            productId,
            purchaseUtr,
            purchaseDate,
            quantity,
            amount,
            _msgSender()
        );
    }

    function getOrder(string memory orderId) public view returns (
        string memory dpId,
        string memory productId,
        string memory purchaseUtr,
        string memory purchaseDate,
        uint256 quantity,
        uint256 orderValue,
        address customer
    ) {
        require(bytes(orders[orderId].orderId).length > 0, "Order does not exist");
        Order memory order = orders[orderId];
        return (
            order.dpIdentifier,
            order.productIdentifier,
            order.purchaseUtr,
            order.purchaseDate,
            order.quantity,
            order.orderValue,
            order.customer
        );
    }

    function orderExists(string memory orderId) public view returns (bool) {
        return bytes(orders[orderId].orderId).length > 0;
    }

    function setUsdtAddress(address _usdtAddress) public onlyRole(ADMIN_ROLE) {
        require(_usdtAddress != address(0), "Invalid USDT address");
        address oldAddress = usdtAddress;
        usdtAddress = _usdtAddress;
        emit USDTAddressUpdated(oldAddress, _usdtAddress);
    }

    /// @notice Admins can withdraw anywhere; Withdrawers can withdraw only to whitelisted addresses
    function withdrawUSDT(
        address to,
        uint256 amount
    ) public nonReentrant {
        // Authorization: must be ADMIN_ROLE or WITHDRAWER_ROLE
        bool isAdmin = hasRole(ADMIN_ROLE, _msgSender());
        bool isWithdrawer = hasRole(WITHDRAWER_ROLE, _msgSender());
        require(isAdmin || isWithdrawer, "Not authorized");

        // Destination rules for withdrawer role
        if (!isAdmin) {
            require(withdrawalWhitelist[to], "Recipient not whitelisted");
        }

        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than zero");
        require(
            IERC20(usdtAddress).balanceOf(address(this)) >= amount,
            "Insufficient contract balance"
        );
        require(
            IERC20(usdtAddress).transfer(to, amount),
            "USDT transfer failed"
        );
        emit USDTWithdrawn(to, amount);
    }

    function getContractBalance() public view returns (uint256) {
        return IERC20(usdtAddress).balanceOf(address(this));
    }

    function setTrustedForwarder(
        address _trustedForwarder,
        bool _isTrusted
    ) external onlyRole(ADMIN_ROLE) {
        require(_trustedForwarder != address(0), "Invalid forwarder address");
        trustedForwarder[_trustedForwarder] = _isTrusted;
    }

    function isTrustedForwarder(
        address forwarder
    ) public view override returns (bool) {
        return trustedForwarder[forwarder];
    }

    // === Added: admin control over WITHDRAWER_ROLE ===
    function setWithdrawer(address account, bool isWithdrawer_) external onlyRole(ADMIN_ROLE) {
        require(account != address(0), "Invalid address");
        if (isWithdrawer_) {
            if (!hasRole(WITHDRAWER_ROLE, account)) {
                _grantRole(WITHDRAWER_ROLE, account);
            }
        } else {
            if (hasRole(WITHDRAWER_ROLE, account)) {
                _revokeRole(WITHDRAWER_ROLE, account);
            }
        }
        emit WithdrawerRoleUpdated(account, isWithdrawer_);
    }

    // === Added: admin control over whitelist ===
    function setWhitelisted(address addr, bool isWhitelisted) external onlyRole(ADMIN_ROLE) {
        require(addr != address(0), "Invalid address");
        withdrawalWhitelist[addr] = isWhitelisted;
        emit WhitelistUpdated(addr, isWhitelisted);
    }

    // Optional helpers
    function isWhitelisted(address addr) external view returns (bool) {
        return withdrawalWhitelist[addr];
    }

    function isWithdrawer(address account) external view returns (bool) {
        return hasRole(WITHDRAWER_ROLE, account);
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
}
