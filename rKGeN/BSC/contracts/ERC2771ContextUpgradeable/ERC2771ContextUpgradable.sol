// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract ERC2771ContextUpgradeable is
    Initializable,
    ContextUpgradeable
{
    function isTrustedForwarder(
        address forwarder
    ) public view virtual returns (bool) {}

    /**
     * @dev Override for `msg.sender`. Defaults to the original `msg.sender` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (
            isTrustedForwarder(msg.sender) &&
            calldataLength >= contextSuffixLength
        ) {
            return
                address(
                    bytes20(msg.data[calldataLength - contextSuffixLength:])
                );
        } else {
            return super._msgSender();
        }
    }

    /**
     * @dev Override for `msg.data`. Defaults to the original `msg.data` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgData()
        internal
        view
        virtual
        override
        returns (bytes calldata)
    {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (
            isTrustedForwarder(msg.sender) &&
            calldataLength >= contextSuffixLength
        ) {
            return msg.data[:calldataLength - contextSuffixLength];
        } else {
            return super._msgData();
        }
    }

    /**
     * @dev ERC-2771 specifies the context as being a single address (20 bytes).
     */
    function _contextSuffixLength()
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return 20;
    }
}
