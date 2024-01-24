// SPDX-License-Identifier: MIT
import {Script, console} from "forge-std/Script.sol";
import {TeleportAaveV3} from "src/TeleportAaveV3.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {PrepareTeleportAaveV3} from "src/PrepareTeleportAaveV3.sol";

pragma solidity ^0.8.20;

contract DeployTeleportFinance is Script {
    function run() external returns (TeleportAaveV3, HelperConfig, PrepareTeleportAaveV3) {
        HelperConfig helperConfig = new HelperConfig();

        (
            IPoolAddressesProvider iPoolAddressProvider,
            IPoolDataProvider iPoolDataProvider,
            IPool iPool,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        TeleportAaveV3 teleportAaveV3 =
            new TeleportAaveV3(address(iPoolAddressProvider), payable(0x9945852318056dC9EbAfdC3caC70d05e0fBa00F7));

        PrepareTeleportAaveV3 prepareTeleportAaveV3 =
            new PrepareTeleportAaveV3(iPoolDataProvider, iPool, teleportAaveV3);
        vm.stopBroadcast();
        return (teleportAaveV3, helperConfig, prepareTeleportAaveV3);
    }
}
