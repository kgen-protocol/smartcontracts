// SPDX-License-Identifier: MIT

// ██╗  ██╗     ██████╗ █████╗ ███████╗██╗  ██╗
// ██║ ██╔╝    ██╔════╝██╔══██╗██╔════╝██║  ██║
// █████╔╝     ██║     ███████║███████╗███████║
// ██╔═██╗     ██║     ██╔══██║╚════██║██╔══██║
// ██║  ██╗    ╚██████╗██║  ██║███████║██║  ██║
// ╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./KCashSigner.sol";
import "../ERC2771Override/ERC2771Overrides.sol";
/**
 * @title KCash
 * @dev This contract represents the KCash token, which is an ERC20 token with additional functionalities.
 * It inherits from ERC20Upgradeable, ERC20BurnableUpgradeable, AccessControlUpgradeable, and KCashSigner contracts.
 */
contract KCash is
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable,
    KCashSigner,ERC2771Overrides
{
    /**
     * @dev Represents a bucket that tracks the amount of reward1, reward2, and reward3 in the KCash contract.
     */
    struct Bucket {
        uint256 reward1;
        uint256 reward2;
        uint256 reward3;
    }

    /**
     * @dev This contract defines the roles used in the KCash contract.
     * The `MINTER_ROLE` role is used to designate accounts that have the ability to mint new tokens.
     * The `ADMIN_TRANSFER_ROLE` role is used to designate accounts that have the ability to transfer tokens and bucket.
     */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_TRANSFER_ROLE =
        keccak256("ADMIN_TRANSFER_ROLE");

    /**
     * @dev The address of the designated signer for the contract.
     */
    address public designatedSigner;

    /**
     * @dev A mapping that stores the `Bucket` struct for each address.
     * The `buckets` mapping allows users to access the `Bucket` struct associated with their address.
     */
    mapping(address => Bucket) public buckets;

    /**
     * @dev A mapping to keep track of used signatures.
     * The keys of the mapping are bytes and the values are booleans.
     */
    mapping(bytes => bool) usedSignatures;
     uint256[48] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the KCashNew contract.
     * @param _owner The address of the contract owner.
     * @param _designatedSigner The address of the designated signer.
     */
    function initialize(
        address _owner,
        address _designatedSigner
    ) public initializer {
        __ERC20_init("Kratos Cash", "KCASH");
        __ERC20Burnable_init();
        __AccessControl_init();
        __Signer_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(MINTER_ROLE, _owner);
        _grantRole(ADMIN_TRANSFER_ROLE, _owner);
        designatedSigner = _designatedSigner;
    }
    function reintializer()  public reinitializer(2) {
        // add code for reintializer
    }
    /**
     * @dev Returns the decimals of the token.
     */
    function decimals() public pure override returns (uint8) {
        return 0;
    }

    /**
     * @dev Internal function to mint KCash tokens to a specified address with a given amount and bucket.
     * @param _to The address to mint tokens to.
     * @param _amount The amount of tokens to mint.
     * @param _bucket The bucket containing the rewards for the minted tokens.
     * @dev The sum of rewards in the bucket must match the specified amount.
     * @dev Updates the rewards in the recipient's bucket and mints the tokens.
     */
    function _internalMint(
        address _to,
        uint256 _amount,
        Bucket calldata _bucket
    ) private {
        require(
            _bucket.reward1 + _bucket.reward2 + _bucket.reward3 == _amount,
            "KC: amount mismatch"
        );
        Bucket storage bucket = buckets[_to];
        unchecked {
            bucket.reward1 += _bucket.reward1;
            bucket.reward2 += _bucket.reward2;
            bucket.reward3 += _bucket.reward3;
        }
        _mint(_to, _amount);
    }

    /**
     * @dev Mints new tokens and assigns them to the specified address.
     * Only the address with the MINTER_ROLE can call this function.
     * The total amount of tokens minted must match the sum of reward1, reward2, and reward3 tokens in the provided bucket.
     * @param _to The address to which the tokens will be minted.
     * @param _amount The total amount of tokens to be minted.
     * @param _bucket The bucket containing the breakdown of reward1, reward2, and reward3 tokens.
     * @dev Throws an error if the amount of tokens in the bucket does not match the total amount.
     */

    function mint(
        address _to,
        uint256 _amount,
        Bucket calldata _bucket
    ) external onlyRole(MINTER_ROLE) {
        _internalMint(_to, _amount, _bucket);
    }

    /**
     * @dev Bulk mints KCash tokens to multiple accounts with corresponding amounts and buckets.
     * @param accounts The array of addresses to mint tokens to.
     * @param amounts The array of token amounts to mint for each account.
     * @param _bucket The array of buckets for each minted token.
     * Only the address with the MINTER_ROLE can call this function.
     * The total amount of tokens minted must match the sum of reward1, reward2, and reward3 tokens in the provided bucket.
     */
    function bulkMint(
        address[] calldata accounts,
        uint256[] calldata amounts,
        Bucket[] calldata _bucket
    ) external onlyRole(MINTER_ROLE) {
        require(accounts.length == amounts.length, "KC: length mismatch");
        uint256 length = accounts.length;
        for (uint i; i < length; ) {
            _internalMint(accounts[i], amounts[i], _bucket[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Approves multiple spenders to spend specified amounts of tokens.
     * @param spenders The array of spender addresses.
     * @param amounts The array of corresponding amounts to be approved.
     * @return A boolean indicating the success of the operation.
     */
    function bulkApprove(
        address[] calldata spenders,
        uint256[] calldata amounts
    ) public returns (bool) {
        require(spenders.length == amounts.length, "KC: length mismatch");
        uint256 length = spenders.length;
        for (uint i; i < length; ) {
            address spender = spenders[i];
            uint256 amount = amounts[i];
            approve(spender, amount);
            unchecked {
                ++i;
            }
        }
        return true;
    }

    /**
     * @dev Grants a specific role to multiple accounts.
     * Can only be called by an account with the role's admin role.
     * @param role The role to grant.
     * @param accounts The array of accounts to grant the role to.
     */
    function bulkGrantRoles(
        bytes32 role,
        address[] calldata accounts
    ) public onlyRole(getRoleAdmin(role)) {
        uint256 length = accounts.length;
        for (uint i; i < length; ) {
            address account = accounts[i];
            grantRole(role, account);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Intrenal function for transfer that will dedduct from bucket (in order reward3, reward2, reward1) and then transfer the amount to recepient reward3 bucket
     * @param sender The address of the sender.
     * @param recipient The address of the recipient.
     * @param amount The amount to be transferred.
     */
    function _defaultBucketTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        Bucket storage bucketSender = buckets[sender];
        Bucket storage bucketRecipient = buckets[recipient];
        if (bucketSender.reward3 >= amount) {
            bucketSender.reward3 -= amount;
        } else if (bucketSender.reward2 + bucketSender.reward3 >= amount) {
            bucketSender.reward2 -= amount - bucketSender.reward3;
            delete bucketSender.reward3;
        } else {
            bucketSender.reward1 -=
                amount -
                bucketSender.reward2 -
                bucketSender.reward3;
            delete bucketSender.reward3;
            delete bucketSender.reward2;
        }
        bucketRecipient.reward3 += amount;
    }

    /**
     * @dev Transfers tokens from the sender's bucket to the recipient's bucket using a signature for authorization.
     * @param signature The signature containing the transfer details.
     * - `signature.nonce`: The nonce of the signature.
     * - `signature.from`: The address of the sender.
     * - `signature.to`: The address of the recipient.
     * - `signature.deductionFromSender`: The amount of tokens to deduct from the sender's bucket.
     * - `signature.additionToRecipient`: The amount of tokens to add to the recipient's bucket.
     * - `signature.signature`: The signature for authorization.
     * @notice This function requires the signature to be valid, the sender to match the message sender, and the signature to not have been used before.
     * @notice The amounts deducted from the sender's bucket and added to the recipient's bucket must match.
     */
    function adminTransferWithSignature(
        AdminTransferSignature calldata signature
    ) public {
        isValidAdminTransferSignature(signature, designatedSigner);
        require(signature.from == _msgSender() , "KC: sender mismatch");
        require(
            !usedSignatures[signature.signature],
            "KC: signature already used"
        );
        uint256 amount = signature.deductionFromSender.reward1 +
            signature.deductionFromSender.reward2 +
            signature.deductionFromSender.reward3;
        require(
            amount ==
                signature.additionToRecipient.reward1 +
                    signature.additionToRecipient.reward2 +
                    signature.additionToRecipient.reward3,
            "KC: amount mismatch"
        );
        Bucket storage bucketSender = buckets[signature.from];
        Bucket storage bucketRecipient = buckets[signature.to];
        bucketSender.reward1 -= signature.deductionFromSender.reward1;
        bucketSender.reward2 -= signature.deductionFromSender.reward2;
        bucketSender.reward3 -= signature.deductionFromSender.reward3;
        bucketRecipient.reward1 += signature.additionToRecipient.reward1;
        bucketRecipient.reward2 += signature.additionToRecipient.reward2;
        bucketRecipient.reward3 += signature.additionToRecipient.reward3;
        usedSignatures[signature.signature] = true;
        _transfer(signature.from, signature.to, amount);
    }

    /**
     * @dev Executes multiple admin transfers with signatures.
     * @param signatures The array of AdminTransferSignature structs containing the transfer details.
     */
    function adminTransferWithSignatureBulk(
        AdminTransferSignature[] calldata signatures
    ) external {
        uint256 length = signatures.length;
        for (uint i; i < length; ) {
            adminTransferWithSignature(signatures[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Transfers rewards from the sender's bucket to the recipient's bucket.
     * Only the address with the ADMIN_TRANSFER_ROLE can call this function.
     * The amount of rewards transferred must match the sum of rewards deducted from the sender's bucket
     * and added to the recipient's bucket.
     *
     * @param to The address of the recipient.
     * @param deductionFromSender The bucket containing the rewards to be deducted from the sender.
     * @param additionToRecipient The bucket containing the rewards to be added to the recipient.
     */
    function adminTransfer(
        address to,
        Bucket calldata deductionFromSender,
        Bucket calldata additionToRecipient
    ) public onlyRole(ADMIN_TRANSFER_ROLE) {
        uint256 amount = deductionFromSender.reward1 +
            deductionFromSender.reward2 +
            deductionFromSender.reward3;
        require(
            amount ==
                additionToRecipient.reward1 +
                    additionToRecipient.reward2 +
                    additionToRecipient.reward3,
            "KC: amount mismatch"
        );
        Bucket storage bucketSender = buckets[_msgSender() ];
        Bucket storage bucketRecipient = buckets[to];
        bucketSender.reward1 -= deductionFromSender.reward1;
        bucketSender.reward2 -= deductionFromSender.reward2;
        bucketSender.reward3 -= deductionFromSender.reward3;
        bucketRecipient.reward1 += additionToRecipient.reward1;
        bucketRecipient.reward2 += additionToRecipient.reward2;
        bucketRecipient.reward3 += additionToRecipient.reward3;
        _transfer(_msgSender() , to, amount);
    }

    /**
     * @dev Performs bulk admin transfers.
     * @param to The array of recipient addresses.
     * @param deductionFromSender The array of Bucket structs representing the amount to deduct from the sender.
     * @param additionToRecipient The array of Bucket structs representing the amount to add to the recipient.
     * Requirements:
     * - The length of `to`, `deductionFromSender`, and `additionToRecipient` arrays must be the same.
     * - Only the role with ADMIN_TRANSFER_ROLE can call this function.
     */
    function adminTranferBulk(
        address[] calldata to,
        Bucket[] calldata deductionFromSender,
        Bucket[] calldata additionToRecipient
    ) external onlyRole(ADMIN_TRANSFER_ROLE) {
        require(
            to.length == deductionFromSender.length,
            "KC: deductionFromSender length mismatch"
        );
        require(
            to.length == additionToRecipient.length,
            "KC: additionToRecipient length mismatch"
        );
        uint256 length = to.length;
        for (uint i; i < length; ) {
            adminTransfer(
                to[i],
                deductionFromSender[i],
                additionToRecipient[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Transfers tokens to the reward3 bucket of the recipient address.
     * @param to The address to transfer the tokens to.
     * @param _bucket The bucket containing the token amounts to transfer.
     */
    function transferToReward3(address to, Bucket calldata _bucket) public {
        uint256 amount = _bucket.reward1 + _bucket.reward2 + _bucket.reward3;
        Bucket storage bucketSender = buckets[_msgSender() ];
        Bucket storage bucketRecipient = buckets[to];
        if (amount == _bucket.reward1) {
            bucketSender.reward1 -= _bucket.reward1;
        } else {
            if (_bucket.reward1 != 0) {
                bucketSender.reward1 -= _bucket.reward1;
            }
            if (_bucket.reward2 != 0) {
                bucketSender.reward2 -= _bucket.reward2;
            }
            if (_bucket.reward3 != 0) {
                bucketSender.reward3 -= _bucket.reward3;
            }
        }
        bucketRecipient.reward3 += amount;
        _transfer(_msgSender() , to, amount);
    }

    /**
     * @dev Transfers tokens to multiple addresses and assigns them to corresponding reward3 buckets.
     * @param to The array of addresses to transfer tokens to.
     * @param _bucket The array of reward3 buckets to assign to each address.
     * Requirements:
     * - The length of `to` array must be equal to the length of `_bucket` array.
     */
    function transferToReward3Bulk(
        address[] calldata to,
        Bucket[] calldata _bucket
    ) external {
        require(to.length == _bucket.length, "KC: length mismatch");
        uint256 length = to.length;
        for (uint i; i < length; ) {
            transferToReward3(to[i], _bucket[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Transfers a specified amount of reward3 tokens from the sender's bucket to the recipient's bucket.
     * Emits a Transfer event.
     *
     * Requirements:
     * - The sender must have a sufficient balance of reward3 tokens in their bucket.
     *
     * @param to The address of the recipient.
     * @param amount The amount of reward3 tokens to transfer.
     */
    function transferReward3ToReward3(address to, uint256 amount) public {
        Bucket storage bucketSender = buckets[_msgSender() ];
        Bucket storage bucketRecipient = buckets[to];

        bucketSender.reward3 -= amount;
        bucketRecipient.reward3 += amount;

        _transfer(_msgSender() , to, amount);
    }

    /**
     * @dev Transfers multiple amounts of Reward3 tokens to multiple addresses.
     * @param to An array of addresses to transfer the tokens to.
     * @param amounts An array of amounts to be transferred to each address.
     * Requirements:
     * - The `to` and `amounts` arrays must have the same length.
     * - The caller must have sufficient balance of Reward3 tokens.
     */
    function transferReward3ToReward3Bulk(
        address[] calldata to,
        uint256[] calldata amounts
    ) external {
        require(to.length == amounts.length, "KC: length mismatch");
        uint256 length = to.length;
        for (uint i; i < length; ) {
            transferReward3ToReward3(to[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Transfers an amount from the reward3 bucket to the reward1 bucket.
     * @param signature The signature containing the transfer details.
     */
    function transferFromReward3ToReward1(
        TransferFromReward3ToReward1Signature calldata signature
    ) public {
        isValidTransferFromReward3ToReward1Signature(
            signature,
            designatedSigner
        );
        require(
            !usedSignatures[signature.signature],
            "KC: signature already used"
        );
        require(signature.from == _msgSender() , "KC: sender mismatch");
        Bucket storage bucketSender = buckets[signature.from];
        Bucket storage bucketRecipient = buckets[signature.to];
        bucketSender.reward3 -= signature.amount;
        bucketRecipient.reward1 += signature.amount;
        usedSignatures[signature.signature] = true;
        _transfer(signature.from, signature.to, signature.amount);
    }

    /**
     * @dev Transfers tokens from Reward3 to Reward1 in bulk.
     * @param signatures The array of TransferFromReward3ToReward1Signature structs containing the transfer details.
     */
    function transferFromReward3ToReward1Bulk(
        TransferFromReward3ToReward1Signature[] calldata signatures
    ) external {
        uint256 length = signatures.length;
        for (uint i; i < length; ) {
            transferFromReward3ToReward1(signatures[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Transfers an amount from the reward3 balance of the sender to the reward2 balance of the recipient.
     * @param signature The transfer signature containing the necessary information.
     */
    function transferFromReward3ToReward2(
        TransferFromReward3ToReward2Signature calldata signature
    ) public {
        isValidTransferFromReward3ToReward2Signature(
            signature,
            designatedSigner
        );
        require(
            !usedSignatures[signature.signature],
            "KC: signature already used"
        );
        require(signature.from == _msgSender() , "KC: sender mismatch");
        Bucket storage bucketSender = buckets[signature.from];
        Bucket storage bucketRecipient = buckets[signature.to];
        bucketSender.reward3 -= signature.amount;
        bucketRecipient.reward2 += signature.amount;

        usedSignatures[signature.signature] = true;
        _transfer(signature.from, signature.to, signature.amount);
    }

    /**
     * @dev Transfers tokens from Reward3 to Reward2 in bulk.
     * @param signatures The array of TransferFromReward3ToReward2Signature structs containing the transfer details.
     */
    function transferFromReward3ToReward2Bulk(
        TransferFromReward3ToReward2Signature[] calldata signatures
    ) external {
        uint256 length = signatures.length;
        for (uint i; i < length; ) {
            transferFromReward3ToReward2(signatures[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Transfers a specified amount of tokens from the caller's account to the recipient's account.
     * Emits a {Transfer} event.
     *
     * Requirements:
     * - `to` cannot be the zero address.
     * - The caller must have a balance of at least `amount`.
     *
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        _defaultBucketTransfer(_msgSender() , to, amount);
        return super.transfer(to, amount);
    }

    /**
     * @dev Transfers a specified amount of tokens from one address to another.
     * Emits a {Transfer} event.
     *
     * Requirements:
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - The caller must have allowance for `from`'s tokens of at least `amount`.
     *
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        _defaultBucketTransfer(from, to, amount);
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Performs bulk transfer of KC tokens to multiple accounts.
     * @param accounts The array of recipient addresses.
     * @param amounts The array of corresponding transfer amounts.
     * @return A boolean indicating the success of the bulk transfer operation.
     */
    function bulkTransfer(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) public returns (bool) {
        require(accounts.length == amounts.length, "KC: length mismatch");
        uint256 length = accounts.length;
        for (uint i; i < length; ) {
            address account = accounts[i];
            uint256 amount = amounts[i];
            transfer(account, amount);
            unchecked {
                ++i;
            }
        }
        return true;
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
     * @dev Retrieves the balance and bucket information for a given address.
     * @param _address The address for which to retrieve the balance and bucket information.
     * @return The balance of the address and the corresponding bucket information.
     */
    function getBalanceWithBucket(
        address _address
    ) public view returns (uint256, Bucket memory) {
        return (balanceOf(_address), buckets[_address]);
    }

    /**
     * @dev Internal function to transfer an amount from the reward3 bucket of the sender to the reward1 bucket of the recipient.
     * @param to The address of the recipient.
     * @param amount The amount to transfer.
     */
    function _adminTransferFromReward3ToReward1(
        address to,
        uint256 amount
    ) internal {
        Bucket storage bucketSender = buckets[_msgSender() ];
        Bucket storage bucketRecipient = buckets[to];
        bucketSender.reward3 -= amount;
        bucketRecipient.reward1 += amount;
        _transfer(_msgSender() , to, amount);
    }

    /**
     * @dev Transfers an amount from Reward3 to Reward1.
     * Only the address with the ADMIN_TRANSFER_ROLE can call this function.
     * 
     * @param to The address to transfer the amount to.
     * @param amount The amount to transfer.
     */
    function adminTransferFromReward3ToReward1(
        address to,
        uint256 amount
    ) external onlyRole(ADMIN_TRANSFER_ROLE) {
        _adminTransferFromReward3ToReward1(to, amount);
    }

    /**
     * @dev Transfers tokens from the reward3 pool to the reward1 pool in bulk.
     * Only the address with the ADMIN_TRANSFER_ROLE can call this function.
     * 
     * @param to The array of recipient addresses.
     * @param amounts The array of token amounts to be transferred.
     * 
     * Requirements:
     * - The length of the `to` array must be equal to the length of the `amounts` array.
     */
    function adminTransferFromReward3ToReward1Bulk(
        address[] calldata to,
        uint256[] calldata amounts
    ) external onlyRole(ADMIN_TRANSFER_ROLE) {
        require(to.length == amounts.length, "KC: length mismatch");
        uint256 length = to.length;
        for (uint i; i < length; ) {
            _adminTransferFromReward3ToReward1(to[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }


    /**
     * @dev Internal function to transfer tokens from reward3 to reward2.
     * @param to The address to transfer the tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _adminTransferFromReward3ToReward2(
        address to,
        uint256 amount
    ) internal {
        Bucket storage bucketSender = buckets[_msgSender()];
        Bucket storage bucketRecipient = buckets[to];
        bucketSender.reward3 -= amount;
        bucketRecipient.reward2 += amount;
        _transfer(_msgSender() , to, amount);
    }

    /**
     * @dev Transfers a specified amount from the reward3 balance to the reward2 balance.
     * Only the address with the ADMIN_TRANSFER_ROLE can call this function.
     * 
     * @param to The address to transfer the funds to.
     * @param amount The amount of funds to transfer.
     */
    function adminTransferFromReward3ToReward2(
        address to,
        uint256 amount
    ) external onlyRole(ADMIN_TRANSFER_ROLE) {
        _adminTransferFromReward3ToReward2(to, amount);
    }

    /**
     * @dev Transfers tokens from Reward3 to Reward2 in bulk for multiple addresses.
     * Only the admin with the ADMIN_TRANSFER_ROLE can call this function.
     * 
     * @param to The array of addresses to transfer tokens to.
     * @param amounts The array of token amounts to transfer.
     * 
     * Requirements:
     * - The length of `to` array must be equal to the length of `amounts` array.
     */
    function adminTransferFromReward3ToReward2Bulk(
        address[] calldata to,
        uint256[] calldata amounts
    ) external onlyRole(ADMIN_TRANSFER_ROLE) {
        require(to.length == amounts.length, "KC: length mismatch");
        uint256 length = to.length;
        for (uint i; i < length; ) {
            _adminTransferFromReward3ToReward2(to[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Transfers tokens from one address to another, while updating the reward buckets.
     * Only the admin role can call this function.
     * 
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param bucket The reward bucket containing the reward amounts.
     */
    function adminTransferFrom(
        address from,
        address to,
        Bucket calldata bucket
    ) external onlyRole(ADMIN_TRANSFER_ROLE) {
        uint256 amount = bucket.reward1 + bucket.reward2 + bucket.reward3;
        require(
            amount <= balanceOf(from),
            "KC: transfer amount exceeds balance"
        );
        Bucket storage bucketSender = buckets[from];
        Bucket storage bucketRecipient = buckets[to];
        bucketSender.reward1 -= bucket.reward1;
        bucketSender.reward2 -= bucket.reward2;
        bucketSender.reward3 -= bucket.reward3;
        bucketRecipient.reward1 += bucket.reward1;
        bucketRecipient.reward2 += bucket.reward2;
        bucketRecipient.reward3 += bucket.reward3;
        super.transferFrom(from, to, amount); 
    }

    function burn(uint256 amount) public override {
        revert("KC: burn disabled");
    }

    function burnFrom(address account, uint256 amount) public override {
        revert("KC: burn disabled");
    }


    
}
