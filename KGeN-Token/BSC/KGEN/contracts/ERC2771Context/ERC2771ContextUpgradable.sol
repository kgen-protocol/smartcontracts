// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/Context.sol";

abstract contract ERC2771Context is Context {
    /// @dev Return true if `forwarder` is allowed to forward meta-txs.
    function isTrustedForwarder(address forwarder) public view virtual returns (bool);

    /**
     * @dev Override for `msg.sender`. If called via a trusted forwarder and
     * calldata is long enough, extract the real sender from the last 20 bytes.
     */
    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
        } else {
            return super._msgSender();
        }
    }

    /**
     * @dev Override for `msg.data`. If called via a trusted forwarder and
     * calldata is long enough, strip the last 20 bytes (the appended sender).
     */
    function _msgData() internal view virtual override returns (bytes calldata) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return msg.data[:calldataLength - contextSuffixLength];
        } else {
            return super._msgData();
        }
    }

    /// @dev ERC-2771 context is a single address (20 bytes).
    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return 20;
    }
}
