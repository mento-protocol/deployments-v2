// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

/**
 * @title Imports08
 * @notice This file imports all Mento protocol contracts that use Solidity 0.8.24
 *         to ensure they are compiled and their artifacts are available for deployment scripts.
 */
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {OracleAdapter} from "mento-core/oracles/OracleAdapter.sol";
import {MarketHoursBreaker} from "mento-core/oracles/breakers/MarketHoursBreaker.sol";

import {VirtualPool} from "mento-core/swap/virtual/VirtualPool.sol";
import {VirtualPoolFactory} from "mento-core/swap/virtual/VirtualPoolFactory.sol";
import {FPMMFactory} from "mento-core/swap/FPMMFactory.sol";
import {FPMM} from "mento-core/swap/FPMM.sol";
import {FPMMFactory} from "mento-core/swap/FPMMFactory.sol";
import {OneToOneFPMM} from "mento-core/swap/OneToOneFPMM.sol";
import {FactoryRegistry} from "mento-core/swap/FactoryRegistry.sol";
import {Router} from "mento-core/swap/router/Router.sol";
import {ReserveV2} from "mento-core/swap/ReserveV2.sol";
import {CDPLiquidityStrategy} from "mento-core/liquidityStrategies/CDPLiquidityStrategy.sol";
import {ReserveLiquidityStrategy} from "mento-core/liquidityStrategies/ReserveLiquidityStrategy.sol";
import {OpenLiquidityStrategy} from "mento-core/liquidityStrategies/OpenLiquidityStrategy.sol";
