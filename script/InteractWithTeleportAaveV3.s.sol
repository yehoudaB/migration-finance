//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PrepareTeleportAaveV3} from "src/PrepareTeleportAaveV3.sol";
import {TeleportAaveV3} from "src/TeleportAaveV3.sol";
import {ICreditDelegationToken} from "@aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";

import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract InteractWithTeleportAaveV3 is Script {
    function run() external {
        address teleportAaveV3Address = 0x5d6085935AD04FBACC9D025Ba989bEAE91f94090;
        address prepareTeleportAaveV3Address = 0xe8f617fbc78A6699dEa376fCE4695571044233ba;

        PrepareTeleportAaveV3 prepareTeleportAaveV3 = PrepareTeleportAaveV3(prepareTeleportAaveV3Address);
        TeleportAaveV3 teleportAaveV3 = TeleportAaveV3(teleportAaveV3Address);
        teleport(teleportAaveV3, prepareTeleportAaveV3);
    }

    function teleport(TeleportAaveV3 _teleportAaveV3, PrepareTeleportAaveV3 _prepareTeleportAaveV3) public {
        address sourceAddress = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)
        address destinationAddress = 0xC5e0B6E472dDE70eCEfFa4c568Bd52f2A7a1632A; // account 5 metamask dev
        uint256 sourceAddressPK = vm.deriveKey(vm.envString("MNEMONIC"), 0);
        uint256 destinationAddressPK = vm.deriveKey(vm.envString("MNEMONIC"), 1);
        (
            address[] memory assetsBorrowed,
            uint256[] memory amountsBorrowed,
            uint256[] memory interestRateModes,
            address[] memory aTokenAssetsToMove,
            uint256[] memory aTokenAmountsToMove
        ) = _prepareTeleportAaveV3.getAllAaveV3PositionsToMoveViaTeleportAaveV3(sourceAddress);

        vm.startBroadcast(destinationAddressPK);

        giveAllowanceToTeleportToBorrowOnBehalfOfDestinationWallet(
            assetsBorrowed, amountsBorrowed, _teleportAaveV3, _prepareTeleportAaveV3
        );
        vm.stopBroadcast();
        vm.startBroadcast(sourceAddressPK);
        giveAllowanceToTeleportToMoveATokenOnBehalfOfSourceWallet(
            aTokenAssetsToMove, aTokenAmountsToMove, _teleportAaveV3
        );
        _teleportAaveV3.moveAavePositionToAnotherWallet(
            sourceAddress,
            destinationAddress,
            assetsBorrowed,
            amountsBorrowed,
            interestRateModes,
            aTokenAssetsToMove,
            aTokenAmountsToMove
        );
        vm.stopBroadcast();
    }

    /////////////////////////////////////////////////////////////////////
    ////////////////////////// APPROVAL FUNCTIONS ////////////////////////
    /* 
    *   @notice must be called by the destination wallet
    *   @param _assetsBorrowed the list of addresses of assets that the source swallet borrowed (we need to replicate them in the destination wallet)
    *   @param _amountsBorrowed the list of amounts that the source wallet borrowed
    */
    function giveAllowanceToTeleportToBorrowOnBehalfOfDestinationWallet(
        address[] memory _assetsBorrowed,
        uint256[] memory _amountsBorrowed,
        TeleportAaveV3 teleportAaveV3,
        PrepareTeleportAaveV3 prepareTeleportAaveV3
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
        uint256[] memory _aTokenAmountsToMove,
        TeleportAaveV3 teleportAaveV3
    ) public {
        for (uint256 i = 0; i < _aTokenAssetsToMove.length; i++) {
            IERC20(_aTokenAssetsToMove[i]).approve(address(teleportAaveV3), _aTokenAmountsToMove[i]);
        }
    }
}
