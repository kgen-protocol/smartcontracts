// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IKCashMarketplaceUpgradble
 * @dev Interface for the KCashMarketplaceUpgradble contract.
 */
interface IKCashMarketplace {
    struct Item {
        uint256 tokenId;
        string name;
        string productId;
        string productDetails;
    }

    struct Signature {
        bytes signature;
        address buyerAddress;
        uint256 tokenId;
        uint256 quantity;
    }

    event ItemAdded(
        uint256 indexed tokenId,
        string name,
        string productId,
        string productDetails
    );

    event ItemEdited(
        uint256 indexed tokenId,
        string name,
        string productId,
        string productDetails
    );

    event ItemPurchased(
        uint256 indexed tokenId,
        uint256 quantity,
        address buyer
    );

    function startContract(
        address _owner,
        address _designatedSigner,
        string memory _baseURI
    ) external;

    function uri(uint256 _id) external view returns (string memory);

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

    function purchaseItemAdmin(
        uint256 _tokenId,
        uint256 _quantity,
        address _buyer
    ) external;

    function purchaseItemBatch(
        address _buyer,
        uint256[] calldata _tokenIds,
        uint256[] calldata _quantities
    ) external;

    function purchaseItem(Signature calldata signature) external;

    function purchaseItems(
        address[] calldata _buyers,
        uint256[][] calldata _tokenIds,
        uint256[][] calldata _quantitys
    ) external;

    function withdrawNative() external;

    function setBaseURI(string memory _baseURI) external;

    function setDesignatedSigner(address _designatedSigner) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
