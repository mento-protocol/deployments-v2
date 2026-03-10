// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @dev NTT Manager peer info returned by getPeer()
struct NttManagerPeer {
    bytes32 peerAddress;
    uint8 tokenDecimals;
}

/// @dev Rate limit parameters returned by getInboundLimitParams() / getOutboundLimitParams()
struct RateLimitParams {
    uint72 limit; // TrimmedAmount (packed: amount << 8 | decimals)
    uint72 currentCapacity; // TrimmedAmount
    uint64 lastTxTimestamp;
}

interface INTTManager {
    function setPeer(uint16 peerChainId, bytes32 peerContract, uint8 decimals, uint256 inboundLimit) external;
    function getPeer(uint16 chainId) external view returns (NttManagerPeer memory);
    function setInboundLimit(uint256 limit, uint16 chainId_) external;
    function setOutboundLimit(uint256 limit) external;
    function getOutboundLimitParams() external view returns (RateLimitParams memory);
    function getInboundLimitParams(uint16 chainId_) external view returns (RateLimitParams memory);
}
