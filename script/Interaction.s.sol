//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InteractWithTeleportAaveV3} from "src/InteractWithTeleportAaveV3.sol";
import {TeleportAaveV3} from "src/TeleportAaveV3.sol";
import {ICreditDelegationToken} from "@aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";

import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract Interaction is Script {
    address public USER_1 = 0x3e122A3dB43d225DD5BFFD929AD4176ce69117E0; // account 1 metamask dev (same as .env private key)
    address public USER_2 = 0xC5e0B6E472dDE70eCEfFa4c568Bd52f2A7a1632A; // account 5 metamask dev

    function teleport(address teleportAaveV3Address, address interactWithTeleportAaveV3Address) public {
        InteractWithTeleportAaveV3 interactWithTeleportAaveV3 =
            InteractWithTeleportAaveV3(interactWithTeleportAaveV3Address);
        TeleportAaveV3 teleportAaveV3 = TeleportAaveV3(teleportAaveV3Address);
        InteractWithTeleportAaveV3.AaveUserDataList memory aaveUser1DataList =
            interactWithTeleportAaveV3.getAaveUserDataForAllAssets(USER_1);

        (address[] memory assetsBorrowed, uint256[] memory amountsBorrowed,) =
            interactWithTeleportAaveV3.getAssetsToBorrowFromFLToRepayAaveDebt(aaveUser1DataList);
        vm.startBroadcast(USER_2);
        for (uint256 i = 0; i < assetsBorrowed.length; i++) {
            address variableDebtToken = interactWithTeleportAaveV3.getVariableDebtToken(assetsBorrowed[i]);
            // amountBorrowed + fee (2%) // approximatively
            uint256 amountToBorrow = amountsBorrowed[i] + (amountsBorrowed[i] * 2) / 100;
            ICreditDelegationToken(variableDebtToken).approveDelegation(
                address(teleportAaveV3), amountToBorrow + 9999000000
            );
            console.log("user 2 approve delegation for", variableDebtToken, "amount", amountToBorrow + 9999000000);
        }
        vm.stopBroadcast();
        vm.startBroadcast(USER_1);
        (address[] memory aTokenAssetsToMove, uint256[] memory aTokenAmountsToMove) =
            interactWithTeleportAaveV3.getATokenAssetToMoveToDestinationWallet(USER_1);
        for (uint256 i = 0; i < aTokenAssetsToMove.length; i++) {
            IERC20(aTokenAssetsToMove[i]).approve(address(teleportAaveV3), aTokenAmountsToMove[i] + 9999000000);
            console.log("user 1 approve", aTokenAssetsToMove[i], "amount", aTokenAmountsToMove[i] + 9999000000);
        }
        interactWithTeleportAaveV3.teleportAaveV3PositionsBetweenWallets(USER_1, USER_2);
        vm.stopBroadcast();
    }

    function run() external {
        address teleportAaveV3Address = 0xdf65CECbE8df607789620486F68c01076b66ba49;
        address interactWithTeleportAaveV3Address = 0x06b22eDF4d5fD095789F793f16De2e52907589CC;

        teleport(teleportAaveV3Address, interactWithTeleportAaveV3Address);
    }
}
