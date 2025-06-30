pragma solidity ^0.8.20;
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./storage/kgenStorage.sol";
contract KgenAdapterProxy is  TransparentUpgradeableProxy,KgenStorage {
    constructor(
        address _logic,
        address crAdmin,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, crAdmin, _data) {}
}
