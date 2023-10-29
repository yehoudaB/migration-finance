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
        address teleportAaveV3Address = 0x25E30Eb1AD42e7176B9711A169D1f2d135A88C2B;
        address prepareTeleportAaveV3Address = 0x5efADa3363f4040A032F4De4c1221ac6c2B73525;

        PrepareTeleportAaveV3 prepareTeleportAaveV3 = PrepareTeleportAaveV3(prepareTeleportAaveV3Address);
        TeleportAaveV3 teleportAaveV3 = TeleportAaveV3(teleportAaveV3Address);
        teleport(teleportAaveV3, prepareTeleportAaveV3);
    }

    function teleport(TeleportAaveV3 teleportAaveV3, PrepareTeleportAaveV3 prepareTeleportAaveV3) public {
        address destinationAddress = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)
        address sourceAddress = 0xC5e0B6E472dDE70eCEfFa4c568Bd52f2A7a1632A; // account 5 metamask dev

        (
            address[] memory assetsBorrowed,
            uint256[] memory amountsBorrowed,
            uint256[] memory interestRateModes,
            address[] memory aTokenAssetsToMove,
            uint256[] memory aTokenAmountsToMove
        ) = getParamsToFillForMovingPosition(prepareTeleportAaveV3, sourceAddress);
        uint256 sourceAddressPK = vm.deriveKey(vm.envString("MNEMONIC"), 1);
        uint256 destinationAddressPK = vm.deriveKey(vm.envString("MNEMONIC"), 0);

        vm.startBroadcast(destinationAddressPK);

        giveAllowanceToTeleportToBorrowOnBehalfOfDestinationWallet(
            assetsBorrowed, amountsBorrowed, teleportAaveV3, prepareTeleportAaveV3
        );
        vm.stopBroadcast();
        vm.startBroadcast(sourceAddressPK);
        giveAllowanceToTeleportToMoveATokenOnBehalfOfSourceWallet(
            aTokenAssetsToMove, aTokenAmountsToMove, teleportAaveV3
        );
        teleportAaveV3.moveAavePositionToAnotherWallet(
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

    function getParamsToFillForMovingPosition(PrepareTeleportAaveV3 _prepareTeleportAaveV3, address _sourceWallet)
        public
        view
        returns (
            address[] memory assetsBorrowed,
            uint256[] memory amountsBorrowed,
            uint256[] memory interestRateModes,
            address[] memory aTokenAssetsToMove,
            uint256[] memory aTokenAmountsToMove
        )
    {
        (assetsBorrowed, amountsBorrowed, interestRateModes, aTokenAssetsToMove, aTokenAmountsToMove) =
            _prepareTeleportAaveV3.getAllAaveV3PositionsToMoveViaTeleportAaveV3(_sourceWallet);
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
