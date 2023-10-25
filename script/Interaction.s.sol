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

    function teleport(address teleportAaveV3Address, address interactWithTeleportAaveV3Address, IPool iPool) public {
        uint256 user1PrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);
        uint256 user2PrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 1);
        InteractWithTeleportAaveV3 interactWithTeleportAaveV3 =
            InteractWithTeleportAaveV3(interactWithTeleportAaveV3Address);
        TeleportAaveV3 teleportAaveV3 = TeleportAaveV3(teleportAaveV3Address);
        InteractWithTeleportAaveV3.AaveUserDataList memory aaveUser1DataList =
            interactWithTeleportAaveV3.getAaveUserDataForAllAssets(USER_1);

        (address[] memory assetsBorrowed, uint256[] memory amountsBorrowed,) =
            interactWithTeleportAaveV3.getAssetsToBorrowFromFLToRepayAaveDebt(aaveUser1DataList);
        vm.startBroadcast(user2PrivateKey);
        for (uint256 i = 0; i < assetsBorrowed.length; i++) {
            address variableDebtToken = interactWithTeleportAaveV3.getVariableDebtToken(assetsBorrowed[i]);
            // amountBorrowed + fee (2%) // approximatively
            uint256 amountToBorrow = amountsBorrowed[i] + (amountsBorrowed[i] * 2) / 100;
            ICreditDelegationToken(variableDebtToken).approveDelegation(address(teleportAaveV3), amountToBorrow * 2);
            console.log("user 2 approve delegation for", variableDebtToken, "amount", amountToBorrow);
        }
        vm.stopBroadcast();
        vm.startBroadcast(user1PrivateKey);
        (address[] memory aTokenAssetsToMove, uint256[] memory aTokenAmountsToMove) =
            interactWithTeleportAaveV3.getATokenAssetToMoveToDestinationWallet(USER_1);
        for (uint256 i = 0; i < aTokenAssetsToMove.length; i++) {
            IERC20(aTokenAssetsToMove[i]).approve(address(teleportAaveV3), aTokenAmountsToMove[i] * 2);
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
    }

    function run() external {
        HelperConfig helperConfig = new  HelperConfig();
        (,, IPool iPool,) = helperConfig.activeNetworkConfig();
        address teleportAaveV3Address = 0x25E30Eb1AD42e7176B9711A169D1f2d135A88C2B;
        address interactWithTeleportAaveV3Address = 0x5efADa3363f4040A032F4De4c1221ac6c2B73525;
        teleport(teleportAaveV3Address, interactWithTeleportAaveV3Address, iPool);
    }
}
