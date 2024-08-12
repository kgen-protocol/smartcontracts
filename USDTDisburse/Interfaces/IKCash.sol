// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKCash is IERC20 {
    struct Bucket {
        uint256 reward1;
        uint256 reward2;
        uint256 reward3;
    }

    struct BucketSignature {
        uint256 reward1;
        uint256 reward2;
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

    function initialize(address _owner, address _designatedSigner) external;

    function decimals() external pure returns (uint8);

    function mint(
        address _to,
        uint256 _amount,
        Bucket calldata _bucket
    ) external;

    function bulkMint(
        address[] calldata accounts,
        uint256[] calldata amounts,
        Bucket[] calldata _bucket
    ) external;

    function bulkApprove(
        address[] calldata spenders,
        uint256[] calldata amounts
    ) external returns (bool);

    function bulkGrantRoles(bytes32 role, address[] calldata accounts) external;

    function adminTransferWithSignature(
        AdminTransferSignature calldata signature
    ) external;

    function adminTransferWithSignatureBulk(
        AdminTransferSignature[] calldata signatures
    ) external;

    function adminTransfer(
        address to,
        Bucket calldata deductionFromSender,
        Bucket calldata additionToRecipient
    ) external;

    function adminTranferBulk(
        address[] calldata to,
        Bucket[] calldata deductionFromSender,
        Bucket[] calldata additionToRecipient
    ) external;

    function transferToReward3(address to, Bucket calldata _bucket) external;

    function transferToReward3Bulk(
        address[] calldata to,
        Bucket[] calldata _bucket
    ) external;

    function transferReward3ToReward3(address to, uint256 amount) external;

    function transferReward3ToReward3Bulk(
        address[] calldata to,
        uint256[] calldata amounts
    ) external;

    function transferFromReward3ToReward1(
        TransferFromReward3ToReward1Signature calldata signature
    ) external;

    function transferFromReward3ToReward1Bulk(
        TransferFromReward3ToReward1Signature[] calldata signatures
    ) external;

    function transferFromReward3ToReward2(
        TransferFromReward3ToReward2Signature calldata signature
    ) external;

    function transferFromReward3ToReward2Bulk(
        TransferFromReward3ToReward2Signature[] calldata signatures
    ) external;

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function bulkTransfer(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external returns (bool);

    function setDesignatedSigner(address _designatedSigner) external;

    function getBalanceWithBucket(
        address _address
    ) external view returns (uint256, Bucket memory);

    function adminTransferFromReward3ToReward1(
        address to,
        uint256 amount
    ) external;

    function adminTransferFromReward3ToReward1Bulk(
        address[] calldata to,
        uint256[] calldata amounts
    ) external;

    function adminTransferFromReward3ToReward2(
        address to,
        uint256 amount
    ) external;

    function adminTransferFromReward3ToReward2Bulk(
        address[] calldata to,
        uint256[] calldata amounts
    ) external;

    function adminTransferFrom(
        address from,
        address to,
        Bucket calldata bucket
    ) external;

    function adminBurn(address from, uint256 amount, Bucket calldata _bucket) external;

    function adminBurnFrom(
        address account,
        uint256 amount,
        Bucket calldata _bucket
    ) external;
}
