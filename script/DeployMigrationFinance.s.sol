// SPDX-License-Identifier: MIT
import {Script, console} from "forge-std/Script.sol";
import {MigrationFinance} from "src/MigrationFinance.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

pragma solidity ^0.8.20;

contract DeployMigrationFinance is Script {
    function run() external returns (MigrationFinance, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address poolAddressProvider, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        MigrationFinance migrationFinance = new MigrationFinance(poolAddressProvider);
        vm.stopBroadcast();
        console.log("poolAddressProvider: %s", poolAddressProvider);
        return (migrationFinance, helperConfig);
    }
}
