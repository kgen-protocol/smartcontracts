// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
contract ERC2771Override is ERC2771ContextUpgradeable {
    mapping(address => bool) private _trustedForwarders;

    event ForwarderAdded(address indexed trustedForwarder);
    event ForwarderRemoved(address indexed trustedForwarder);

    constructor(address trustedForwarder_)ERC2771ContextUpgradeable(trustedForwarder_) { }

    function initialize(address trustedForwarder) external initializer {
        _trustedForwarders[trustedForwarder] = true;
        emit ForwarderAdded(trustedForwarder);
    }

    /**
     * @dev Checks if an address is a trusted forwarder.
     * Overrides ERC2771Context's function.
     * @param forwarder The address to check.
     * @return A boolean indicating whether the address is a trusted forwarder.
     */
    function isTrustedForwarder(address forwarder) public view override returns (bool) {
        return _trustedForwarders[forwarder];
    }

    /**
     * @dev Adds an address to the list of trusted forwarders.
     * Only the contract owner can call this function.
     * @param trustedForwarder The address to add as a trusted forwarder.
     */
    function addTrustedForwarder(address trustedForwarder) external  onlyRole(DEFAULT_ADMIN_ROLE)  {
        _trustedForwarders[trustedForwarder] = true;
        emit ForwarderAdded(trustedForwarder);
    }

    /**
     * @dev Removes an address from the list of trusted forwarders.
     * Only the contract owner can call this function.
     * @param trustedForwarder The address to remove as a trusted forwarder.
     */
    function removeTrustedForwarder(address trustedForwarder) external  onlyRole(DEFAULT_ADMIN_ROLE)  {
        _trustedForwarders[trustedForwarder] = false;
        emit ForwarderRemoved(trustedForwarder);
    }
}
