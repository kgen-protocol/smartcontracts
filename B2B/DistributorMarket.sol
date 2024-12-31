// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract DistributorMarketUpgradeable is
    ERC1155Upgradeable,
    AccessControlUpgradeable
{
    using StringsUpgradeable for *;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    struct Item {
        string name;
        string description;
        string vendorId;
        string vendorName;
        address vendorWallet;
        uint256 tokenId;
    }

    event ItemAdded(
        uint256 tokenId,
        string name,
        string description,
        string vendorId,
        string vendorName,
        address vendorWallet
    );

    event ItemEdited(
        uint256 tokenId,
        string name,
        string description,
        string vendorId,
        string vendorName,
        address vendorWallet
    );

    event ItemPurchased(
        uint256 tokenId,
        uint256 quantity,
        uint256 totalPrice,
        address payToken,
        string utr
    );

    bytes32 public constant ADMIN_CONTROLLER_ROLE =
        keccak256("ADMIN_CONTROLLER_ROLE");
    address public payToken;
    address public storageContract;
    // Mapping from tokenId to Item
    mapping(uint256 => Item) public items;
    uint256[49] private __gap;

    function initialize(
        address _owner,
        address _payToken,
        address _storageContract
    ) external initializer {
        __ERC1155_init("");
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ADMIN_CONTROLLER_ROLE, _owner);
        payToken = _payToken;
        storageContract = _storageContract;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function addItem(
        uint256 _tokenId,
        string calldata _name,
        string calldata _description,
        string calldata _vendorId,
        string calldata _vendorName,
        address _vendorWallet
    ) external onlyRole(ADMIN_CONTROLLER_ROLE) {
        require(items[_tokenId].tokenId == 0, "Item already exists");
        Item memory item = Item({
            name: _name,
            description: _description,
            vendorId: _vendorId,
            vendorName: _vendorName,
            vendorWallet: _vendorWallet,
            tokenId: _tokenId
        });
        items[_tokenId] = item;
        emit ItemAdded(
            _tokenId,
            _name,
            _description,
            _vendorId,
            _vendorName,
            _vendorWallet
        );
    }

    function editItem(
        uint256 _tokenId,
        string calldata _name,
        string calldata _description,
        string calldata _vendorId,
        string calldata _vendorName,
        address _vendorWallet
    ) external onlyRole(ADMIN_CONTROLLER_ROLE) {
        Item storage item = items[_tokenId];
        require(item.tokenId == _tokenId, "Item does not exist");
        item.name = _name;
        item.description = _description;
        item.vendorId = _vendorId;
        item.vendorName = _vendorName;
        item.vendorWallet = _vendorWallet;
        emit ItemEdited(
            _tokenId,
            _name,
            _description,
            _vendorId,
            _vendorName,
            _vendorWallet
        );
    }

    function purchaseItem(
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _totalPrice,
        string calldata _utr
    ) external onlyRole(ADMIN_CONTROLLER_ROLE) {
        Item memory item = items[_tokenId];
        require(item.tokenId == _tokenId, "Item does not exist");
        require(_quantity > 0, "Quantity must be greater than 0");

        IERC20Upgradeable(payToken).safeTransferFrom(
            msg.sender,
            item.vendorWallet,
            _totalPrice
        );
        _mint(storageContract, _tokenId, _quantity, "");
        emit ItemPurchased(_tokenId, _quantity, _totalPrice, payToken, _utr);
    }

    function updatePayToken(
        address _payToken
    ) external onlyRole(ADMIN_CONTROLLER_ROLE) {
        payToken = _payToken;
    }

    function updateStorageContract(
        address _storageContract
    ) external onlyRole(ADMIN_CONTROLLER_ROLE) {
        storageContract = _storageContract;
    }

    function uri(uint256 _id) public view override returns (string memory) {
        Item memory item = items[_id];
        require(item.tokenId == _id, "Item does not exist");
        string memory json = Base64Upgradeable.encode(
            bytes(
                string(
                    abi.encodePacked(
                        "{",
                        '"token_id": ',
                        StringsUpgradeable.toString(_id),
                        ",",
                        '"name":"',
                        item.name,
                        '",',
                        '"description": "',
                        item.description,
                        '",',
                        "}"
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /**
     * @dev Checks if a contract supports a given interface.
     * @param interfaceId The interface identifier.
     * @return A boolean value indicating whether the contract supports the interface.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155Upgradeable).interfaceId ||
            interfaceId == type(IERC1155MetadataURIUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
