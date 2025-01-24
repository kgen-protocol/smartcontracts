// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UserLoyaltyOnChain {
    struct OnChainData {
        bytes32 userId;
        bytes32 eventId;
        uint32 timestamp;
    }

    event OnChainDataEmit(
        OnChainData data
    );

    function emitOnChainData(OnChainData calldata newData) external {
        emit OnChainDataEmit(newData);
    }
}