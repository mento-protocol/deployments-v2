// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {IMentoConfig} from "./IMentoConfig.sol";

import "./MentoConfig_vbase.sol";
import "./MentoConfig_celo_sepolia.sol";
import "./MentoConfig_monad_testnet.sol";

library Config {
    address private constant VM_ADDRESS =
        address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    // Cache the config contract to avoid multiple deployments
    address private constant CACHE_SLOT =
        address(uint160(uint256(keccak256("mento.config.cache"))));

    /**
     * @notice Gets the Mento configuration contract
     * @dev Checks MENTO_CONFIG_CONTRACT env var for the artifact name to deploy
     * @return The deployed config contract instance
     */
    function get() internal returns (IMentoConfig) {
        // Check if we already have a cached config
        bytes32 slot = keccak256(abi.encode(CACHE_SLOT));
        address cachedConfig;
        assembly {
            cachedConfig := sload(slot)
        }

        if (cachedConfig != address(0)) {
            return IMentoConfig(cachedConfig);
        }

        // Get the config contract artifact name from environment
        string memory artifactName;
        try vm.envString("MENTO_CONFIG_CONTRACT") returns (string memory name) {
            artifactName = name;
        } catch {
            // Default to a base config if not specified
            artifactName = string.concat(
                "MentoConfig_",
                vm.envString("NETWORK")
            );
        }

        try vm.deployCode(artifactName) returns (address configContract) {
            require(
                configContract != address(0),
                "Config contract deployment failed"
            );
            // Cache the deployed config
            assembly {
                sstore(slot, configContract)
            }

            console.log(
                string.concat("Deployed ", artifactName, " at:"),
                configContract
            );
            return IMentoConfig(configContract);
        } catch {
            return IMentoConfig(address(0));
        }
    }

    /**
     * @notice Clears the cached config contract
     * @dev Useful for testing when you want to redeploy the config
     */
    function clearCache() internal {
        bytes32 slot = keccak256(abi.encode(CACHE_SLOT));
        assembly {
            sstore(slot, 0)
        }
    }
}
