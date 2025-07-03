// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./ERC2771Context/ERC2771ContextUpgradable.sol";
import "./proxy/storage/KgenStorage.sol";

error AlreadyWhitelisted();
error NotWhitelisted();
error InvalidReceiver();
error TransferFailed();
error TokenNotWhitelisted();
error AmountZero();
error InvalidAdminSignature();
error InvalidDuration();
error NoAPY();
error HarvestTooSoon();
error NoRewards();
error StakeNotFound();
error NotMatured();
error APYRangeNotFound();
error CanNotUnstakeAfterMaturity();

contract KgenStaking is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, KgenStorage, ERC2771ContextUpgradable {
    event Staked(address indexed user, address indexed token, uint256 stakeId, uint256 amount, uint256 duration, uint256 apy);
    event Harvested(address indexed user, uint256 indexed stakeId, uint256 reward, uint256 timestamp, uint256 apy);
    event Claimed(address indexed user, uint256 indexed stakeId, uint256 principal, uint256 totalClaimed, uint256 rewards, uint256 timestamp, uint256 apy);
    event Unstaked(address indexed user, uint256 stakeId, uint256 amount, uint256 unstakeTime, uint256 lockEndTime);

    /* -------------------------------------------------------------------------- */
    /*                                   Init                                     */
    /* -------------------------------------------------------------------------- */
    function initialize() public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
    }

    /* -------------------------------------------------------------------------- */
    /*                               Math Helpers                                 */
    /* -------------------------------------------------------------------------- */
    function _earned(uint256 start, uint256 apy, uint256 amount, uint256 nowOrEnd) internal pure returns (uint256) {
        if (nowOrEnd <= start) return 0;
        return amount * apy * (nowOrEnd - start) / (365 days * 100) / 10_000;
    }

    /* -------------------------------------------------------------------------- */
    /*                              APY Management                                */
    /* -------------------------------------------------------------------------- */
    function addAPYRange(uint256 duration, uint256 min, uint256 max, uint256 apy) external onlyRole(ADMIN_ROLE) {
        apyRanges[duration].push(APYRange(min, max, apy, duration));
    }

    function updateAPYRangeByBounds(uint256 duration, uint256 oldMin, uint256 oldMax, uint256 newMin, uint256 newMax, uint256 newApy) external onlyRole(ADMIN_ROLE) {
        APYRange[] storage arr = apyRanges[duration];
        for (uint256 i; i < arr.length; ++i) {
            if (arr[i].minAmount == oldMin && arr[i].maxAmount == oldMax) {
                arr[i] = APYRange(newMin, newMax, newApy, duration);
                return;
            }
        }
        revert APYRangeNotFound();
    }

    /* -------------------------------------------------------------------------- */
    /*                               Whitelist                                    */
    /* -------------------------------------------------------------------------- */
    function addWhitelistedToken(bool status, address token) external onlyRole(ADMIN_ROLE) {
        whitelistedToken[token] = status;
    }

    /* -------------------------------------------------------------------------- */
    /*                         Signature Verification                             */
    /* -------------------------------------------------------------------------- */
    /**
     * Signature hash: keccak256(user, token, value, nonce, address(this), chainId, action)
     */
    function verifySignature(
        address user,
        address token,
        uint256 value,
        uint256 userNonce,
        ActionType action,
        bytes memory sig
    ) public view returns (bool) {
        bytes32 raw = keccak256(abi.encode(user, token, value, userNonce, address(this), block.chainid, action));
        return hasRole(ADMIN_ROLE, ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(raw), sig));
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Staking                                    */
    /* -------------------------------------------------------------------------- */
    function addStake(uint256 amount, uint256 duration, address token, bytes memory sig) external nonReentrant {
        if (!whitelistedToken[token]) revert TokenNotWhitelisted();
        if (amount == 0) revert AmountZero();
        if (!verifySignature(_msgSender(), token, amount, nonce[_msgSender()], ActionType.Stake, sig)) revert InvalidAdminSignature();
      

        APYRange[] memory ranges = apyRanges[duration];
        if (ranges.length == 0) revert InvalidDuration();
        uint256 apy;
        for (uint256 i; i < ranges.length; ++i) {
            if (amount >= ranges[i].minAmount && amount <= ranges[i].maxAmount) { apy = ranges[i].apy; break; }
        }
        if (apy == 0) revert NoAPY();

        if (!IERC20(token).transferFrom(_msgSender(), address(this), amount)) revert TransferFailed();

        uint256 id = ++userStakeCount[_msgSender()];
        activeStakeCount[_msgSender()]++;
        userStakes[_msgSender()][id] = StakeDetails(id, amount, block.timestamp, duration, apy, 0, block.timestamp, token);
        nonce[_msgSender()]++;
        emit Staked(_msgSender(), token, id, amount, duration, apy);
    }

    function harvestStake(address token, uint256 id, bytes memory sig) external nonReentrant {
        if (!whitelistedToken[token]) revert TokenNotWhitelisted();
        if (!verifySignature(_msgSender(), token, id, nonce[_msgSender()], ActionType.Harvest, sig)) revert InvalidAdminSignature();
        StakeDetails storage s = userStakes[_msgSender()][id];
        if (s.stakeId == 0) revert StakeNotFound();
        if (block.timestamp - s.lastHarvested < HARVEST_TIME) revert HarvestTooSoon();
        if(token != s.token) revert TokenNotWhitelisted();
        uint256 end = s.startTime + (s.duration * 1 days);
        uint256 ts  = block.timestamp > end ? end : block.timestamp;
        uint256 earned = _earned(s.startTime, s.apy, s.amount, ts);
        uint256 reward = earned > s.totalClaimed ? earned - s.totalClaimed : 0;
        if (reward == 0) revert NoRewards();

        s.totalClaimed += reward;
        s.lastHarvested = ts;
        if (!IERC20(token).transfer(_msgSender(), reward)) revert TransferFailed();
        nonce[_msgSender()]++;
        emit Harvested(_msgSender(), id, reward, ts, s.apy);
    }

    function claimStake(address token, uint256 id, bytes memory sig) external nonReentrant {
        if (!whitelistedToken[token]) revert TokenNotWhitelisted();
        if (!verifySignature(_msgSender(), token, id, nonce[_msgSender()], ActionType.Claim, sig)) revert InvalidAdminSignature();
        StakeDetails storage s = userStakes[_msgSender()][id];
        if (s.stakeId == 0) revert StakeNotFound();
        if (s.token != token) revert TokenNotWhitelisted();

        uint256 end = s.startTime + (s.duration * 1 days);
        if (block.timestamp < end) revert NotMatured();
        uint256 totalEarned = _earned(s.startTime, s.apy, s.amount, end);
        uint256 reward      = totalEarned > s.totalClaimed ? totalEarned - s.totalClaimed : 0;

        if (!IERC20(token).transfer(_msgSender(), s.amount + reward)) revert TransferFailed();
        emit Claimed(_msgSender(), id, s.amount, s.amount + reward, reward, block.timestamp, s.apy);

        delete userStakes[_msgSender()][id];
        activeStakeCount[_msgSender()]--;
        nonce[_msgSender()]++;
    }

    function unstake(address token, uint256 id, bytes memory sig) external nonReentrant {
        if (!whitelistedToken[token]) revert TokenNotWhitelisted();
        if (!verifySignature(_msgSender(), token, id, nonce[_msgSender()], ActionType.Unstake, sig)) revert InvalidAdminSignature();
        StakeDetails storage s = userStakes[_msgSender()][id];
        if (s.stakeId == 0) revert StakeNotFound();
        if (s.token != token) revert TokenNotWhitelisted();

        uint256 lockEnd = s.startTime + (s.duration * 1 days);
        if (block.timestamp > lockEnd) revert CanNotUnstakeAfterMaturity();

        uint256 refund = s.amount > s.totalClaimed ? s.amount - s.totalClaimed : 0;
        if (!IERC20(token).transfer(_msgSender(), refund)) revert TransferFailed();

        emit Unstaked(_msgSender(), id, refund, block.timestamp, lockEnd);
        delete userStakes[_msgSender()][id];
        activeStakeCount[_msgSender()]--;
        nonce[_msgSender()]++;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Auto-renew (admin)                             */
    /* -------------------------------------------------------------------------- */
    function autoRenewStake(address user, uint256 id) external onlyRole(ADMIN_ROLE) {
        StakeDetails storage s = userStakes[user][id];
        if (s.stakeId == 0) revert StakeNotFound();

        uint256 end = s.startTime + (s.duration * 1 days);
        if (block.timestamp < end) revert NotMatured();

        uint256 totalEarned = _earned(s.startTime, s.apy, s.amount, end);
        uint256 reinvest    = totalEarned - s.totalClaimed;
        uint256 newId       = ++userStakeCount[user];
        uint256 newStart    = block.timestamp - (block.timestamp % 1 days) + (s.startTime % 1 days);

        userStakes[user][newId] = StakeDetails({
            stakeId: newId,
            amount:  s.amount + reinvest,
            startTime: newStart,
            duration: s.duration,
            apy:      s.apy,
            totalClaimed: 0,
            lastHarvested: newStart,
            token:    s.token
        });

        emit Staked(user, s.token, newId, s.amount + reinvest, s.duration, s.apy);
        delete userStakes[user][id];
    }

    /* -------------------------------------------------------------------------- */
    /*                        Trusted Forwarder Management                        */
    /* -------------------------------------------------------------------------- */
    function setTrustedForwarder(address fwd, bool trusted) external onlyRole(DEFAULT_ADMIN_ROLE) {
        trustedForwarder[fwd] = trusted;
    }

    function isTrustedForwarder(address fwd) public view override returns (bool) {
        return trustedForwarder[fwd];
    }

    /* -------------------------------------------------------------------------- */
    /*                        Context Overrides (ERC-2771)                        */
    /* -------------------------------------------------------------------------- */
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradable) returns (address) {
        return ERC2771ContextUpgradable._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradable) returns (bytes calldata) {
        return ERC2771ContextUpgradable._msgData();
    }

    function _contextSuffixLength() internal view override(ContextUpgradeable, ERC2771ContextUpgradable) returns (uint256) {
        return ERC2771ContextUpgradable._contextSuffixLength();
    }
}