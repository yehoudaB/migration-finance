// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

//import {MockPool} from "@aave-v3-core/contracts/mocks/helpers/MockPool.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address poolAddressProvider;
        uint256 deployerKey;
        address poolProxy;
        address usdt;
        address variableDebtTokenUsdt;
    }

    // MockPool public pool;

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
        return NetworkConfig({
            poolAddressProvider: 0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            poolProxy: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951,
            usdt: 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0,
            variableDebtTokenUsdt: 0x9844386d29EEd970B9F6a2B9a676083b0478210e
        });
    }
}
