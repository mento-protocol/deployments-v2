// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {IMentoConfig} from "./IMentoConfig.sol";

import "./MentoConfig_vbase.sol";
import "./MentoConfig_celo.sol";
import "./MentoConfig_celo_sepolia.sol";
import "./MentoConfig_monad_testnet.sol";
import "./MentoConfig_monad_local_fork.sol";
import "./MentoConfig_celo_sepolia_local_fork.sol";

library Config {
    address private constant VM_ADDRESS =
        address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    // Cache the config contract to avoid multiple deployments
    address private constant CACHE_SLOT =
        address(uint160(uint256(keccak256("mento.config.cache"))));

    /**
     * @notice Gets the Mento configuration contract as a IMentoConfig
     * @dev This is meant to preserve compatibility with Mento V2 scripts
     * @return The deployed config contract instance
     */
    function get() internal returns (IMentoConfig) {
        return IMentoConfig(_get("MentoConfig"));
    }

    /**
     * @notice Gets the Mento configuration contract
     * @dev Checks MENTO_CONFIG_CONTRACT env var for the artifact name to deploy
     * @return The deployed config contract instance
     */
    function _get(string memory baseName) internal returns (address) {
        // Check if we already have a cached config
        bytes32 slot = keccak256(abi.encode(CACHE_SLOT));
        address cachedConfig;
        assembly {
            cachedConfig := sload(slot)
        }

        if (cachedConfig != address(0)) {
            return cachedConfig;
        }

        // Get the config contract artifact name from environment
        string memory artifactName;
        try vm.envString("MENTO_CONFIG_CONTRACT") returns (string memory name) {
            artifactName = name;
        } catch {
            // Default to a base config if not specified
            artifactName = string.concat(
                baseName,
                "_",
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
            return configContract;
        } catch {
            revert(
                string.concat(
                    "Config: failed to deploy '",
                    artifactName,
                    "'. Check that the contract exists and NETWORK is set correctly."
                )
            );
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
