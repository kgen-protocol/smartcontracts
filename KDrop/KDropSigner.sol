//SPDX-License-Identifier: MIT
//   _  ______                    ____  _
//  | |/ /  _ \ _ __ ___  _ __   / ___|(_) __ _ _ __   ___ _ __
//  | ' /| | | | '__/ _ \| '_ \  \___ \| |/ _` | '_ \ / _ \ '__|
//  | . \| |_| | | | (_) | |_) |  ___) | | (_| | | | |  __/ |
//  |_|\_\____/|_|  \___/| .__/  |____/|_|\__, |_| |_|\___|_|
//                       |_|              |___/
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract KDropSigner is EIP712 {
    string private constant SIGNING_DOMAIN = "KDropSigner";
    string private constant SIGNATURE_VERSION = "1";

    struct Signature {
        address userAddress;
        address rewardToken;
        string userId;
        uint256 rewardAmount;
        string campaignId;
        bytes signature;
    }

    constructor() EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {}

    function _hash(
        Signature calldata signature
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "Signature(address userAddress,address rewardToken,string userId,uint256 rewardAmount,string campaignId)"
                        ),
                        signature.userAddress,
                        signature.rewardToken,
                        keccak256(abi.encodePacked(signature.userId)),
                        signature.rewardAmount,
                        keccak256(abi.encodePacked(signature.campaignId))
                    )
                )
            );
    }

    function _verify(
        Signature calldata signature
    ) internal view returns (address) {
        bytes32 digest = _hash(signature);
        return ECDSA.recover(digest, signature.signature);
    }

    function getSigner(
        Signature calldata signature
    ) public view returns (address) {
        return _verify(signature);
    }

    modifier isValidSignature(
        Signature calldata signature,
        address designatedSigner
    ) {
        require(
            getSigner(signature) == designatedSigner,
            "KDropSigner: invalid signature"
        );
        _;
    }
}
