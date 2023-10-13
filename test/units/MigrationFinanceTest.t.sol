// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {MigrationFinance} from "src/MigrationFinance.sol";
import {DeployMigrationFinance} from "script/DeployMigrationFinance.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract MigrationFinanceTest is Test {
    /**
     * Events
     */

    address public USER = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    MigrationFinance public migrationFinance;
    HelperConfig helperConfig;
    address[] assetsToBorrow;
    uint256[] amountsToBorrow;
    uint256[] premiums; // find what this is
    bytes params; // find what this is
    address poolAddressProvider;
    uint256 deployerKey;
    address poolProxy;
    address usdt;
    address variableDebtTokenUsdt;

    function setUp() public {
        DeployMigrationFinance migrationFinanceDeployer = new DeployMigrationFinance();
        console.log("Deploying MigrationFinance");
        (migrationFinance, helperConfig) = migrationFinanceDeployer.run();
        (poolAddressProvider, deployerKey, poolProxy, usdt, variableDebtTokenUsdt) = helperConfig.activeNetworkConfig();
        console.log("MigrationFinance deployed at ", address(migrationFinance));
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    function testGetFlashLoan() public {
        console.log("testGetFlashLoan");
        vm.startBroadcast();

        assetsToBorrow.push(usdt);
        amountsToBorrow.push(10000);
        premiums.push(0);
        params = "0x";

        bool success = migrationFinance.getFlashLoan(assetsToBorrow, amountsToBorrow, premiums, USER, params);
        vm.stopBroadcast();
        assertTrue(success, "getFlashLoan failed");
    }
}
