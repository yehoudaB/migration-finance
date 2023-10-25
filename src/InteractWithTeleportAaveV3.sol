//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {TeleportAaveV3} from "src/TeleportAaveV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InteractWithTeleportAaveV3 {
    TeleportAaveV3 teleportAaveV3;

    IPoolDataProvider iPoolDataProvider;
    IPool iPool;

    struct AaveUserDataOnOneAsset {
        uint256 currentATokenBalance;
        uint256 currentStableDebt;
        uint256 currentVariableDebt;
        uint256 principalStableDebt;
        uint256 scaledVariableDebt;
        uint256 stableBorrowRate;
        uint256 liquidityRate;
        uint40 stableRateLastUpdated;
        bool usageAsCollateralEnabled;
    }

    struct AaveUserDataList {
        address[] aaveReserveTokenList;
        uint256[] tokensAmountsThatUserDepositedInAave;
        bool[] areTokensCollateralThatUserDepositedInAave;
        uint256[] tokensAmountThatUserStableBorrowedFromAave;
        uint256[] tokensAmountsThatUserVariableBorrowedFromAave;
    }

    constructor(IPoolDataProvider _iPoolDataProvider, IPool _iPool, TeleportAaveV3 _teleportAaveV3) {
        iPoolDataProvider = _iPoolDataProvider;
        iPool = _iPool;
        teleportAaveV3 = _teleportAaveV3;
    }

    /*
    * @notice this function is used to migrate an Aave position from one wallet to another
    * @param _from the address of the wallet that has the Aave position
    * @param _to the address of the wallet that will receive the Aave position
    * @dev the _to wallet had to approve the TeleportAaveV3 to borrow on its behalf (debtToken approveDelegation method )
    *  of amount = the total amount of debt of the _from wallet + FL fee 
    * @dev Also the _from wallet had to approve the TeleportAaveV3 to move the aToken (deposited token) to the _to wallet
    */
    function teleportAaveV3PositionsBetweenWallets(address _to) external {
        InteractWithTeleportAaveV3.AaveUserDataList memory aaveUser1DataList = _getAaveUserDataForAllAssets(msg.sender);
        (address[] memory assetsBorrowed, uint256[] memory amountsBorrowed, uint256[] memory interestRateModes) =
            _getAssetsToBorrowFromFLToRepayAaveDebt(aaveUser1DataList);

        (address[] memory aTokenAssetsToMove, uint256[] memory aTokenAmountsToMove) =
            _getATokenAssetToMoveToDestinationWallet(msg.sender);

        teleportAaveV3.moveAavePositionToAnotherWallet(
            msg.sender, _to, assetsBorrowed, amountsBorrowed, interestRateModes, aTokenAssetsToMove, aTokenAmountsToMove
        );
    }

    /*
    * @notice this function returns the postion (deposit, borrow) of an user for in the Aave market for all assets
    * @param _user the address of the user 
    * 
    */
    function _getAaveUserDataForAllAssets(address _user) private view returns (AaveUserDataList memory) {
        address[] memory aaveReserveTokenList = _getAaveMarketReserveTokenList();
        uint256[] memory tokensAmountsThatUserDepositedInAave = new uint256[](aaveReserveTokenList.length);
        bool[] memory areTokensCollateralThatUserDepositedInAave = new bool[](aaveReserveTokenList.length);
        uint256[] memory tokensAmountThatUserStableBorrowedFromAave = new uint256[](aaveReserveTokenList.length);
        uint256[] memory tokensAmountsThatUserVariableBorrowedFromAave = new uint256[](aaveReserveTokenList.length);

        for (uint256 i = 0; i < aaveReserveTokenList.length; i++) {
            AaveUserDataOnOneAsset memory aaveUserDataOnOneAsset =
                _getAavePositionOfUserByAsset(aaveReserveTokenList[i], _user);
            if (aaveUserDataOnOneAsset.currentATokenBalance > 0) {
                tokensAmountsThatUserDepositedInAave[i] = aaveUserDataOnOneAsset.currentATokenBalance;
                areTokensCollateralThatUserDepositedInAave[i] = aaveUserDataOnOneAsset.usageAsCollateralEnabled;
            }
            if (aaveUserDataOnOneAsset.currentStableDebt > 0) {
                tokensAmountThatUserStableBorrowedFromAave[i] = aaveUserDataOnOneAsset.currentStableDebt;
            }
            if (aaveUserDataOnOneAsset.currentVariableDebt > 0) {
                tokensAmountsThatUserVariableBorrowedFromAave[i] = aaveUserDataOnOneAsset.currentVariableDebt;
            }
        }
        return AaveUserDataList({
            aaveReserveTokenList: aaveReserveTokenList,
            tokensAmountsThatUserDepositedInAave: tokensAmountsThatUserDepositedInAave,
            areTokensCollateralThatUserDepositedInAave: areTokensCollateralThatUserDepositedInAave,
            tokensAmountThatUserStableBorrowedFromAave: tokensAmountThatUserStableBorrowedFromAave,
            tokensAmountsThatUserVariableBorrowedFromAave: tokensAmountsThatUserVariableBorrowedFromAave
        });
    }

    /*
    * @notice this function returns the postion (deposit, borrow) of an user for one asset in the Aave market
    * @param _asset the address of the asset
    * @param _user the address of the user
    * @dev this function is used by getAaveUserDataForAllAssets
    */
    function _getAavePositionOfUserByAsset(address _asset, address _user)
        private
        view
        returns (AaveUserDataOnOneAsset memory)
    {
        (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        ) = iPoolDataProvider.getUserReserveData(_asset, _user);
        return AaveUserDataOnOneAsset({
            currentATokenBalance: currentATokenBalance,
            currentStableDebt: currentStableDebt,
            currentVariableDebt: currentVariableDebt,
            principalStableDebt: principalStableDebt,
            scaledVariableDebt: scaledVariableDebt,
            stableBorrowRate: stableBorrowRate,
            liquidityRate: liquidityRate,
            stableRateLastUpdated: stableRateLastUpdated,
            usageAsCollateralEnabled: usageAsCollateralEnabled
        });
    }

    /**
     *  @notice this function prepare the array of asset to borrow from FlashLoan to repay Aave debt for an user
     *  @param _aaveUserDataList the data of the Aave position to migrate : for gas efficiency you need to feed this variable with
     *                           only the data of the Aave position you want to migrate
     */
    function _getAssetsToBorrowFromFLToRepayAaveDebt(AaveUserDataList memory _aaveUserDataList)
        private
        pure
        returns (address[] memory assetsBorrowed, uint256[] memory amountsBorrowed, uint256[] memory interestRateModes)
    {
        uint256 lengthOfassetsToBorrowArray = 0;

        for (uint256 i = 0; i < _aaveUserDataList.aaveReserveTokenList.length; i++) {
            if (_aaveUserDataList.tokensAmountsThatUserVariableBorrowedFromAave[i] > 0) {
                lengthOfassetsToBorrowArray++;
            }
        }
        assetsBorrowed = new address[](lengthOfassetsToBorrowArray);
        amountsBorrowed = new uint256[](lengthOfassetsToBorrowArray);
        interestRateModes = new uint256[](lengthOfassetsToBorrowArray);
        uint256 indexOfAssetToBorrow = 0;
        for (uint256 i = 0; i < _aaveUserDataList.aaveReserveTokenList.length; i++) {
            if (_aaveUserDataList.tokensAmountsThatUserVariableBorrowedFromAave[i] > 0) {
                assetsBorrowed[indexOfAssetToBorrow] = _aaveUserDataList.aaveReserveTokenList[i];
                amountsBorrowed[indexOfAssetToBorrow] =
                    _aaveUserDataList.tokensAmountsThatUserVariableBorrowedFromAave[i];
                interestRateModes[indexOfAssetToBorrow] = 0;
                indexOfAssetToBorrow++;
            }
        }
    }

    /*
    * @notice this function prepare the array of AToken asset (represent deposited tokens) to move from the _from wallet to the _to wallet
    * @param _from the address of the wallet that has the Aave position
    * @dev this function is used by teleportAaveV3PositionsBetweenWallets to prepare the data to send to the TeleportAaveV3 contract
    */
    function _getATokenAssetToMoveToDestinationWallet(address _from)
        private
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory reserveTokensList = _getAaveMarketReserveTokenList();
        uint256 lengthOfAssetToMoveArray;
        for (uint256 i = 0; i < reserveTokensList.length; i++) {
            address aToken = _getAToken(reserveTokensList[i]);
            if (IERC20(aToken).balanceOf(_from) > 0) {
                lengthOfAssetToMoveArray++;
            }
        }
        address[] memory aTokenAssetsToMove = new address[](lengthOfAssetToMoveArray);
        uint256[] memory aTokenAmountsToMove = new uint256[](lengthOfAssetToMoveArray);
        uint256 indexOfATokenToMove = 0;
        for (uint256 i = 0; i < reserveTokensList.length; i++) {
            address aToken = _getAToken(reserveTokensList[i]);

            if (IERC20(aToken).balanceOf(_from) > 0) {
                aTokenAssetsToMove[indexOfATokenToMove] = aToken;
                aTokenAmountsToMove[indexOfATokenToMove] = IERC20(aToken).balanceOf(_from);
                indexOfATokenToMove++;
            }
        }
        return (aTokenAssetsToMove, aTokenAmountsToMove);
    }

    function _getATokenAssetToMoveToDestinationWallet2(address _from)
        private
        view
        returns (address[] memory, uint256[] memory)
    {
        IPoolDataProvider.TokenData[] memory aTokenList = _getAaveMarketATokenList();
        uint256 lengthOfAssetToMoveArray;
        for (uint256 i = 0; i < aTokenList.length; i++) {
            address aToken = aTokenList[i].tokenAddress;
            if (IERC20(aToken).balanceOf(_from) > 0) {
                lengthOfAssetToMoveArray++;
            }
        }
        address[] memory aTokenAssetsToMove = new address[](lengthOfAssetToMoveArray);
        uint256[] memory aTokenAmountsToMove = new uint256[](lengthOfAssetToMoveArray);
        uint256 indexOfATokenToMove = 0;
        for (uint256 i = 0; i < aTokenList.length; i++) {
            address aToken = aTokenList[i].tokenAddress;
            if (IERC20(aToken).balanceOf(_from) > 0) {
                aTokenAssetsToMove[indexOfATokenToMove] = aToken;
                aTokenAmountsToMove[indexOfATokenToMove] = IERC20(aToken).balanceOf(_from);
                indexOfATokenToMove++;
            }
        }
        return (aTokenAssetsToMove, aTokenAmountsToMove);
    }

    function _getAaveMarketATokenList() private view returns (IPoolDataProvider.TokenData[] memory) {
        return iPoolDataProvider.getAllATokens();
    }

    function _getAaveMarketReserveTokenList() private view returns (address[] memory) {
        return iPool.getReservesList();
    }

    function _getAToken(address _tokenReserve) private view returns (address) {
        return iPool.getReserveData(_tokenReserve).aTokenAddress;
    }

    function _getVariableDebtToken(address _tokenReserve) private view returns (address) {
        return iPool.getReserveData(_tokenReserve).variableDebtTokenAddress;
    }
}
