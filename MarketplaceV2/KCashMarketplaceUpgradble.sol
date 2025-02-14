pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "./MarketplaceSigner.sol";
import"../ERC2771Override/ERC2771Overrides.sol";
/**
 * @title KCashMarketplaceV2
 * @dev This contract implements the Kcash Marketplace by inheriting ERC1155.
 */
contract KCashMarketplaceUpgradable is
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    MarketplaceSigner,ERC2771Override
{
    using StringsUpgradeable for *;

    /**
     * @dev A struct representing an item in the marketplace.
     * @param name The name of the item.
     * @param productId The unique identifier of the product associated with the item.
     * @param productDetails The details of the product associated with the item.
     */
    struct Item {
        uint256 tokenId;
        string name;
        string productId;
        string productDetails;
    }
    /**
     * @dev The bytes32 constant `ADMIN_MINT_ROLE` represents the role required to perform admin minting.
     */
    bytes32 public constant ADMIN_MINT_ROLE = keccak256("ADMIN_MINT_ROLE");

    /**
     * @dev Public variable that stores the address of the designated signer.
     */
    address public designatedSigner;

    // Mapping from tokenId to Item
    mapping(uint256 => Item) public items;
    // Mapping from productId to tokenId
    mapping(string => uint256) public productIds;

    /**
     * @dev A mapping to keep track of used signatures.
     * The keys of the mapping are bytes and the values are booleans.
     * The mapping is used to check if a signature has already been used.
     */
    mapping(bytes => bool) usedSignatures;
    // Events
    // Event for adding an item
    event ItemAdded(
        uint256 indexed tokenId,
        string name,
        string productId,
        string productDetails
    );
    // Event for editing an item
    event ItemEdited(
        uint256 indexed tokenId,
        string name,
        string productId,
        string productDetails
    );
    // Event for purchasing an item
    event ItemPurchased(
        uint256 indexed tokenId,
        uint256 quantity,
        address buyer
    );

    uint256[48] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function startContract(
        address _owner,
        address _designatedSigner,
        string memory _baseURI
    ) external initializer {
        __ERC1155_init(_baseURI);
        __Signer_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ADMIN_MINT_ROLE, _owner);
        designatedSigner = _designatedSigner;
    }
function reintializer()  public reinitializer(2) {
    // add code for reintializer
}
    /**
     * @dev Returns the Uniform Resource Identifier (URI) for a given token ID.
     * @param _id uint256 ID of the token to query.
     * @return string URI of the token.
     */
    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(_id), _id.toString()));
    }

    /**
     * @dev Adds a new item to the marketplace.
     * @param _tokenId The unique identifier for the item.
     * @param _name The name of the item.
     * @param _productId The product ID associated with the item.
     * @param _productDetails Additional details about the product.
     * Requirements:
     * - The caller must have the DEFAULT_ADMIN_ROLE.
     * - The item with the given tokenId must not already exist.
     * Emits an {ItemAdded} event.
     */
    function addItem(
        uint256 _tokenId,
        string calldata _name,
        string calldata _productId,
        string calldata _productDetails
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Check if item with given tokenId already exists
        require(items[_tokenId].tokenId == 0, "Item already exists");
        // Create a new item
        Item memory newItem = Item({
            tokenId: _tokenId,
            name: _name,
            productId: _productId,
            productDetails: _productDetails
        });
        items[_tokenId] = newItem;
        productIds[_productId] = _tokenId;
        emit ItemAdded(_tokenId, _name, _productId, _productDetails);
    }

    /**
     * @dev Allows the default admin role to edit the details of an item.
     * @param _tokenId The ID of the item to be edited.
     * @param _name The new name of the item.
     * @param _productId The new product ID of the item.
     * @param _productDetails The new product details of the item.
     * Requirements:
     * - The caller must have the DEFAULT_ADMIN_ROLE.
     * - The item with the given `_tokenId` must exist.
     * - Emits an {ItemEdited} event.
     */
    function editItem(
        uint256 _tokenId,
        string calldata _name,
        string calldata _productId,
        string calldata _productDetails
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Check if item with given tokenId exists
        require(items[_tokenId].tokenId != 0, "Item does not exist");
        //delete previous productId
        delete productIds[items[_tokenId].productId];
        // Update item details
        items[_tokenId].name = _name;
        items[_tokenId].productId = _productId;
        items[_tokenId].productDetails = _productDetails;
        productIds[_productId] = _tokenId;
        emit ItemEdited(_tokenId, _name, _productId, _productDetails);
    }

    /**
     * @dev Internal function to purchase an item.
     * @param _tokenId The ID of the item to be purchased.
     * @param _quantity The quantity of the item to be purchased.
     * @param _buyer The address of the buyer.
     * @dev This function checks if the item with the given tokenId exists, mints the item to the buyer's address,
     * and emits an `ItemPurchased` event.
     * @dev Throws an error if the item does not exist.
     */
    function _purchaseItem(
        uint256 _tokenId,
        uint256 _quantity,
        address _buyer
    ) internal {
        require(items[_tokenId].tokenId != 0, "Item does not exist");
        _mint(_buyer, _tokenId, _quantity, "");
        emit ItemPurchased(_tokenId, _quantity, _buyer);
    }

    /**
     * @dev Allows an admin to purchase an item on behalf of a buyer.
     * @param _tokenId The ID of the item to be purchased.
     * @param _quantity The quantity of the item to be purchased.
     * @param _buyer The address of the buyer.
     */
    function purchaseItemAdmin(
        uint256 _tokenId,
        uint256 _quantity,
        address _buyer
    ) external onlyRole(ADMIN_MINT_ROLE) {
        _purchaseItem(_tokenId, _quantity, _buyer);
    }

    /**
     * @dev Allows a buyer to purchase an item using a valid signature.
     * @param signature The signature object containing the necessary information for the purchase.
     * @notice The function requires the signature to be valid and not already used.
     * @notice The caller must be the buyer specified in the signature.
     */
    function purchaseItem(
        Signature calldata signature
    ) external isValidSignature(signature, designatedSigner) {
        require(!usedSignatures[signature.signature], "Signature already used");
        require(
            signature.buyerAddress == _msgSender(),
            "Caller is not the buyer"
        );
        usedSignatures[signature.signature] = true;
        _purchaseItem(
            signature.tokenId,
            signature.quantity,
            signature.buyerAddress
        );
    }

    /**
     * @dev Purchases an item from the marketplace.
     * @param _buyers The address of the buyer.
     * @param _tokenIds The IDs of the items to be purchased.
     * @param _quantitys The quantities of the items to be purchased.
     * Emits an {ItemPurchased} event.
     * Requirements:
     * - The item with the given tokenId must exist.
     */

    function _purchaseItems(
        address[] calldata _buyers,
        uint256[][] calldata _tokenIds,
        uint256[][] calldata _quantitys
    ) internal {
        //check the array length and mint using batch mint
        require(_buyers.length == _tokenIds.length, "Array length mismatch");
        require(_buyers.length == _quantitys.length, "Array length mismatch");
        for (uint256 i = 0; i < _buyers.length; i++) {
            _mintBatch(_buyers[i], _tokenIds[i], _quantitys[i], "");
            for (uint256 j = 0; j < _tokenIds[i].length; j++) {
                emit ItemPurchased(
                    _tokenIds[i][j],
                    _quantitys[i][j],
                    _buyers[i]
                );
            }
        }
    }

    function purchaseItemsAdmin(
        address[] calldata _buyers,
        uint256[][] calldata _tokenIds,
        uint256[][] calldata _quantitys
    ) external onlyRole(ADMIN_MINT_ROLE) {
        _purchaseItems(_buyers, _tokenIds, _quantitys);
    }

    function _purchaseItemBatch(
        address _buyer,
        uint256[] calldata _tokenIds,
        uint256[] calldata _quantities
    ) internal {
        _mintBatch(_buyer, _tokenIds, _quantities, "");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            emit ItemPurchased(_tokenIds[i], _quantities[i], _buyer);
        }
    }

    function purchaseItemBatchAdmin(
        address _buyer,
        uint256[] calldata _tokenIds,
        uint256[] calldata _quantities
    ) external onlyRole(ADMIN_MINT_ROLE) {
        _purchaseItemBatch(_buyer, _tokenIds, _quantities);
    }

    function purchaseItemBatch(
        SignatureBatch calldata signature
    ) external isValidSignatureBatch(signature, designatedSigner) {
        require(!usedSignatures[signature.signature], "Signature already used");
        require(
            signature.buyerAddress == _msgSender() ,
            "Caller is not the buyer"
        );
        usedSignatures[signature.signature] = true;
        _purchaseItemBatch(
            signature.buyerAddress,
            signature.tokenIds,
            signature.quantities
        );
    }

    /**
     * @dev Allows the default admin role to withdraw the native currency from the contract.
     */
    function withdrawNative() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(_msgSender() ).transfer(address(this).balance);
    }

    /**
     * @dev Sets the base URI for all token IDs in the contract.
     * @param _baseURI The base URI to be set.
     * Requirements:
     * - Only the owner of the contract can call this function.
     */
    function setBaseURI(
        string memory _baseURI
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(_baseURI);
    }

    /**
     * @dev Sets the designated signer address.
     * Can only be called by the contract's default admin role.
     * @param _designatedSigner The address of the designated signer.
     */
    function setDesignatedSigner(
        address _designatedSigner
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        designatedSigner = _designatedSigner;
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

    /**
     * @dev Hook function that is called before any token transfer.
     * It checks if the token is soulbound, meaning it cannot be transferred between addresses.
     * This function is internal and overrides the same function in ERC1155Upgradeable contract.
     * @param operator The address performing the token transfer.
     * @param from The address transferring the tokens.
     * @param to The address receiving the tokens.
     * @param ids An array of token IDs being transferred.
     * @param amounts An array of amounts being transferred for each token ID.
     * @param data Additional data with no specified format.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable) {
        require(from == address(0) || to == address(0), "token is soulbound");
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    }


