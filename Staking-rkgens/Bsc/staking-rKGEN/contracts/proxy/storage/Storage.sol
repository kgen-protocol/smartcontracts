// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
abstract contract KgenStorage{
        bytes32 public constant ADMIN_ROLE = keccak256("KGEN_STAKING_ADMIN_ROLE");
   using ECDSA for bytes32;
    struct StakeDetails {
        uint256 stakeId;
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        uint256 apy;
        uint256 totalClaimed;
        uint256 lastHarvested;
    }

    struct APYRange {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 apy;
        uint256 duration;
    }
    // uint256 public constant HARVEST_TIME = 5 * 60;
    uint256 public constant HARVEST_TIME = 1 * 60;
    enum ActionType { Stake, Harvest, Claim, Unstake, Renew }
    mapping(address => mapping(uint256 => APYRange[])) public apyRanges;
    mapping(address => mapping(address => StakeDetails[])) public userTokenStakes;
    mapping(address => mapping(address => uint256)) public userStakeCount;
    mapping(address => mapping(address => uint256)) public activeStakeCount;
    mapping(address => bool) public whitelistedToken;
    mapping (address=>uint256) public nonce;
    mapping (address => bool) public trustedForwarder;
    uint256[50] private __gap;
}