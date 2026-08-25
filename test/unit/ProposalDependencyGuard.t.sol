// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProposalDependencyGuard} from "src/ProposalDependencyGuard.sol";

contract MockGovernor {
    mapping(uint256 => uint8) internal states;
    mapping(uint256 => bool) internal known;

    function set(uint256 id, uint8 s) external {
        states[id] = s;
        known[id] = true;
    }

    function state(uint256 id) external view returns (uint8) {
        require(known[id], "Governor: unknown proposal id");
        return states[id];
    }
}

contract ProposalDependencyGuardTest is Test {
    uint8 constant PENDING = 0;
    uint8 constant ACTIVE = 1;
    uint8 constant CANCELED = 2;
    uint8 constant DEFEATED = 3;
    uint8 constant SUCCEEDED = 4;
    uint8 constant QUEUED = 5;
    uint8 constant EXPIRED = 6;
    uint8 constant EXECUTED = 7;

    ProposalDependencyGuard guard;
    MockGovernor governor;
    uint256 constant ID = 42;

    function setUp() public {
        guard = new ProposalDependencyGuard();
        governor = new MockGovernor();
    }

    function test_revertsWhileDependencyIsPendingActiveSucceededOrQueued() public {
        uint8[4] memory blocking = [PENDING, ACTIVE, SUCCEEDED, QUEUED];
        for (uint256 i = 0; i < blocking.length; i++) {
            governor.set(ID, blocking[i]);
            assertFalse(guard.isSettled(address(governor), ID));
            vm.expectRevert(
                abi.encodeWithSelector(
                    ProposalDependencyGuard.DependencyNotSettled.selector, address(governor), ID, blocking[i]
                )
            );
            guard.requireSettled(address(governor), ID);
        }
    }

    function test_passesOnceDependencyIsExecutedCanceledDefeatedOrExpired() public {
        uint8[4] memory settled = [EXECUTED, CANCELED, DEFEATED, EXPIRED];
        for (uint256 i = 0; i < settled.length; i++) {
            governor.set(ID, settled[i]);
            assertTrue(guard.isSettled(address(governor), ID));
            guard.requireSettled(address(governor), ID); // must not revert
        }
    }

    function test_revertsForUnknownProposal() public {
        vm.expectRevert("Governor: unknown proposal id");
        guard.requireSettled(address(governor), 1337);
    }
}
