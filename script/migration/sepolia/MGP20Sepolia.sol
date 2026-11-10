// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {OZGovernor} from "lib/treb-sol/src/internal/sender/OZGovernorSender.sol";

import {MGP20} from "../MGP20.sol";

/**
 * @title MGP20Sepolia
 * @notice Celo Sepolia rehearsal of MGP20: the same proposal body, run against the testnet
 *         governor. The only difference is the sender list. treb-sol resolves an oz_governor
 *         proposer by sender *name*, which must equal the proposer account name. On mainnet that
 *         sender is pulled in automatically as the deployer Safe's signer; on Sepolia the dev
 *         key is the "deployer" sender itself, so the proposer must be requested explicitly
 *         (hyphen-free alias account `devpk`, declared as a testnet-v2-rc5 sender), otherwise the governor
 *         sender fails to initialize with InvalidOZGovernorConfig.
 */
contract MGP20Sepolia is MGP20 {
    using Senders for Senders.Sender;
    using OZGovernor for OZGovernor.Sender;

    uint256 internal constant CELO_SEPOLIA_CHAIN_ID = 11142220;

    /// @custom:senders deployer, governor, devpk
    function run() public override broadcast {
        require(block.chainid == CELO_SEPOLIA_CHAIN_ID, "MGP20Sepolia: only runnable on Celo Sepolia");

        Senders.Sender storage govSender = sender("governor");

        OZGovernor.Sender storage ozGovSender = govSender.ozGovernor();
        // A governor proposal id is the hash of its calls and description. Testnet supplies and
        // rates rarely move, so re-running after a defeated or expired rehearsal would produce the
        // same id and revert with "proposal already exists"; an optional suffix makes it unique.
        ozGovSender.setTitle(
            string.concat(
                "MGP-20 (Celo Sepolia rehearsal): Refresh trading limits on remaining Mento v2 exchanges",
                vm.envOr("MGP20_SEPOLIA_TITLE_SUFFIX", string(""))
            )
        );
        ozGovSender.setProposalDescription("./mgps/mgp20.md");

        preChecks();

        applyLimits(govSender);

        postChecks();
    }
}
