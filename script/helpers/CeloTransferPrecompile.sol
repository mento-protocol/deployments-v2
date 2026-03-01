// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Stub Celo transfer precompile for Anvil forks.
/// @dev Returns success for any call. The real precompile syncs native balances
///      with GoldToken, but on Anvil we replace GoldToken with a standard ERC20
///      so the precompile is never needed. This is just a safety net.
contract CeloTransferPrecompile {
    fallback(bytes calldata) external returns (bytes memory) {
        return abi.encode(true);
    }
}
