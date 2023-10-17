// SPDX-License-Identifier: MIT
import {Script, console} from "forge-std/Script.sol";
import {MigrationFinance} from "src/MigrationFinance.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";

pragma solidity ^0.8.20;

contract DeployMigrationFinance is Script {
    function run() external returns (MigrationFinance, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (IPoolAddressesProvider iPoolAddressProvider,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        console.log("iPoolAddressProvider", address(iPoolAddressProvider));

        console.log("deployerKey", deployerKey);
        vm.startBroadcast(deployerKey);
        MigrationFinance migrationFinance = new MigrationFinance(address(iPoolAddressProvider));
        vm.stopBroadcast();
        return (migrationFinance, helperConfig);
    }
}
