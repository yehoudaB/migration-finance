// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {MigrationFinance} from "src/MigrationFinance.sol";
import {DeployMigrationFinance} from "script/DeployMigrationFinance.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

    IPoolAddressesProvider iPoolAddressProvider;
    IPoolDataProvider iPoolDataProvider;
    IPool iPool;
    uint256 deployerKey;
    address[] assetsToBorrow;
    uint256[] amountsToBorrow;
    uint256[] interestRateModes;
    address usdt = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
    address usdc = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    bytes params = ""; //Arbitrary bytes-encoded params that will be passed to executeOperation() method of the receiver contract.

    function setUp() public {
        DeployMigrationFinance migrationFinanceDeployer = new DeployMigrationFinance();
        (migrationFinance, helperConfig) = migrationFinanceDeployer.run();
        (iPoolAddressProvider, iPoolDataProvider, iPool, deployerKey) = helperConfig.activeNetworkConfig();
        console.log("MigrationFinance deployed at ", address(migrationFinance));
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    function testGetAaveReserveTokenList() public view {
        address[] memory aaveReserveTokenList = helperConfig.getAaveMarketReserveTokenList();
        for (uint256 i = 0; i < aaveReserveTokenList.length; i++) {
            console.log("aaveReserveTokenList", aaveReserveTokenList[i]);
        }
        assert(aaveReserveTokenList.length > 0);
    }

    function testGetAaveUserDataOnAllAsset() public view {
        address[] memory aaveReserveTokenList = helperConfig.getAaveMarketReserveTokenList();

        for (uint256 i = 0; i < aaveReserveTokenList.length; i++) {
            address reserveToken = aaveReserveTokenList[i];
            HelperConfig.AaveUserDataOnOneAsset memory aaveUserDataOnOneAsset =
                helperConfig.getAavePositionOfUserByAsset(reserveToken, USER);
            console.log("------------------- ", ERC20(reserveToken).symbol(), " -------------------");
            console.log("aaveUserDataOnOneAsset.currentATokenBalance", aaveUserDataOnOneAsset.currentATokenBalance);
            console.log("aaveUserDataOnOneAsset.currentStableDebt", aaveUserDataOnOneAsset.currentStableDebt);
            console.log("aaveUserDataOnOneAsset.currentVariableDebt", aaveUserDataOnOneAsset.currentVariableDebt);
            console.log("aaveUserDataOnOneAsset.principalStableDebt", aaveUserDataOnOneAsset.principalStableDebt);
            console.log("aaveUserDataOnOneAsset.scaledVariableDebt", aaveUserDataOnOneAsset.scaledVariableDebt);
            console.log("aaveUserDataOnOneAsset.stableBorrowRate", aaveUserDataOnOneAsset.stableBorrowRate);
            console.log("aaveUserDataOnOneAsset.liquidityRate", aaveUserDataOnOneAsset.liquidityRate);
            console.log("aaveUserDataOnOneAsset.stableRateLastUpdated", aaveUserDataOnOneAsset.stableRateLastUpdated);
            console.log(
                "aaveUserDataOnOneAsset.usageAsCollateralEnabled", aaveUserDataOnOneAsset.usageAsCollateralEnabled
            );
            console.log("______________________________________________________________");
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
