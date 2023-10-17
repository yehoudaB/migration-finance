// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {MigrationFinance} from "src/MigrationFinance.sol";
import {DeployMigrationFinance} from "script/DeployMigrationFinance.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {IUiPoolDataProviderV3} from "@aave-v3-periphery/contracts/misc/interfaces/IUiPoolDataProviderV3.sol";

contract MigrationFinanceTest is Test {
    /**
     * Events
     */

    address public USER = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    MigrationFinance public migrationFinance;
    HelperConfig helperConfig;

    address poolAddressProvider;
    uint256 deployerKey;
    address poolProxy;
    address usdt;
    address usdc;
    address variableDebtTokenUsdt;
    address[] assetsToBorrow;
    uint256[] amountsToBorrow;
    uint256[] interestRateModes;
    bytes params = ""; //Arbitrary bytes-encoded params that will be passed to executeOperation() method of the receiver contract.

    function setUp() public {
        DeployMigrationFinance migrationFinanceDeployer = new DeployMigrationFinance();
        console.log("Deploying MigrationFinance");
        (migrationFinance, helperConfig) = migrationFinanceDeployer.run();
        (poolAddressProvider, deployerKey, poolProxy, usdt, usdc, variableDebtTokenUsdt) =
            helperConfig.activeNetworkConfig();
        console.log("MigrationFinance deployed at ", address(migrationFinance));
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    function testGetAddressesList() public {
        IPoolAddressesProvider iPoolAddressProvider = IPoolAddressesProvider(poolAddressProvider);
        IPool pool = IPool(iPoolAddressProvider.getPool());
        IPoolDataProvider poolDataProviderInstance = IPoolDataProvider(iPoolAddressProvider.getPoolDataProvider());

        console.log("poolAddressProvider", address(poolAddressProvider));
        console.log("pool", address(pool));
        console.log("poolDataProviderInstance", address(poolDataProviderInstance));

        address[] memory allReservesTokens = pool.getReservesList();

        IPoolDataProvider.TokenData[] memory data = poolDataProviderInstance.getAllATokens();
        console.log("data", data.length);
        for (uint256 i = 0; i < data.length; i++) {
            console.log("data", i, data[i].symbol);
        }
    }

    function testRequestFlashLoan() public {
        console.log("testGetFlashLoan");
        assetsToBorrow.push(usdt);
        assetsToBorrow.push(usdc);
        amountsToBorrow.push(100e6);
        amountsToBorrow.push(200e6);
        interestRateModes.push(0); // no open debt. (amount+fee must be paid in this case or revert)
        interestRateModes.push(0); // no open debt. (amount+fee must be paid in this case or revert)
        vm.startBroadcast(USER);
        IERC20(usdt).transfer(address(migrationFinance), 1e6);
        IERC20(usdc).transfer(address(migrationFinance), 2e6);
        console.log("usdt balance of migrationFinance", IERC20(usdt).balanceOf(address(migrationFinance)));
        console.log("usdc balance of migrationFinance", IERC20(usdc).balanceOf(address(migrationFinance)));
        uint16 referralCode = 0;

        migrationFinance.requestFlashLoan(
            address(migrationFinance),
            assetsToBorrow,
            amountsToBorrow,
            interestRateModes,
            address(migrationFinance),
            params,
            referralCode
        );
        vm.stopBroadcast();
    }
}
