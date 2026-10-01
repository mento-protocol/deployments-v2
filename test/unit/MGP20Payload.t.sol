// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {MGP20Payload, IGovernorPayload} from "script/actions/CheckMGP20Payload.s.sol";

/// @dev External wrapper so the library's `require` reasons surface through `vm.expectRevert`.
contract PayloadHarness {
    function decodeAndValidate(bytes calldata input, address broker, MGP20Payload.ExpectedPool[] calldata pools)
        external
        pure
        returns (MGP20Payload.FrozenLimits[] memory)
    {
        return MGP20Payload.validate(MGP20Payload.decodePropose(input), broker, pools);
    }
}

/**
 * @title MGP20PayloadTest
 * @notice Decoder and shape tests for the MGP-20 payload checker, on synthetic payloads (no fork).
 */
contract MGP20PayloadTest is Test {
    uint8 internal constant LG = 4;
    address internal constant BROKER = address(0xB0B);
    address internal constant USDM = address(0xD01);

    PayloadHarness internal harness;
    MGP20Payload.ExpectedPool[] internal pools;

    struct Limits {
        int48 fx;
        int48 usdm;
    }

    function setUp() public {
        harness = new PayloadHarness();
        for (uint256 i = 0; i < MGP20Payload.POOL_COUNT; i++) {
            pools.push(
                MGP20Payload.ExpectedPool({
                    exchangeId: keccak256(abi.encodePacked("exchange", i)),
                    fxToken: address(uint160(0x1000 + i)),
                    usdmToken: USDM
                })
            );
        }
    }

    // ========== Builders ==========

    function limitsFor(uint256 i) internal pure returns (Limits memory) {
        return Limits({fx: int48(uint48(1_000 + i)), usdm: int48(uint48(500 + i))});
    }

    function resetConfig() internal pure returns (ITradingLimits.Config memory cfg) {}

    function setConfig(int48 limitGlobal) internal pure returns (ITradingLimits.Config memory cfg) {
        cfg.limitGlobal = limitGlobal;
        cfg.flags = LG;
    }

    function configureCall(bytes32 exchangeId, address token, ITradingLimits.Config memory cfg)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(IBroker.configureTradingLimit.selector, exchangeId, token, cfg);
    }

    /// @dev Builds the 40 calls in MGP20 order for the given pool order.
    function buildCalls(uint256[] memory order)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        uint256 n = order.length * MGP20Payload.CALLS_PER_POOL;
        targets = new address[](n);
        values = new uint256[](n);
        calldatas = new bytes[](n);
        for (uint256 g = 0; g < order.length; g++) {
            MGP20Payload.ExpectedPool memory pool = pools[order[g]];
            Limits memory l = limitsFor(order[g]);
            uint256 base = g * MGP20Payload.CALLS_PER_POOL;
            calldatas[base] = configureCall(pool.exchangeId, pool.fxToken, resetConfig());
            calldatas[base + 1] = configureCall(pool.exchangeId, pool.fxToken, setConfig(l.fx));
            calldatas[base + 2] = configureCall(pool.exchangeId, pool.usdmToken, resetConfig());
            calldatas[base + 3] = configureCall(pool.exchangeId, pool.usdmToken, setConfig(l.usdm));
            for (uint256 k = 0; k < MGP20Payload.CALLS_PER_POOL; k++) {
                targets[base + k] = BROKER;
            }
        }
    }

    function identityOrder() internal view returns (uint256[] memory order) {
        order = new uint256[](pools.length);
        for (uint256 i = 0; i < order.length; i++) {
            order[i] = i;
        }
    }

    function encodePropose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IGovernorPayload.propose.selector, targets, values, calldatas, '{"title":"MGP-20","description":"x"}'
        );
    }

    function validPayload() internal view returns (bytes memory) {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        return encodePropose(t, v, c);
    }

    function validate(bytes memory input) internal view returns (MGP20Payload.FrozenLimits[] memory) {
        return harness.decodeAndValidate(input, BROKER, pools);
    }

    function expectReason(string memory reason) internal {
        vm.expectRevert(bytes(reason));
    }

    // ========== Accepts ==========

    function test_validPayload_returnsFrozenLimitsInPayloadOrder() public view {
        MGP20Payload.FrozenLimits[] memory frozen = validate(validPayload());
        assertEq(frozen.length, MGP20Payload.POOL_COUNT);
        for (uint256 i = 0; i < frozen.length; i++) {
            assertEq(frozen[i].exchangeId, pools[i].exchangeId, "exchange id");
            assertEq(frozen[i].fxToken, pools[i].fxToken, "fx token");
            assertEq(frozen[i].usdmToken, USDM, "usdm token");
            assertEq(frozen[i].fxLimit, limitsFor(i).fx, "fx limit");
            assertEq(frozen[i].usdmLimit, limitsFor(i).usdm, "usdm limit");
        }
    }

    function test_validPayload_poolOrderMayDifferFromLiveSet() public view {
        uint256[] memory order = identityOrder();
        for (uint256 i = 0; i < order.length; i++) {
            order[i] = order.length - 1 - i;
        }
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(order);
        MGP20Payload.FrozenLimits[] memory frozen = validate(encodePropose(t, v, c));
        assertEq(frozen[0].exchangeId, pools[pools.length - 1].exchangeId);
        assertEq(frozen[0].fxLimit, limitsFor(pools.length - 1).fx);
    }

    // ========== Rejects: outer frame ==========

    function test_rejects_wrongOuterSelector() public {
        bytes memory input = validPayload();
        input[0] = bytes1(uint8(input[0]) ^ 0xff);
        expectReason("MGP20Payload: not a propose(address[],uint256[],bytes[],string) call");
        validate(input);
    }

    function test_rejects_inputShorterThanSelector() public {
        expectReason("MGP20Payload: input shorter than a selector");
        validate(hex"7d5e");
    }

    function test_rejects_tooFewCalls() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        assembly {
            mstore(t, 39)
            mstore(v, 39)
            mstore(c, 39)
        }
        expectReason("MGP20Payload: expected exactly 40 targets");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_tooManyCalls() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        address[] memory t2 = new address[](41);
        uint256[] memory v2 = new uint256[](41);
        bytes[] memory c2 = new bytes[](41);
        for (uint256 i = 0; i < 40; i++) {
            t2[i] = t[i];
            v2[i] = v[i];
            c2[i] = c[i];
        }
        t2[40] = t[39];
        c2[40] = c[39];
        expectReason("MGP20Payload: expected exactly 40 targets");
        validate(encodePropose(t2, v2, c2));
    }

    function test_rejects_wrongExpectedPoolCount() public {
        MGP20Payload.ExpectedPool[] memory nine = new MGP20Payload.ExpectedPool[](9);
        for (uint256 i = 0; i < 9; i++) {
            nine[i] = pools[i];
        }
        expectReason("MGP20Payload: expected exactly 10 exchanges");
        harness.decodeAndValidate(validPayload(), BROKER, nine);
    }

    // ========== Rejects: per-call shape ==========

    function test_rejects_reorderedResetAndSet() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        (c[0], c[1]) = (c[1], c[0]); // set-FX before reset-FX
        expectReason("MGP20Payload: call #0 reset config is not empty");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_usdmLegBeforeFxLeg() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        (c[0], c[2]) = (c[2], c[0]);
        (c[1], c[3]) = (c[3], c[1]);
        expectReason("MGP20Payload: call #0 reset token mismatch");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_wrongTokenForPool() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        // Pool 0's set-FX call carries pool 1's FX token.
        c[1] = configureCall(pools[0].exchangeId, pools[1].fxToken, setConfig(limitsFor(0).fx));
        expectReason("MGP20Payload: call #1 set token mismatch");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_setConfigWithExtraFlags() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        ITradingLimits.Config memory cfg = setConfig(limitsFor(0).fx);
        cfg.flags = LG | 1;
        cfg.timestep0 = 5 minutes;
        cfg.limit0 = 10;
        c[1] = configureCall(pools[0].exchangeId, pools[0].fxToken, cfg);
        expectReason("MGP20Payload: call #1 set config flags are not LG-only");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_setConfigWithL0FieldsButLgFlag() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        ITradingLimits.Config memory cfg = setConfig(limitsFor(0).usdm);
        cfg.limit1 = 7;
        c[3] = configureCall(pools[0].exchangeId, pools[0].usdmToken, cfg);
        expectReason("MGP20Payload: call #3 set config carries L0/L1 fields");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_zeroLimitGlobal() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        c[3] = configureCall(pools[0].exchangeId, pools[0].usdmToken, setConfig(0));
        expectReason("MGP20Payload: call #3 set config limitGlobal is not positive");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_resetConfigNotEmpty() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        ITradingLimits.Config memory cfg;
        cfg.limitGlobal = 1; // no flags, but a stray value
        c[2] = configureCall(pools[0].exchangeId, pools[0].usdmToken, cfg);
        expectReason("MGP20Payload: call #2 reset config is not empty");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_targetOtherThanBroker() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        t[5] = address(0xBAD);
        expectReason("MGP20Payload: call #5 target is not the Broker");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_nonZeroValue() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        v[7] = 1 wei;
        expectReason("MGP20Payload: call #7 value is not zero");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_wrongInnerSelector() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        c[4][0] = bytes1(uint8(c[4][0]) ^ 0x01);
        expectReason("MGP20Payload: call #4 is not configureTradingLimit");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_innerCallWithTrailingBytes() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        c[8] = abi.encodePacked(c[8], hex"00");
        expectReason("MGP20Payload: call #8 has an unexpected calldata length");
        validate(encodePropose(t, v, c));
    }

    // ========== Rejects: exchange set ==========

    function test_rejects_unknownExchangeId() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        bytes32 unknown = keccak256("not a live exchange");
        c[0] = configureCall(unknown, pools[0].fxToken, resetConfig());
        expectReason("MGP20Payload: unknown exchange id in group 0");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_exchangeUsedTwice() public {
        uint256[] memory order = identityOrder();
        order[9] = 0; // pool 0 appears twice, pool 9 never
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(order);
        expectReason("MGP20Payload: exchange used twice, group 9");
        validate(encodePropose(t, v, c));
    }

    function test_rejects_exchangeIdMismatchWithinGroup() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = buildCalls(identityOrder());
        // Group 0's set-USDm call points at pool 1's exchange.
        c[3] = configureCall(pools[1].exchangeId, pools[0].usdmToken, setConfig(limitsFor(0).usdm));
        expectReason("MGP20Payload: call #3 exchange id does not match its group");
        validate(encodePropose(t, v, c));
    }
}
