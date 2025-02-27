// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./KStorePurchaseProcessorSignerUpgradable.sol";
import "./Interface/IUSDTTreasury.sol";
import "./Interface/IKCashMarketplace.sol";

contract KStorePurchaseProcessorUpgradable is
    Initializable,
    Ownable2StepUpgradeable,
    KStorePurchaseProcessorSignerUpgradable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public usdt;
    IUSDTTreasury public treasury;
    IKCashMarketplace public kStoreMarketplace;
    address public designatedSigner;
    mapping(bytes => bool) public usedSignatures;

    uint256[49] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _usdt,
        address _treasury,
        address _designatedSigner,
        address _kStoreMarketplace
    ) public initializer {
        __Ownable_init();
        __Signer_init();
        usdt = IERC20Upgradeable(_usdt);
        treasury = IUSDTTreasury(_treasury);
        designatedSigner = _designatedSigner;
        kStoreMarketplace = IKCashMarketplace(_kStoreMarketplace);
    }

    function initiatePurchase(
        Signature memory signature
    ) external isValidSignature(signature, designatedSigner) {
        require(!usedSignatures[signature.signature], "Signature already used");
        treasury.withdraw(signature.amount, signature.to);
        usdt.safeTransferFrom(signature.to, address(this), signature.amount);
        kStoreMarketplace.purchaseItemBatchAdmin(
            signature.mintTo,
            signature.tokenIds,
            signature.quantities
        );
        usedSignatures[signature.signature] = true;
    }

    //setter functions
    function setUsdt(address _usdt) external onlyOwner {
        usdt = IERC20Upgradeable(_usdt);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = IUSDTTreasury(_treasury);
    }

    function setKStoreMarketplace(
        address _kStoreMarketplace
    ) external onlyOwner {
        kStoreMarketplace = IKCashMarketplace(_kStoreMarketplace);
    }

    function setDesignatedSigner(address _designatedSigner) external onlyOwner {
        designatedSigner = _designatedSigner;
    }

    //recover functions
    function withdrawUsdt() external onlyOwner {
        IERC20Upgradeable(usdt).safeTransfer(
            msg.sender,
            IERC20Upgradeable(usdt).balanceOf(address(this))
        );
    }

    function withdrawToken(address _token) external onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(
            msg.sender,
            IERC20Upgradeable(_token).balanceOf(address(this))
        );
    }

    function withdrawNative() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Failed to send Ether");
    }
}
