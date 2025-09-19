// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { KgenOFT } from "../KgenOFT.sol";

// @dev WARNING: This is for testing purposes only
contract MyOFTMock is KgenOFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate,
        address _trustedForwarder
    ) KgenOFT(_name, _symbol, _lzEndpoint, _delegate,_trustedForwarder) {}

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}
