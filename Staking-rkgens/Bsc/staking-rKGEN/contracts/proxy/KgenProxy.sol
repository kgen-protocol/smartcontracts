// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
contract KgenStakingProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address crAdmin,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, crAdmin, _data) {}
}
