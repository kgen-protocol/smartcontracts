// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @dev Storage layout shared by every implementation behind the proxy.
abstract contract KgenStorage {
    bytes32 public constant ADMIN_ROLE = keccak256("KGEN_STAKING_ADMIN_ROLE");
    using ECDSA for bytes32;

    /* -------------------- per-stake & APY data structures ------------------- */
    struct StakeDetails {
        uint256 stakeId;        // unique per-user
        uint256 amount;         // principal staked (token decimals)
        uint256 startTime;      // unix seconds
        uint256 duration;       // lock period in days
        uint256 apy;            // annual % × 10_000  (1.00 % ⇒ 10_000)
        uint256 totalClaimed;   // reward already paid out / harvested
        uint256 lastHarvested;  // last harvest timestamp
        address token;
    }

    struct APYRange {
        uint256 minAmount;      // inclusive lower bound
        uint256 maxAmount;      // inclusive upper bound
        uint256 apy;            // percent × 10_000
        uint256 duration;       // days
    }

    uint256 public constant HARVEST_TIME = 1 minutes;
    enum ActionType { Stake, Harvest, Claim, Unstake, Renew }

    // APY brackets for each lock duration
    mapping(uint256 => APYRange[]) public apyRanges;

    // user => stakeId => stake data
    mapping(address => mapping(uint256 => StakeDetails)) public userStakes;

    // user => latest stake ID used
    mapping(address => uint256) public userStakeCount;

    // user => currently active stake count
    mapping(address => uint256) public activeStakeCount;

    // token whitelist for staking
    mapping(address =>bool) public whitelistedToken;
    address public stakingToken;

    // meta-tx tracking
    mapping(address => uint256) public nonce;
    mapping(address => bool) public trustedForwarder;

    uint256[50] private __gap; // storage gap for upgrades
}
