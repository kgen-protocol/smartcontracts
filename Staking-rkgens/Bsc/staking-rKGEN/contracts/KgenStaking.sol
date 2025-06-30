// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "hardhat/console.sol";
import "./proxy/storage/Storage.sol";
import "./ERC2771Context/ERC2771ContextUpgradable.sol";
/* -------------------------------------------------------------------------- */
/*                                  Errors                                    */
/* -------------------------------------------------------------------------- */
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
contract KgenStaking is
   Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    KgenStorage,
    ERC2771ContextUpgradable
{
    event Staked(
        address indexed user,
        address indexed token,
        uint256 stakeId,
        uint256 amount,
        uint256 duration,
        uint256 apy
    );
    event Harvested(
        address indexed user,
        uint256 indexed stakeId,
        uint256 reward,
        uint256 timestamp,
        uint256 apy
    );
    event Claimed(
        address indexed user,
        uint256 indexed stakeId,
        uint256 stakedAmount,
        uint256 totalClaimed,
        uint256 rewards,
        uint256 timestamp,
        uint256 apy
    );
  event Unstaked(
        address indexed user,
        address indexed token,
        uint256 stakeId,
        uint256 amount,
        uint256 unstakeTime,
        uint256 lockEndTime
    );

    /* -------------------------------------------------------------------------- */
    /*                                 Initialize                                 */
    /* -------------------------------------------------------------------------- */

    function initialize() public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
    }

    /* -------------------------------------------------------------------------- */
    /*                              Admin Functions                               */
    /* -------------------------------------------------------------------------- */

    function addAPYRange(
        address token,
        uint256 duration,
        uint256 min,
        uint256 max,
        uint256 apy
    ) external onlyRole(ADMIN_ROLE) {
        apyRanges[token][duration].push(APYRange(min, max, apy, duration));
    }

   
    function updateAPYRangeByBounds(
        address token,
        uint256 duration,
        uint256 oldMin,
        uint256 oldMax,
        uint256 newMin,
        uint256 newMax,
        uint256 newApy
    ) external onlyRole(ADMIN_ROLE) {
        APYRange[] storage ranges = apyRanges[token][duration];
        for (uint256 i = 0; i < ranges.length; i++) {
            if (
                ranges[i].minAmount == oldMin && ranges[i].maxAmount == oldMax
            ) {
                ranges[i] = APYRange(newMin, newMax, newApy, duration);
                return;
            }
        }
        revert APYRangeNotFound();
    }

    function verifySignature(
        address user,
        address token,
        uint256 amountOrStakeId,
        uint256 userNonce,
        ActionType action,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 rawHash = keccak256(
            abi.encode(
                user,
                token,
                amountOrStakeId,
                userNonce,
                address(this),
                action
            )
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(rawHash);
        address recovered = ECDSA.recover(ethHash, signature);
        return hasRole(ADMIN_ROLE, recovered);
    }

    function addWhitelistedToken(address token) external onlyRole(ADMIN_ROLE) {
        if (whitelistedToken[token]) revert AlreadyWhitelisted();
        whitelistedToken[token] = true;
    }

    function removeWhitelistedToken(
        address token
    ) external onlyRole(ADMIN_ROLE) {
        if (!whitelistedToken[token]) revert NotWhitelisted();
        whitelistedToken[token] = false;
    }

    function adminWithdrawToken(
        address token,
        address receiver,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        if (receiver == address(0)) revert InvalidReceiver();
        bool success = IERC20(token).transfer(receiver, amount);
        if (!success) revert TransferFailed();
    }

    /* -------------------------------------------------------------------------- */
    /*                               User Actions                                 */
    /* -------------------------------------------------------------------------- */

    function addStake(
        address token,
        uint256 amount,
        uint256 duration,
        bytes memory adminSignature
    ) external nonReentrant {
        if (!whitelistedToken[token]) revert TokenNotWhitelisted();
        if (amount == 0) revert AmountZero();
        if (
            !verifySignature(
                _msgSender(),
                token,
                amount,
                nonce[_msgSender()],
                ActionType.Stake,
                adminSignature
            )
        ) revert InvalidAdminSignature();

        APYRange[] memory ranges = apyRanges[token][duration];
        if (ranges.length == 0) revert InvalidDuration();

        uint256 applicableApy = 0;
        for (uint i = 0; i < ranges.length; i++) {
            if (
                amount >= ranges[i].minAmount && amount <= ranges[i].maxAmount
            ) {
                applicableApy = ranges[i].apy;
                break;
            }
        }
        if (applicableApy == 0) revert NoAPY();

        bool success = IERC20(token).transferFrom(
            _msgSender(),
            address(this),
            amount
        );
        if (!success) revert TransferFailed();

        uint256 stakeId = ++userStakeCount[_msgSender()][token];
        activeStakeCount[_msgSender()][token]++;

    StakeDetails memory stake = StakeDetails({
            stakeId: stakeId,
            amount: amount,
            startTime: block.timestamp,
            duration: duration,
            apy: applicableApy,
            totalClaimed: 0,
            lastHarvested: block.timestamp
        });

        userTokenStakes[_msgSender()][token].push(stake);
        nonce[_msgSender()]++;
        emit Staked(
            _msgSender(),
            token,
            stakeId,
            amount,
            duration,
            applicableApy
        );
    }

    function harvestStake(
        address token,
        uint256 stakeId,
        bytes memory adminSignature
    ) external nonReentrant {
        if (!whitelistedToken[token]) revert TokenNotWhitelisted();
        if (
            !verifySignature(
                _msgSender(),
                token,
                stakeId,
                nonce[_msgSender()],
                ActionType.Harvest,
                adminSignature
            )
        ) revert InvalidAdminSignature();

        StakeDetails[] storage stakes = userTokenStakes[_msgSender()][token];

        for (uint i = 0; i < stakes.length; i++) {
            if (stakes[i].stakeId == stakeId) {
                StakeDetails storage stake = stakes[i];
                if (block.timestamp - stake.lastHarvested < HARVEST_TIME)
                    revert HarvestTooSoon();

                uint256 endTime = stake.startTime + (stake.duration * 1 days);
                uint256 currentTime = block.timestamp > endTime
                    ? endTime
                    : block.timestamp;

                uint256 earned = (stake.amount *
                    stake.apy *
                    (currentTime - stake.startTime)) /
                    (365 * 86400 * 100 * 10000);
                uint256 reward = earned > stake.totalClaimed
                    ? earned - stake.totalClaimed
                    : 0;

                if (reward == 0) revert NoRewards();

                stake.totalClaimed += reward;
                stake.lastHarvested = currentTime;

                bool success = IERC20(token).transfer(_msgSender(), reward);
                if (!success) revert TransferFailed();

                emit Harvested(
                    _msgSender(),
                    stakeId,
                    reward,
                    currentTime,
                    stake.apy
                );
                nonce[_msgSender()]++;
                return;
            }
        }
        revert StakeNotFound();
    }

    function claimStake(
        address token,
        uint256 stakeId,
        bytes memory adminSignature
    ) external nonReentrant {
        if (!whitelistedToken[token]) revert TokenNotWhitelisted();
        if (
            !verifySignature(
                _msgSender(),
                token,
                stakeId,
                nonce[_msgSender()],
                ActionType.Claim,
                adminSignature
            )
        ) revert InvalidAdminSignature();

        StakeDetails[] storage stakes = userTokenStakes[_msgSender()][token];
        for (uint i = 0; i < stakes.length; i++) {
            if (stakes[i].stakeId == stakeId) {
                StakeDetails memory stake = stakes[i];
                uint256 endTime = stake.startTime + (stake.duration * 1 days);
                console.log(endTime, block.timestamp);
                if (block.timestamp < endTime) revert NotMatured();

                uint256 totalEarned = (stake.amount *
                    stake.apy *
                    (endTime - stake.startTime)) / (365 * 86400 * 100 * 10000);
                uint256 reward = totalEarned > stake.totalClaimed
                    ? totalEarned - stake.totalClaimed
                    : 0;

                bool success = IERC20(token).transfer(
                    _msgSender(),
                    stake.amount + reward
                );
                if (!success) revert TransferFailed();
                emit Claimed(
                    _msgSender(),
                    stakeId,
                    stake.amount,
                    stake.amount + reward,
                    reward,
                    block.timestamp,
                    stake.apy
                );
                _removeStake(stakes, i, _msgSender(), token);
                nonce[_msgSender()]++;
                return;
            }
        }
        revert StakeNotFound();
    }

    function unstake(
        address token,
        uint256 stakeId,
        bytes memory adminSignature
    ) external nonReentrant {
        if (!whitelistedToken[token]) revert TokenNotWhitelisted();
        if (
            !verifySignature(
                _msgSender(),
                token,
                stakeId,
                nonce[_msgSender()],
                ActionType.Unstake,
                adminSignature
            )
        ) revert InvalidAdminSignature();

        StakeDetails[] storage stakes = userTokenStakes[_msgSender()][token];

        for (uint i = 0; i < stakes.length; i++) {
            if (stakes[i].stakeId == stakeId) {
                StakeDetails memory stake = stakes[i];
                uint256 lockEndTime = stake.startTime +
                    (stake.duration * 1 days);
                uint256 currentTime = block.timestamp;

                uint256 refund = currentTime < lockEndTime
                    ? (
                        stake.amount > stake.totalClaimed
                            ? stake.amount - stake.totalClaimed
                            : 0
                    )
                    : stake.amount;

                bool success = IERC20(token).transfer(_msgSender(), refund);
                if (!success) revert TransferFailed();

                emit Unstaked(
                    _msgSender(),
                    token,
                    stakeId,
                    refund,
                    currentTime,
                    lockEndTime
                );
                _removeStake(stakes, i, _msgSender(), token);
                nonce[_msgSender()]++;
                return;
            }
        }
        revert StakeNotFound();
    }

    function autoRenewStake(
        address user,
        address token,
        uint256 stakeId
    ) external onlyRole(ADMIN_ROLE) {
        StakeDetails[] storage stakes = userTokenStakes[user][token];
        for (uint i = 0; i < stakes.length; i++) {
            if (stakes[i].stakeId == stakeId) {
                StakeDetails memory stake = stakes[i];

                uint256 endTime = stake.startTime + (stake.duration * 1 days);
                uint256 totalRewards = (stake.amount *
                    stake.apy *
                    (endTime - stake.startTime)) / (365 * 86400 * 100 * 10000);
                uint256 rewardToReinvest = totalRewards - stake.totalClaimed;
                if (block.timestamp < endTime) revert NotMatured();
                uint256 newStart = block.timestamp -
                    (block.timestamp % 1 days) +
                    (stake.startTime % 1 days);
                uint256 newStakeId = userStakeCount[user][token]++;

                stakes.push(
                    StakeDetails({
                        stakeId: newStakeId,
                        amount: stake.amount + rewardToReinvest,
                        startTime: newStart,
                        duration: stake.duration,
                        apy: stake.apy,
                        totalClaimed: 0,
                        lastHarvested: newStart
                    })
                );
                emit Staked(
                    user,
                    token,
                    newStakeId,
                    stake.amount + rewardToReinvest,
                    stake.duration,
                    stake.apy
                );
                _removeStake(stakes, i, user, token);
                return;
            }
        }
        revert StakeNotFound();
    }
    function setTrustedForwarder(
        address _trustedForwarder,
        bool _isTrusted
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        trustedForwarder[_trustedForwarder] = _isTrusted;
    }

    function isTrustedForwarder(
        address forwarder
    ) public view override returns (bool) {
        return trustedForwarder[forwarder];
    }
    /* -------------------------------------------------------------------------- */
    /*                            Internal Operations                             */
    /* -------------------------------------------------------------------------- */

    function _removeStake(
        StakeDetails[] storage stakes,
        uint256 index,
        address user,
        address token
    ) internal {
        stakes[index] = stakes[stakes.length - 1];
        stakes.pop();
        if (activeStakeCount[user][token] > 0) {
            activeStakeCount[user][token]--;
        }
    }


    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradable)
        returns (address)
    {
        return ERC2771ContextUpgradable._msgSender();
    }

    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradable._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradable)
        returns (uint256)
    {
        return ERC2771ContextUpgradable._contextSuffixLength();
    }
}
