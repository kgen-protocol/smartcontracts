// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
abstract contract KgenStorage{

    mapping(address => bool) public approvedToken;
    mapping(bytes32 => bool) public processed;

   /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
 uint256[50] private __kgen_gap;
}
