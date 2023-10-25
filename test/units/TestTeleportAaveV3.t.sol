// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {TeleportAaveV3} from "src/TeleportAaveV3.sol";
import {DeployMigrationFinance} from "script/DeployMigrationFinance.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {IUiPoolDataProviderV3} from "@aave-v3-periphery/contracts/misc/interfaces/IUiPoolDataProviderV3.sol";
import {ICreditDelegationToken} from "@aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {InteractWithTeleportAaveV3} from "src/InteractWithTeleportAaveV3.sol";

contract MigrationFinanceTest is Test {
    /**
     * Events
     */

    address public USER_1 = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)
    address public USER_2 = 0xC5e0B6E472dDE70eCEfFa4c568Bd52f2A7a1632A; // account 5 metamask dev
    TeleportAaveV3 public teleportAaveV3;
    HelperConfig helperConfig;
    InteractWithTeleportAaveV3 interactWithTeleportAaveV3;

    IPoolAddressesProvider iPoolAddressProvider;
    IPoolDataProvider iPoolDataProvider;
    IPool iPool;
    uint256 deployerKey;

    address usdt = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
    address usdc = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address eurs = 0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E;
    address link = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;

    function setUp() public {
        DeployMigrationFinance migrationFinanceDeployer = new DeployMigrationFinance();
        (teleportAaveV3, helperConfig, interactWithTeleportAaveV3) = migrationFinanceDeployer.run();
        (iPoolAddressProvider, iPoolDataProvider, iPool, deployerKey) = helperConfig.activeNetworkConfig();
    }

    /* private function
    function testGetAaveReserveTokenList() public view {
        address[] memory aaveReserveTokenList = interactWithTeleportAaveV3.getAaveMarketReserveTokenList();
        for (uint256 i = 0; i < aaveReserveTokenList.length; i++) {
            console.log("aaveReserveTokenList", aaveReserveTokenList[i]);
        }
        assert(aaveReserveTokenList.length > 0);
    }
    */

    /* private function
    function testGetAaveUserDataForAllAsset() public view {
        address[] memory aaveReserveTokenList = interactWithTeleportAaveV3.getAaveMarketReserveTokenList();

        for (uint256 i = 0; i < aaveReserveTokenList.length; i++) {
            address reserveToken = aaveReserveTokenList[i];
            InteractWithTeleportAaveV3.AaveUserDataOnOneAsset memory aaveUserDataOnOneAsset =
                interactWithTeleportAaveV3.getAavePositionOfUserByAsset(reserveToken, USER_1);
            console.log("------------------- ", ERC20(reserveToken).symbol(), " -------------------"); // remove all console.log before prod
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
    }*/
    /* private function
    function testGetAaveAllUserPositions() public view {
        InteractWithTeleportAaveV3.AaveUserDataList memory aaveUserDataList =
            interactWithTeleportAaveV3.getAaveUserDataForAllAssets(USER_1);

        for (uint256 i = 0; i < aaveUserDataList.tokensAmountsThatUserVariableBorrowedFromAave.length; i++) {
            // remove all console.log before prod
            console.log(
                "------------------- ", ERC20(aaveUserDataList.aaveReserveTokenList[i]).symbol(), " -------------------"
            );
            console.log("aaveUserDataList.aaveReserveTokenList", aaveUserDataList.aaveReserveTokenList[i]);
            console.log(
                "aaveUserDataList.tokensAmountsThatUserVariableBorrowedFromAave",
                aaveUserDataList.tokensAmountsThatUserVariableBorrowedFromAave[i]
            );
            console.log(
                "aaveUserDataList.tokensAmountThatUserStableBorrowedFromAave",
                aaveUserDataList.tokensAmountThatUserStableBorrowedFromAave[i]
            );
            console.log(
                "aaveUserDataList.tokensAmountsThatUserDepositedInAave",
                aaveUserDataList.tokensAmountsThatUserDepositedInAave[i]
            );
            console.log(
                "aaveUserDataList.areTokensCollateralThatUserDepositedInAave",
                aaveUserDataList.areTokensCollateralThatUserDepositedInAave[i]
            );

            console.log("______________________________________________________________");
        }
    }*/

    function testRequestFlashLoan() public {
        bytes memory params = abi.encode("");
        address[] memory assetsToBorrow = new address[](3);
        uint256[] memory amountsToBorrow = new uint256[](3);
        uint256[] memory interestRateModes = new uint256[](3);
        assetsToBorrow[0] = usdt;
        assetsToBorrow[1] = usdc;
        assetsToBorrow[2] = link;

        amountsToBorrow[0] = 100002700;
        amountsToBorrow[1] = 2000e6;
        amountsToBorrow[2] = 629951073162322;
        interestRateModes[0] = 0; // no open debt. (amount+fee must be paid in this case or revert)
        interestRateModes[1] = 0; //  no open debt. (amount+fee must be paid in this case or revert)
        interestRateModes[2] = 0; // no open debt. (amount+fee must be paid in this case or revert)
        vm.startPrank(USER_1);
        IERC20(usdt).transfer(address(teleportAaveV3), 100e6);
        IERC20(usdc).transfer(address(teleportAaveV3), 200e6);
        IERC20(link).transfer(address(teleportAaveV3), 1e18);

        uint16 referralCode = 0;
        // function requestFlashLoan is currently private
        /* teleportAaveV3.requestFlashLoan(
            address(teleportAaveV3),
            assetsToBorrow,
            amountsToBorrow,
            interestRateModes,
            address(teleportAaveV3),
            params,
            referralCode
        );*/
        vm.stopPrank();
    }
    /* need to be refactored
    function testMoveAavePositionToAnotherWallet() external {
        InteractWithTeleportAaveV3.AaveUserDataList memory aaveUser1DataList =
            interactWithTeleportAaveV3.getAaveUserDataForAllAssets(USER_1);
        InteractWithTeleportAaveV3.AaveUserDataList memory aaveUser2DataList =
            interactWithTeleportAaveV3.getAaveUserDataForAllAssets(USER_2);

        console.log("-----------------BEFORE FLASHLOAN ------------------");
        for (uint256 i = 0; i < aaveUser1DataList.tokensAmountsThatUserVariableBorrowedFromAave.length; i++) {
            // remove all console.log before prod

            console.log(
                "------------------- ",
                ERC20(aaveUser1DataList.aaveReserveTokenList[i]).symbol(),
                " -------------------"
            );
            console.log(
                "user 1 debt",
                aaveUser1DataList.tokensAmountsThatUserVariableBorrowedFromAave[i],
                " | user 2 debt",
                aaveUser2DataList.tokensAmountsThatUserVariableBorrowedFromAave[i]
            );
            console.log(
                "user 1 aToken",
                aaveUser1DataList.tokensAmountsThatUserDepositedInAave[i],
                " | user 2 aToken",
                aaveUser2DataList.tokensAmountsThatUserDepositedInAave[i]
            );
        }
        (address[] memory assetsBorrowed, uint256[] memory amountsBorrowed, uint256[] memory interestRateModes) =
            interactWithTeleportAaveV3.getAssetsToBorrowFromFLToRepayAaveDebt(aaveUser1DataList);
        vm.startPrank(USER_2);
        for (uint256 i = 0; i < assetsBorrowed.length; i++) {
            address variableDebtToken = interactWithTeleportAaveV3.getVariableDebtToken(assetsBorrowed[i]);
            // amountBorrowed + fee (2%) // approximatively
            uint256 amountToBorrow = amountsBorrowed[i] + (amountsBorrowed[i] * 2) / 100;
            ICreditDelegationToken(variableDebtToken).approveDelegation(address(teleportAaveV3), amountToBorrow);
        }
        vm.stopPrank();

        (address[] memory aTokenAssetsToMove, uint256[] memory aTokenAmountsToMove) =
            interactWithTeleportAaveV3.getATokenAssetToMoveToDestinationWallet(USER_1);
        vm.startBroadcast(USER_1);
        for (uint256 i = 0; i < aTokenAssetsToMove.length; i++) {
            IERC20(aTokenAssetsToMove[i]).approve(address(teleportAaveV3), aTokenAmountsToMove[i]);
        }

        teleportAaveV3.moveAavePositionToAnotherWallet(
            USER_1, USER_2, assetsBorrowed, amountsBorrowed, interestRateModes, aTokenAssetsToMove, aTokenAmountsToMove
        );
        vm.stopBroadcast();

        aaveUser1DataList = interactWithTeleportAaveV3.getAaveUserDataForAllAssets(USER_1);
        aaveUser2DataList = interactWithTeleportAaveV3.getAaveUserDataForAllAssets(USER_2);

        console.log("-----------------AFTER FLASHLOAN ------------------");
        for (uint256 i = 0; i < aaveUser1DataList.tokensAmountsThatUserVariableBorrowedFromAave.length; i++) {
            // remove all console.log before prod

            console.log(
                "------------------- ",
                ERC20(aaveUser1DataList.aaveReserveTokenList[i]).symbol(),
                " -------------------"
            );
            console.log(
                "user 1 debt",
                aaveUser1DataList.tokensAmountsThatUserVariableBorrowedFromAave[i],
                " | user 2 debt",
                aaveUser2DataList.tokensAmountsThatUserVariableBorrowedFromAave[i]
            );
            console.log(
                "user 1 aToken",
                aaveUser1DataList.tokensAmountsThatUserDepositedInAave[i],
                " | user 2 aToken",
                aaveUser2DataList.tokensAmountsThatUserDepositedInAave[i]
            );
        }
    }*/

    function testBorrowOnBehalf() public {
        uint256 amount = 0.00063434896262961 ether;

        vm.startBroadcast(USER_2);
        IERC20(link).approve(address(teleportAaveV3), amount);
        IERC20(link).approve(USER_1, amount);
        ICreditDelegationToken(0x34a4d932E722b9dFb492B9D8131127690CE2430B).approveDelegation(
            address(teleportAaveV3), amount
        );
        ICreditDelegationToken(0x34a4d932E722b9dFb492B9D8131127690CE2430B).approveDelegation(USER_1, amount);
        vm.startBroadcast();

        vm.startBroadcast();
        iPool.borrow(link, amount, 2, 0, USER_2);
        vm.stopBroadcast();
    }
    /* private function
    function testGetATokenAssetToMoveToDestinationWallet() public view {
        (address[] memory aTokenAssetsToMove, uint256[] memory aTokenAmountsToMove) =
            interactWithTeleportAaveV3.getATokenAssetToMoveToDestinationWallet(USER_1);
        console.log("aTokenAssetsToMove", aTokenAssetsToMove.length);
        console.log("aTokenAmountsToMove", aTokenAmountsToMove.length);
    }

    function testMoveWalletWithInteractionContract() public {
        InteractWithTeleportAaveV3.AaveUserDataList memory aaveUser1DataList =
            interactWithTeleportAaveV3.getAaveUserDataForAllAssets(USER_1);

        (address[] memory assetsBorrowed, uint256[] memory amountsBorrowed,) =
            interactWithTeleportAaveV3.getAssetsToBorrowFromFLToRepayAaveDebt(aaveUser1DataList);
        vm.startBroadcast(USER_2);
        for (uint256 i = 0; i < assetsBorrowed.length; i++) {
            address variableDebtToken = interactWithTeleportAaveV3.getVariableDebtToken(assetsBorrowed[i]);
            // amountBorrowed + fee (2%) // approximatively
            uint256 amountToBorrow = amountsBorrowed[i] + (amountsBorrowed[i] * 2) / 100;
            ICreditDelegationToken(variableDebtToken).approveDelegation(address(teleportAaveV3), amountToBorrow);
            console.log("user 2 approve delegation for", variableDebtToken, "amount", amountToBorrow);
        }

        vm.stopBroadcast();
        vm.startBroadcast(USER_1);
        (address[] memory aTokenAssetsToMove, uint256[] memory aTokenAmountsToMove) =
            interactWithTeleportAaveV3.getATokenAssetToMoveToDestinationWallet(USER_1);
        for (uint256 i = 0; i < aTokenAssetsToMove.length; i++) {
            IERC20(aTokenAssetsToMove[i]).approve(address(teleportAaveV3), aTokenAmountsToMove[i]);
            console.log("user 1 approve", aTokenAssetsToMove[i], "amount", aTokenAmountsToMove[i]);
        }
        for (uint256 i = 0; i < aaveUser1DataList.aaveReserveTokenList.length; i++) {
            if (
                aaveUser1DataList.areTokensCollateralThatUserDepositedInAave[i]
                    && aaveUser1DataList.tokensAmountsThatUserDepositedInAave[i] > 0
            ) {
                iPool.setUserUseReserveAsCollateral(aaveUser1DataList.aaveReserveTokenList[i], true);
            }
        }
        interactWithTeleportAaveV3.teleportAaveV3PositionsBetweenWallets(USER_1, USER_2);
        vm.stopBroadcast();
    } */

    function testSetUserUseReserveAsCollateral() public {
        vm.startBroadcast(USER_1);
        iPool.setUserUseReserveAsCollateral(usdc, true); // usdt is not permitted as collateral

        vm.stopBroadcast();
    }
}
