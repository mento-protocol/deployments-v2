// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";

/// @dev Minimal interface for the MentoGovernor on-chain getters.
///      MentoGovernor inherits GovernorSettingsUpgradeable and
///      GovernorVotesQuorumFractionUpgradeable, exposing these public functions.
interface IMentoGovernorView {
    function votingDelay() external view returns (uint256);

    function votingPeriod() external view returns (uint256);

    function proposalThreshold() external view returns (uint256);

    function quorumNumerator() external view returns (uint256);
}

/// @dev Minimal interface for the Mento TimelockController on-chain getters.
///      TimelockController inherits TimelockControllerUpgradeable which
///      inherits AccessControlUpgradeable.
interface ITimelockControllerView {
    function getMinDelay() external view returns (uint256);

    function hasRole(bytes32 role, address account) external view returns (bool);

    function CANCELLER_ROLE() external view returns (bytes32);
}

/// @dev Minimal interface for the Locking contract public state variables.
interface ILockingView {
    function minCliffPeriod() external view returns (uint256);

    function minSlopePeriod() external view returns (uint256);
}

/**
 * @title GovernanceVerification
 * @notice Verifies that on-chain governance, oracle, and locking configuration
 *         matches the values returned by the deployment config:
 *         - GovernanceConfig: timelockDelay, votingDelay, votingPeriod,
 *           proposalThreshold, quorum, watchdog
 *         - OracleConfig: reportExpirySeconds
 *         - LockingConfig: minCliffPeriod, minSlopePeriod
 */
contract GovernanceVerification is V3IntegrationBase {
    address internal mentoGovernor;
    address internal timelockController;
    address internal locking;

    IMentoConfig.GovernanceConfig internal govCfg;
    IMentoConfig.OracleConfig internal oracleCfg;
    IMentoConfig.LockingConfig internal lockingCfg;

    function setUp() public override {
        super.setUp();
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }

        // Resolve governance contract addresses from the Treb registry
        mentoGovernor = lookupProxyOrFail("MentoGovernor");
        timelockController = lookupProxyOrFail("TimelockController");
        locking = lookupProxyOrFail("Locking");

        // Cache config structs
        govCfg = config.getGovernanceConfig();
        oracleCfg = config.getOracleConfig();
        lockingCfg = config.getLockingConfig();
    }

    // ========== GovernanceConfig: TimelockController ==========

    /// @notice TimelockController minDelay must match config timelockDelay
    function test_timelockDelay_matchesConfig() public view {
        uint256 actual = ITimelockControllerView(timelockController).getMinDelay();
        assertEq(actual, govCfg.timelockDelay, "TimelockController.getMinDelay() does not match config timelockDelay");
    }

    // ========== GovernanceConfig: MentoGovernor ==========

    /// @notice MentoGovernor votingDelay must match config
    function test_votingDelay_matchesConfig() public view {
        uint256 actual = IMentoGovernorView(mentoGovernor).votingDelay();
        assertEq(actual, govCfg.votingDelay, "MentoGovernor.votingDelay() does not match config votingDelay");
    }

    /// @notice MentoGovernor votingPeriod must match config
    function test_votingPeriod_matchesConfig() public view {
        uint256 actual = IMentoGovernorView(mentoGovernor).votingPeriod();
        assertEq(actual, govCfg.votingPeriod, "MentoGovernor.votingPeriod() does not match config votingPeriod");
    }

    /// @notice MentoGovernor proposalThreshold must match config
    function test_proposalThreshold_matchesConfig() public view {
        uint256 actual = IMentoGovernorView(mentoGovernor).proposalThreshold();
        assertEq(
            actual,
            govCfg.proposalThreshold,
            "MentoGovernor.proposalThreshold() does not match config proposalThreshold"
        );
    }

    /// @notice MentoGovernor quorum numerator (percentage) must match config quorum
    function test_quorumNumerator_matchesConfig() public view {
        uint256 actual = IMentoGovernorView(mentoGovernor).quorumNumerator();
        assertEq(actual, govCfg.quorum, "MentoGovernor.quorumNumerator() does not match config quorum");
    }

    // ========== GovernanceConfig: Watchdog ==========

    /// @notice The watchdog address from config must hold the CANCELLER_ROLE on the TimelockController
    function test_watchdog_hasCancellerRole() public view {
        bytes32 cancellerRole = ITimelockControllerView(timelockController).CANCELLER_ROLE();
        assertTrue(
            ITimelockControllerView(timelockController).hasRole(cancellerRole, govCfg.watchdog),
            "Config watchdog does not hold CANCELLER_ROLE on TimelockController"
        );
    }

    // ========== OracleConfig ==========

    /// @notice SortedOracles reportExpirySeconds must match config
    function test_reportExpirySeconds_matchesConfig() public view {
        uint256 actual = ISortedOracles(sortedOracles).reportExpirySeconds();
        assertEq(
            actual,
            oracleCfg.reportExpirySeconds,
            "SortedOracles.reportExpirySeconds() does not match config reportExpirySeconds"
        );
    }

    // ========== LockingConfig ==========

    /// @notice Locking minCliffPeriod must match config
    function test_minCliffPeriod_matchesConfig() public view {
        uint256 actual = ILockingView(locking).minCliffPeriod();
        assertEq(actual, lockingCfg.minCliffPeriod, "Locking.minCliffPeriod() does not match config minCliffPeriod");
    }

    /// @notice Locking minSlopePeriod must match config
    function test_minSlopePeriod_matchesConfig() public view {
        uint256 actual = ILockingView(locking).minSlopePeriod();
        assertEq(actual, lockingCfg.minSlopePeriod, "Locking.minSlopePeriod() does not match config minSlopePeriod");
    }
}
