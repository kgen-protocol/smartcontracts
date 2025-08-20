pragma solidity ^0.8.0;
interface IKGEN {
    // Mint and burn functions
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}