//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MarketplaceBuyerSigner is EIP712 {
    string private constant SIGNING_DOMAIN = "MarketplaceBuyerSigner";
    string private constant SIGNATURE_VERSION = "1";

    struct Signature {
        address walletAddress;
        uint256[] tokenIds;
        uint256[] quantities;
        uint256 usdtAmount;
        uint256 nonce;
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
                            "Signature(address walletAddress,uint256[] tokenIds,uint256[] quantities,uint256 usdtAmount,uint256 nonce)"
                        ),
                        signature.walletAddress,
                        keccak256(abi.encodePacked(signature.tokenIds)),
                        keccak256(abi.encodePacked(signature.quantities)),
                        signature.usdtAmount,
                        signature.nonce
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
            "MarketplaceBuyerSigner: invalid signature"
        );
        _;
    }
}
