// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {MockPool} from "@aave-v3-core/contracts/mocks/helpers/MockPool.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address poolAddressProvider;
        uint256 deployerKey;
    }

    MockPool public pool;

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            poolAddressProvider: 0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.poolAddressProvider != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        pool = new MockPool();
        vm.stopBroadcast();

        return NetworkConfig({poolAddressProvider: address(pool), deployerKey: DEFAULT_ANVIL_PRIVATE_KEY});
    }
}
