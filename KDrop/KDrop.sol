//SPDX-License-Identifier: MIT
//  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.
// | .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |
// | |  ___  ____   | || |  ________    | || |  _______     | || |     ____     | || |   ______     | |
// | | |_  ||_  _|  | || | |_   ___ `.  | || | |_   __ \    | || |   .'    `.   | || |  |_   __ \   | |
// | |   | |_/ /    | || |   | |   `. \ | || |   | |__) |   | || |  /  .--.  \  | || |    | |__) |  | |
// | |   |  __'.    | || |   | |    | | | || |   |  __ /    | || |  | |    | |  | || |    |  ___/   | |
// | |  _| |  \ \_  | || |  _| |___.' / | || |  _| |  \ \_  | || |  \  `--'  /  | || |   _| |_      | |
// | | |____||____| | || | |________.'  | || | |____| |___| | || |   `.____.'   | || |  |_____|     | |
// | |              | || |              | || |              | || |              | || |              | |
// | '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |
//  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces/IKCash.sol";
import "./KDropSigner.sol";

contract KDrop is Ownable2Step, KDropSigner {
    address public designatedSiger;
    IKCash public kcash;

    mapping(bytes => bool) usedSignatures;

    event airdropClaimed(
        address userAddress,
        address rewardToken,
        string userId,
        uint256 rewardAmount,
        string campaignId
    );

    constructor(address _designatedSigner, address _kcash) {
        designatedSiger = _designatedSigner;
        kcash = IKCash(_kcash);
    }

    function setDesignatedSigner(address _designatedSigner) external onlyOwner {
        designatedSiger = _designatedSigner;
    }

    function depositToken(
        uint256 _amount,
        address _rewardToken
    ) external onlyOwner {
        IERC20(_rewardToken).transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawToken(
        uint256 _amount,
        address _rewardToken
    ) external onlyOwner {
        IERC20(_rewardToken).transfer(msg.sender, _amount);
    }

    function claimAirDrop(
        Signature calldata _signature
    ) external isValidSignature(_signature, designatedSiger) {
        require(
            !usedSignatures[_signature.signature],
            "KDrop: signature already used"
        );
        usedSignatures[_signature.signature] = true;
        if (_signature.rewardToken == address(kcash)) {
            kcash.adminTransferFromReward3ToReward2(
                _signature.userAddress,
                _signature.rewardAmount
            );
        } else {
            IERC20(_signature.rewardToken).transfer(
                _signature.userAddress,
                _signature.rewardAmount
            );
        }
        emit airdropClaimed(
            _signature.userAddress,
            _signature.rewardToken,
            _signature.userId,
            _signature.rewardAmount,
            _signature.campaignId
        );
    }

    function updateKCash(address _kcash) external onlyOwner {
        kcash = IKCash(_kcash);
    }
}
