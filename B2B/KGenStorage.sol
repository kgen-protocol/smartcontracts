// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract KGenStorage is AccessControlUpgradeable, ERC1155HolderUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    bytes32 public constant ADMIN_CONTROLLER_ROLE =
        keccak256("ADMIN_CONTROLLER_ROLE");
    bytes32 public constant BUYER_ROLE = keccak256("BUYER_ROLE");

    address public payToken;
    IERC1155Upgradeable public distributorMarket;

    event ItemSold(
        uint256 tokenId,
        uint256 quantity,
        uint256 totalPrice,
        string utr
    );

    function initialize(
        address _owner,
        address _payToken,
        address _distributorMarket
    ) public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(ADMIN_CONTROLLER_ROLE, _owner);
        _setupRole(BUYER_ROLE, _owner);
        payToken = _payToken;
        distributorMarket = IERC1155Upgradeable(_distributorMarket);
    }

    function purchaseNFT(
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _totalPrice,
        string calldata _utr
    ) external onlyRole(BUYER_ROLE) {
        IERC20Upgradeable(payToken).safeTransferFrom(
            msg.sender,
            address(this),
            _totalPrice
        );
        distributorMarket.safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _quantity,
            ""
        );
        emit ItemSold(_tokenId, _quantity, _totalPrice, _utr);
    }

    function setPayToken(
        address _payToken
    ) external onlyRole(ADMIN_CONTROLLER_ROLE) {
        payToken = _payToken;
    }

    function setDistributorMarket(
        address _distributorMarket
    ) external onlyRole(ADMIN_CONTROLLER_ROLE) {
        distributorMarket = IERC1155Upgradeable(_distributorMarket);
    }

    function withdrawToken(
        address _to,
        address _token,
        uint256 _amount
    ) external onlyRole(ADMIN_CONTROLLER_ROLE) {
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(AccessControlUpgradeable, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        return
            AccessControlUpgradeable.supportsInterface(interfaceId) ||
            interfaceId == type(IERC1155ReceiverUpgradeable).interfaceId;
    }
}
