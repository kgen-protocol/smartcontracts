pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract FailingERC20 is ERC20 {

    constructor() ERC20("Fail", "FAIL") {}
    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }
     function transferFrom(address , address , uint256 ) public pure  override virtual returns (bool) {
       
        return false;
    }
}

