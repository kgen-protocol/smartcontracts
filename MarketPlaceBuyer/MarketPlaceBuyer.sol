// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./Interfaces/IKcashMarketPlace.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MarketplaceBuyerSigner.sol";

contract MarketPlaceBuyer is Ownable, MarketplaceBuyerSigner {
    IKCashMarketplace public marketPlace;
    IERC20 public usdt;
    address public designatedSigner;
    mapping(bytes => bool) usedSignature;

    constructor(
        address _marketPlace,
        address _usdt,
        address _designatedSigner
    ) {
        marketPlace = IKCashMarketplace(_marketPlace);
        usdt = IERC20(_usdt);
        designatedSigner = _designatedSigner;
    }

    function updateUsdtAddress(address _usdt) external onlyOwner {
        usdt = IERC20(_usdt);
    }

    function updateMarketplaceAddress(address _marketPlace) external onlyOwner {
        marketPlace = IKCashMarketplace(_marketPlace);
    }

    function updateDesignatedSigner(
        address _designatedSigner
    ) external onlyOwner {
        designatedSigner = _designatedSigner;
    }

    function buy(
        Signature calldata _signature
    ) external isValidSignature(_signature, designatedSigner) {
        require(
            usedSignature[_signature.signature] == false,
            "Signature already used"
        );
        usdt.transferFrom(
            _signature.walletAddress,
            address(this),
            _signature.usdtAmount
        );
        marketPlace.purchaseItemBatch(
            _signature.walletAddress,
            _signature.tokenIds,
            _signature.quantities
        );
        usedSignature[_signature.signature] = true;
    }

    function withdraw() external onlyOwner {
        usdt.transfer(owner(), usdt.balanceOf(address(this)));
    }

    function withdrawNative() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
