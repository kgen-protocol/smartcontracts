//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract KStorePurchaseProcessorSignerUpgradable is EIP712Upgradeable {
    string private constant SIGNING_DOMAIN = "KStorePurchaseProcessor";
    string private constant SIGNATURE_VERSION = "1";
    struct Signature {
        address to;
        address mintTo;
        uint256 amount;
        uint256[] tokenIds;
        uint256[] quantities;
        uint256 nonce;
        bytes signature;
    }
    error InvalidSigner(); // if the call is not from the authorised address
    error InvalidSignature(); // if the signature is invalid
    // error NonceExpired(); // if the nonce is expired

    // constructor() EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {}
    function __Signer_init() internal initializer {
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
    }

    /// @notice Get signer from the signature
    /// @param signature Signature object to get signer
    function getSigner(
        Signature memory signature
    ) public view returns (address) {
        return _verify(signature);
    }

    /// @notice Get hash from the signature
    /// @param signature Signature object to get hash
    function _hash(Signature memory signature) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "Signature(address to,address mintTo,uint256 amount,uint256[] tokenIds,uint256[] quantities,uint256 nonce)"
                        ),
                        signature.to,
                        signature.mintTo,
                        signature.amount,
                        keccak256(abi.encodePacked(signature.tokenIds)),
                        keccak256(abi.encodePacked(signature.quantities)),
                        signature.nonce
                    )
                )
            );
    }

    /// @dev This function is used to verify signature
    ///@param signature Signature object to verify
    function _verify(
        Signature memory signature
    ) internal view returns (address) {
        bytes32 digest = _hash(signature);
        return ECDSAUpgradeable.recover(digest, signature.signature);
    }

    /// @dev This function is used to verify signature
    ///@param signature Signature object to verify
    modifier isValidSignature(
        Signature memory signature,
        address designatedSigner
    ) {
        if (getSigner(signature) != designatedSigner) {
            revert InvalidSignature();
        }
        _;
    }
}
