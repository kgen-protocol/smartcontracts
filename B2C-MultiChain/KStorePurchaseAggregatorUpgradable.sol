// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./KStorePurchaseAggregatorUpgradableSigner.sol";
import "./Interface/IUSDTTreasury.sol";

contract KStorePurchaseAggregatorUpgradable is
    Initializable,
    Ownable2StepUpgradeable,
    KStorePurchaseAggregatorUpgradableSigner
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public usdt;
    IUSDTTreasury public treasury;
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
        address _designatedSigner
    ) public initializer {
        __Ownable_init();
        __Signer_init();
        usdt = IERC20Upgradeable(_usdt);
        treasury = IUSDTTreasury(_treasury);
        designatedSigner = _designatedSigner;
    }

    function initiatePurchase(
        Signature memory _signature
    ) external isValidSignature(_signature, designatedSigner) {
        require(
            !usedSignatures[_signature.signature],
            "KPA: Signature already used"
        );
        treasury.withdraw(_signature.amount, _signature.to);
        usdt.safeTransferFrom(msg.sender, address(this), _signature.amount);
        usedSignatures[_signature.signature] = true;
    }

    //setter functions
    function setUsdt(address _usdt) external onlyOwner {
        usdt = IERC20Upgradeable(_usdt);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = IUSDTTreasury(_treasury);
    }

    function setDesignatedSigner(address _designatedSigner) external onlyOwner {
        designatedSigner = _designatedSigner;
    }

    //recover functions
    function withDrawUSDT() external onlyOwner {
        usdt.safeTransfer(msg.sender, usdt.balanceOf(address(this)));
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
