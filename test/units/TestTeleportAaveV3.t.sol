// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {TeleportAaveV3} from "src/TeleportAaveV3.sol";
import {DeployTeleportFinance} from "script/DeployTeleportFinance.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {IUiPoolDataProviderV3} from "@aave-v3-periphery/contracts/misc/interfaces/IUiPoolDataProviderV3.sol";
import {ICreditDelegationToken} from "@aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {PrepareTeleportAaveV3} from "src/PrepareTeleportAaveV3.sol";
import {InteractWithTeleportAaveV3} from "script/InteractWithTeleportAaveV3.s.sol";

contract MigrationFinanceTest is Test {
    /**
     * Events
     */

    address public USER_1 = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)
    address public USER_2 = 0xC5e0B6E472dDE70eCEfFa4c568Bd52f2A7a1632A; // account 5 metamask dev
    address public USER_6 = 0xb34AEFdA3a46De36eBa562B297a87De107C9c596;
    TeleportAaveV3 public teleportAaveV3;
    HelperConfig helperConfig;
    PrepareTeleportAaveV3 prepareTeleportAaveV3;
    InteractWithTeleportAaveV3 interactWithTeleportAaveV3;
    IPoolAddressesProvider iPoolAddressProvider;
    IPoolDataProvider iPoolDataProvider;
    IPool iPool;
    uint256 deployerKey;

    address usdt = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
    address usdc = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address eurs = 0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E;
    address link = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;
    address dai = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;

    function setUp() public {
        DeployTeleportFinance teleportFinanceDeployer = new DeployTeleportFinance();
        (teleportAaveV3, helperConfig, prepareTeleportAaveV3) = teleportFinanceDeployer.run();
        (iPoolAddressProvider, iPoolDataProvider, iPool, deployerKey) = helperConfig.activeNetworkConfig();
        interactWithTeleportAaveV3 = new InteractWithTeleportAaveV3();
    }

    /*
    * @notice the user must have deposited this asset in the pool before calling this function
    */
    function testSetUserUseReserveAsCollateral() public {
        vm.startBroadcast(USER_1);
        iPool.setUserUseReserveAsCollateral(usdc, true); // usdt is not permitted as collateral
        vm.stopBroadcast();
    }

    function testGetAllAaveV3PositionsToMoveViaTeleportAaveV3() public view {
        (
            address[] memory assetsBorrowed,
            uint256[] memory amountsBorrowed,
            uint256[] memory interestRateModesForPositions,
            uint256[] memory interestRateModesForFL,
            address[] memory aTokenAssetsToMove,
            uint256[] memory aTokenAmountsToMove
        ) = prepareTeleportAaveV3.getAllAaveV3PositionsToMoveViaTeleportAaveV3(USER_6);
        for (uint256 i = 0; i < assetsBorrowed.length; i++) {
            console.log("----------BORROWED-----------------------------");
            console.log("assetsBorrowed", assetsBorrowed[i]);
            console.log("amountsBorrowed", amountsBorrowed[i]);
            console.log("interestRateModesForPositions", interestRateModesForPositions[i]);
            console.log("--------------------------------------------");
        }
        for (uint256 i = 0; i < aTokenAssetsToMove.length; i++) {
            console.log("----------ATOKEN-----------------------------");
            console.log("aTokenAssetsToMove", aTokenAssetsToMove[i]);
            console.log("aTokenAmountsToMove", aTokenAmountsToMove[i]);
            uint256 allowance = IERC20(aTokenAssetsToMove[i]).allowance(USER_6, address(teleportAaveV3));
            console.log("allowance", allowance);
            console.log("--------------------------------------------");
        }
    }

    function testMoveAavePositionsWithInteractions() public {
        address sourceAddress = interactWithTeleportAaveV3.sourceAddress();
        iPool.getUserAccountData(sourceAddress);
        (
            uint256 totalCollateralBaseBeforeSource,
            uint256 totalDebtBaseBeforeSource,
            uint256 availableBorrowsBaseBeforeSource,
            uint256 currentLiquidationThresholdBeforeSource,
            uint256 ltvBeforeSource,
            uint256 healthFactorBeforeSource
        ) = iPool.getUserAccountData(sourceAddress);
        console.log("healthFactorBeforeSource", healthFactorBeforeSource);
        console.log("totalCollateralBaseBeforeSource", totalCollateralBaseBeforeSource);
        address destinationAddress = interactWithTeleportAaveV3.destinationAddress();
        (
            uint256 totalCollateralBaseBeforeDestination,
            uint256 totalDebtBaseBeforeDestination,
            uint256 availableBorrowsBaseBeforeDestination,
            uint256 currentLiquidationThresholdBeforeDestination,
            uint256 ltvBeforeDestination,
            uint256 healthFactorBeforeDestination
        ) = iPool.getUserAccountData(sourceAddress);
        iPool.getUserAccountData(destinationAddress);
        interactWithTeleportAaveV3.teleport(teleportAaveV3, prepareTeleportAaveV3);
        (
            uint256 totalCollateralBaseAfterDestination,
            uint256 totalDebtBaseAfterDestination,
            uint256 availableBorrowsBaseAfterDestination,
            uint256 currentLiquidationThresholdAfterDestination,
            uint256 ltvAfterDestination,
            uint256 healthFactorAfterDestination
        ) = iPool.getUserAccountData(destinationAddress);
        console.log("healthFactorBeforDestination", healthFactorBeforeDestination);
        console.log("healthFactorAfterDestination", healthFactorAfterDestination);
        assert(totalCollateralBaseAfterDestination > totalCollateralBaseBeforeDestination);
        assert(totalDebtBaseAfterDestination > totalDebtBaseBeforeDestination);
        assert(availableBorrowsBaseAfterDestination > availableBorrowsBaseBeforeDestination);
        assert(currentLiquidationThresholdAfterDestination > currentLiquidationThresholdBeforeDestination);
        assert(ltvAfterDestination > ltvBeforeDestination);

        // check that the user has no more debt
        (,,,,, uint256 healthFactor) = iPool.getUserAccountData(sourceAddress);
        assert(healthFactor == type(uint256).max);
    }

    /*
    * @notice the USER_2 must have some usdc in his wallet
    */
    function testWithdrawERC20() public {
        address payable admin = teleportAaveV3.getAdmin();
        uint256 adminBalanceUsdcBefore = IERC20(usdc).balanceOf(teleportAaveV3.getAdmin());

        console.log("userUsdcBalance before", adminBalanceUsdcBefore);
        vm.startBroadcast(USER_2);
        // send usdc to teleportAaveV3

        IERC20(usdc).transfer(address(teleportAaveV3), 1000000);
        teleportAaveV3.withdrawERC20(usdc);
        vm.stopBroadcast();
        console.log("userUsdcBalance after", IERC20(usdc).balanceOf(admin));
        console.log("teleportAaveV3 balance", IERC20(usdc).balanceOf(address(teleportAaveV3)));
        assert(IERC20(usdc).balanceOf(address(teleportAaveV3)) == 0);
        assert(IERC20(usdc).balanceOf(admin) == adminBalanceUsdcBefore + 1000000);
    }

    function testWithdrawETH() public {
        address payable admin = teleportAaveV3.getAdmin();
        console.log("admin", admin);
        uint256 adminBalanceETHBefore = address(admin).balance;
        console.log("adminBalanceETHBefore", adminBalanceETHBefore);
        vm.deal(address(teleportAaveV3), 1 ether);
        vm.startBroadcast(USER_2);
        teleportAaveV3.withdraw();
        vm.stopBroadcast();
        console.log("adminBalanceETHAfter", address(admin).balance);
        assert(address(admin).balance > adminBalanceETHBefore);
    }
}
