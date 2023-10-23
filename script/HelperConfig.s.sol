// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {TeleportAaveV3} from "src/TeleportAaveV3.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        IPoolAddressesProvider iPoolAddressProvider;
        IPoolDataProvider iPoolDataProvider;
        IPool iPool;
        uint256 deployerKey;
    }

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        }
        // for local testing we use a fork from sepolia localy (see README.md)
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        IPoolAddressesProvider iPoolAddressProvider = IPoolAddressesProvider(0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A);
        return NetworkConfig({
            iPoolAddressProvider: iPoolAddressProvider,
            iPoolDataProvider: IPoolDataProvider(iPoolAddressProvider.getPoolDataProvider()),
            iPool: IPool(iPoolAddressProvider.getPool()),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }
}
