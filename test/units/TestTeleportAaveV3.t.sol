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

    address public USER_2 = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)
    address public USER_1 = 0xC5e0B6E472dDE70eCEfFa4c568Bd52f2A7a1632A; // account 5 metamask dev
    TeleportAaveV3 public teleportAaveV3;
    HelperConfig helperConfig;
    PrepareTeleportAaveV3 prepareTeleportAaveV3;
    InteractWithTeleportAaveV3 public interactWithTeleportAaveV3;

    IPoolAddressesProvider iPoolAddressProvider;
    IPoolDataProvider iPoolDataProvider;
    IPool iPool;
    uint256 deployerKey;

    address usdt = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
    address usdc = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address eurs = 0x6d906e526a4e2Ca02097BA9d0caA3c382F52278E;
    address link = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;

    function setUp() public {
        DeployTeleportFinance teleportFinanceDeployer = new DeployTeleportFinance();
        (teleportAaveV3, helperConfig, prepareTeleportAaveV3) = teleportFinanceDeployer.run();
        (iPoolAddressProvider, iPoolDataProvider, iPool, deployerKey) = helperConfig.activeNetworkConfig();
    }

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
    // private function

    function testGetATokenAssetToMoveToDestinationWallet() public view {
        (address[] memory aTokenAssetsToMove, uint256[] memory aTokenAmountsToMove) =
            prepareTeleportAaveV3._getATokenAssetToMoveToDestinationWallet(USER_1);
        console.log("aTokenAssetsToMove", aTokenAssetsToMove.length);
        console.log("aTokenAmountsToMove", aTokenAmountsToMove.length);
    }

    function testSetUserUseReserveAsCollateral() public {
        vm.startBroadcast(USER_1);
        // the user must have deposited this asset in the pool before calling this function
        iPool.setUserUseReserveAsCollateral(usdc, true); // usdt is not permitted as collateral
        vm.stopBroadcast();
    }

    function testGetAllAaveV3PositionsToMoveViaTeleportAaveV3() public view {
        (
            address[] memory assetsBorrowed,
            uint256[] memory amountsBorrowed,
            uint256[] memory interestRateModes,
            address[] memory aTokenAssetsToMove,
            uint256[] memory aTokenAmountsToMove,
        ) = prepareTeleportAaveV3.getAllAaveV3PositionsToMoveViaTeleportAaveV3(USER_2);
        for (uint256 i = 0; i < assetsBorrowed.length; i++) {
            console.log("assetsBorrowed", assetsBorrowed[i]);
            console.log("amountsBorrowed", amountsBorrowed[i]);
            console.log("interestRateModes", interestRateModes[i]);
        }
        for (uint256 i = 0; i < aTokenAssetsToMove.length; i++) {
            console.log("aTokenAssetsToMove", aTokenAssetsToMove[i]);
            console.log("aTokenAmountsToMove", aTokenAmountsToMove[i]);
        }
    }

    function testMoveAavePositions() public {
        (
            address[] memory assetsBorrowed,
            uint256[] memory amountsBorrowed,
            uint256[] memory interestRateModes,
            address[] memory aTokenAssetsToMove,
            uint256[] memory aTokenAmountsToMove,
        ) = prepareTeleportAaveV3.getAllAaveV3PositionsToMoveViaTeleportAaveV3(USER_1);

        vm.startBroadcast(USER_2);
        giveAllowanceToTeleportToBorrowOnBehalfOfDestinationWallet(assetsBorrowed, amountsBorrowed);
        vm.stopBroadcast();

        vm.startBroadcast(USER_1);
        giveAllowanceToTeleportToMoveATokenOnBehalfOfSourceWallet(aTokenAssetsToMove, aTokenAmountsToMove);

        teleportAaveV3.moveAavePositionToAnotherWallet(
            USER_1, USER_2, assetsBorrowed, amountsBorrowed, interestRateModes, aTokenAssetsToMove, aTokenAmountsToMove
        );
        vm.stopBroadcast();
    }

    /////////////////////////////////////////////////////////////////////
    ////////////////////////// APPROVAL FUNCTIONS ////////////////////////
    /////// those function are duplicated in InteractWithTeleportAaveV3.s.sol but it is needed for testing to not call from another contract but from the test contract
    /* 
    *   @notice must be called by the destination wallet
    *   @param _assetsBorrowed the list of addresses of assets that the source swallet borrowed (we need to replicate them in the destination wallet)
    *   @param _amountsBorrowed the list of amounts that the source wallet borrowed
    */
    function giveAllowanceToTeleportToBorrowOnBehalfOfDestinationWallet(
        address[] memory _assetsBorrowed,
        uint256[] memory _amountsBorrowed
    ) public {
        for (uint256 i = 0; i < _assetsBorrowed.length; i++) {
            address variableDebtToken = prepareTeleportAaveV3.getVariableDebtToken(_assetsBorrowed[i]);
            // amountBorrowed + fee (2%) // approximatively
            uint256 amountToBorrow = _amountsBorrowed[i] + (_amountsBorrowed[i] * 2) / 100;
            ICreditDelegationToken(variableDebtToken).approveDelegation(address(teleportAaveV3), amountToBorrow);
        }
    }

    /* 
    *   @notice must be called by the source wallet
    *   @param _aTokenAssetsToMove the list of addresses of aToken that the source wallet has (we need to move them to the destination wallet)
    *   @param _aTokenAmountsToMove the list of amounts of aToken that the source wallet has
    */
    function giveAllowanceToTeleportToMoveATokenOnBehalfOfSourceWallet(
        address[] memory _aTokenAssetsToMove,
        uint256[] memory _aTokenAmountsToMove
    ) public {
        for (uint256 i = 0; i < _aTokenAssetsToMove.length; i++) {
            IERC20(_aTokenAssetsToMove[i]).approve(address(teleportAaveV3), _aTokenAmountsToMove[i]);
        }
    }
}
