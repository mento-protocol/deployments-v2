// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {IMentoConfig} from "./IMentoConfig.sol";
import {ILiquityConfig} from "./ILiquityConfig.sol";

import "./mento/MentoConfig_celo.sol";
import "./mento/MentoConfig_celo_sepolia.sol";
import "./mento/MentoConfig_monad.sol";
import "./mento/MentoConfig_monad_testnet.sol";
import "./liquity/LiquityConfig_GBPm_celo.sol";
import "./liquity/LiquityConfig_GBPm_celo_sepolia.sol";
import "./liquity/LiquityConfig_CHFm_celo.sol";
import "./liquity/LiquityConfig_CHFm_celo_sepolia.sol";
import "./liquity/LiquityConfig_JPYm_celo.sol";
import "./liquity/LiquityConfig_JPYm_celo_sepolia.sol";

library Config {
    address private constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    /**
     * @notice Gets the Mento configuration contract as a IMentoConfig
     * @dev This is meant to preserve compatibility with Mento V2 scripts
     * @return The deployed config contract instance
     */
    function get() internal returns (IMentoConfig) {
        return IMentoConfig(_get("MentoConfig"));
    }

    function getLiquity(string memory token) internal returns (ILiquityConfig) {
        return ILiquityConfig(_get(string.concat("LiquityConfig_", token)));
    }

    /**
     * @notice Gets the Mento configuration contract
     * @dev Checks MENTO_CONFIG_CONTRACT env var for the artifact name to deploy
     * @return The deployed config contract instance
     */
    function _get(string memory baseName) internal returns (address) {
        // Get the config contract artifact name from environment
        string memory artifactName = string.concat(baseName, "_", vm.envString("NETWORK"));

        // Check if we already have a cached config
        bytes32 slot = keccak256(abi.encode(artifactName));
        address cachedConfig;
        assembly {
            cachedConfig := sload(slot)
        }

        if (cachedConfig != address(0)) {
            return cachedConfig;
        }

        try vm.deployCode(artifactName) returns (address configContract) {
            require(configContract != address(0), "Config contract deployment failed");
            // Cache the deployed config
            assembly {
                sstore(slot, configContract)
            }

            console.log(string.concat("Deployed ", artifactName, " at:"), configContract);
            return configContract;
        } catch (bytes memory data) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
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
     * @notice Clears the cached config contract for a given artifact base name
     * @dev Useful for testing when you want to redeploy the config
     */
    function clearCache(string memory baseName) internal {
        string memory artifactName = string.concat(baseName, "_", vm.envString("NETWORK"));
        bytes32 slot = keccak256(abi.encode(artifactName));
        assembly {
            sstore(slot, 0)
        }
    }
}
