//SPDX-License-Identifier: MIT

// ██╗  ██╗     ██████╗ █████╗ ███████╗██╗  ██╗    ███████╗██╗ ██████╗ ███╗   ██╗███████╗██████╗
// ██║ ██╔╝    ██╔════╝██╔══██╗██╔════╝██║  ██║    ██╔════╝██║██╔════╝ ████╗  ██║██╔════╝██╔══██╗
// █████╔╝     ██║     ███████║███████╗███████║    ███████╗██║██║  ███╗██╔██╗ ██║█████╗  ██████╔╝
// ██╔═██╗     ██║     ██╔══██║╚════██║██╔══██║    ╚════██║██║██║   ██║██║╚██╗██║██╔══╝  ██╔══██╗
// ██║  ██╗    ╚██████╗██║  ██║███████║██║  ██║    ███████║██║╚██████╔╝██║ ╚████║███████╗██║  ██║
// ╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝    ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝


//TODO: add storage gap

pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

/**
 * @title KCashSigner
 */
contract KCashSigner is EIP712Upgradeable {
    string private constant SIGNING_DOMAIN = "KCashSigner";
    string private constant SIGNATURE_VERSION = "1";

    struct BucketSignature {
        // DEPRECATED: reward1 is deprecated and should not be used in new logic
        uint256 reward1; // Deprecated
        // DEPRECATED: reward2 is deprecated and should not be used in new logic
        uint256 reward2; // Deprecated
        uint256 reward3;
    }

    struct AdminTransferSignature {
        uint32 nonce;
        address from;
        address to;
        BucketSignature deductionFromSender;
        BucketSignature additionToRecipient;
        bytes signature;
    }

    struct TransferFromReward3ToReward2Signature {
        uint32 nonce;
        address from;
        address to;
        uint256 amount;
        bytes signature;
    }

    struct TransferFromReward3ToReward1Signature {
        uint32 nonce;
        address from;
        address to;
        uint256 amount;
        bytes signature;
    }

    // DEPRECATED: reward1 and reward2 are deprecated in bucket signatures
    bytes32 constant bucketSignatureHash =
        keccak256(
            "BucketSignature(uint256 reward1,uint256 reward2,uint256 reward3)"
        ); // Deprecated: reward1/reward2
    bytes32 constant adminTransferSignatureHash =
        keccak256(
            "AdminTransferSignature(uint32 nonce,address from,address to,BucketSignature deductionFromSender,BucketSignature additionToRecipient)BucketSignature(uint256 reward1,uint256 reward2,uint256 reward3)"
        ); // Deprecated: reward1/reward2

    bytes32 constant transferToReward2SignatureHash =
        keccak256(
            "TransferFromReward3ToReward2Signature(uint32 nonce,address from,address to,uint256 amount)"
        );
    bytes32 constant transferToReward1SignatureHash =
        keccak256(
            "TransferFromReward3ToReward1Signature(uint32 nonce,address from,address to,uint256 amount)"
        );

    uint256[49] __gap_signer;

    error InvalidSignature(); // if the signature is invalid

    // constructor() EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {}
    function __Signer_init() internal initializer {
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
    }

    function _hashTransferFromReward3ToReward2Signature(
        TransferFromReward3ToReward2Signature calldata signature
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        transferToReward2SignatureHash,
                        signature.nonce,
                        signature.from,
                        signature.to,
                        signature.amount
                    )
                )
            );
    }

    function _hashTransferFromReward3ToReward1Signature(
        TransferFromReward3ToReward1Signature calldata signature
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        transferToReward1SignatureHash,
                        signature.nonce,
                        signature.from,
                        signature.to,
                        signature.amount
                    )
                )
            );
    }

    // DEPRECATED: reward1 and reward2 hashing is deprecated
    function _hash(
        AdminTransferSignature calldata signature
    ) internal view returns (bytes32) {
        // Commented out reward1/reward2 hashing logic
        /*
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        adminTransferSignatureHash,
                        signature.nonce,
                        signature.from,
                        signature.to,
                        keccak256(
                            abi.encode(
                                bucketSignatureHash,
                                signature.deductionFromSender.reward1,
                                signature.deductionFromSender.reward2,
                                signature.deductionFromSender.reward3
                            )
                        ),
                        keccak256(
                            abi.encode(
                                bucketSignatureHash,
                                signature.additionToRecipient.reward1,
                                signature.additionToRecipient.reward2,
                                signature.additionToRecipient.reward3
                            )
                        )
                    )
                )
            );
        */
        // Only reward3 should be used in new logic
        return bytes32(0);
    }

    function _verifyAdminTransferSignature(
        AdminTransferSignature calldata signature
    ) internal view returns (address) {
        bytes32 digest = _hash(signature);
        return ECDSAUpgradeable.recover(digest, signature.signature);
    }

    function _verifyTransferFromReward3ToReward2Signature(
        TransferFromReward3ToReward2Signature calldata signature
    ) internal view returns (address) {
        bytes32 digest = _hashTransferFromReward3ToReward2Signature(signature);
        return ECDSAUpgradeable.recover(digest, signature.signature);
    }

    function _verifyTransferFromReward3ToReward1Signature(
        TransferFromReward3ToReward1Signature calldata signature
    ) internal view returns (address) {
        bytes32 digest = _hashTransferFromReward3ToReward1Signature(signature);
        return ECDSAUpgradeable.recover(digest, signature.signature);
    }

    function getSignerAdminTransferSignatur(
        AdminTransferSignature calldata signature
    ) public view returns (address) {
        return _verifyAdminTransferSignature(signature);
    }

    function getSignerTransferFromReward3ToReward2Signature(
        TransferFromReward3ToReward2Signature calldata signature
    ) public view returns (address) {
        return _verifyTransferFromReward3ToReward2Signature(signature);
    }

    function getSignerTransferFromReward3ToReward1Signature(
        TransferFromReward3ToReward1Signature calldata signature
    ) public view returns (address) {
        return _verifyTransferFromReward3ToReward1Signature(signature);
    }

    /// @dev This function is used to verify signature
    ///@param signature Signature object to verify
    function isValidAdminTransferSignature(
        AdminTransferSignature calldata signature,
        address designatedSigner
    ) public view {
        if (getSignerAdminTransferSignatur(signature) != designatedSigner) {
            revert InvalidSignature();
        }
    }

    function isValidTransferFromReward3ToReward2Signature(
        TransferFromReward3ToReward2Signature calldata signature,
        address designatedSigner
    ) public view {
        if (
            getSignerTransferFromReward3ToReward2Signature(signature) !=
            designatedSigner
        ) {
            revert InvalidSignature();
        }
    }

    function isValidTransferFromReward3ToReward1Signature(
        TransferFromReward3ToReward1Signature calldata signature,
        address designatedSigner
    ) public view {
        if (
            getSignerTransferFromReward3ToReward1Signature(signature) !=
            designatedSigner
        ) {
            revert InvalidSignature();
        }
    }
}
