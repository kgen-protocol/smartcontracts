// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC1155Upgradeable.sol";

/**
 * @title IKCashMarketplace
 * @dev Interface for the KCash Marketplace contract
 */
interface IKCashMarketplace is IERC1155Upgradeable {
    /**
     * @dev Struct representing an item in the marketplace
     */
    struct Item {
        uint256 tokenId;
        string name;
        string productId;
        string productDetails;
    }

    /**
     * @dev Struct for signature-based purchases (inherited from IMarketplaceSigner)
     */
    struct Signature {
        uint256 tokenId;
        uint256 quantity;
        address buyerAddress;
        bytes signature;
    }

    /**
     * @dev Struct for batch signature-based purchases (inherited from IMarketplaceSigner)
     */
    struct SignatureBatch {
        uint256[] tokenIds;
        uint256[] quantities;
        address buyerAddress;
        bytes signature;
    }

    // Events
    event ItemAdded(uint256 indexed tokenId, string name, string productId, string productDetails);
    event ItemEdited(uint256 indexed tokenId, string name, string productId, string productDetails);
    event ItemPurchased(uint256 indexed tokenId, uint256 quantity, address buyer);

    // View Functions
    function ADMIN_MINT_ROLE() external view returns (bytes32);
    function designatedSigner() external view returns (address);
    function items(uint256 tokenId) external view returns (Item memory);
    function productIds(string memory productId) external view returns (uint256);
    function uri(uint256 _id) external view returns (string memory);

    // Admin Functions
    function startContract(address _owner, address _designatedSigner, string memory _baseURI) external;
    
    function addItem(
        uint256 _tokenId,
        string calldata _name,
        string calldata _productId,
        string calldata _productDetails
    ) external;

    function editItem(
        uint256 _tokenId,
        string calldata _name,
        string calldata _productId,
        string calldata _productDetails
    ) external;

    function setBaseURI(string memory _baseURI) external;
    function setDesignatedSigner(address _designatedSigner) external;
    function withdrawNative() external;

    // Purchase Functions
    function purchaseItem(Signature calldata signature) external;
    
    function purchaseItemAdmin(
        uint256 _tokenId,
        uint256 _quantity,
        address _buyer
    ) external;

    function purchaseItems(
        address[] calldata _buyers,
        uint256[][] calldata _tokenIds,
        uint256[][] calldata _quantities
    ) external;

    function purchaseItemsAdmin(
        address[] calldata _buyers,
        uint256[][] calldata _tokenIds,
        uint256[][] calldata _quantities
    ) external;

    function purchaseItemBatch(SignatureBatch calldata signature) external;

    function purchaseItemBatchAdmin(
        address _buyer,
        uint256[] calldata _tokenIds,
        uint256[] calldata _quantities
    ) external;

    // Interface Support
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}