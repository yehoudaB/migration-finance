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

    function teleportAaveV3PositionsBetweenWallets(address _from, address _to) public {
        (address[] memory aTokenAssetsToMove, uint256[] memory aTokenAmountsToMove) =
            getATokenAssetToMoveToDestinationWallet(_from);
        (address[] memory assetsBorrowed, uint256[] memory amountsBorrowed, uint256[] memory interestRateModes) =
            getAssetsToBorrowFromFLToRepayAaveDebt(getAaveUserDataForAllAssets(_from));
        teleportAaveV3.moveAavePositionToAnotherWallet(
            _from, _to, assetsBorrowed, amountsBorrowed, interestRateModes, aTokenAssetsToMove, aTokenAmountsToMove
        );
    }

    /*
    * @notice this function returns the postion (deposit, borrow) of an user for in the Aave market for all assets
    * @param _user the address of the user 
    * 
    */
    function getAaveUserDataForAllAssets(address _user) public view returns (AaveUserDataList memory) {
        address[] memory aaveReserveTokenList = getAaveMarketReserveTokenList();
        uint256[] memory tokensAmountsThatUserDepositedInAave = new uint256[](aaveReserveTokenList.length);
        bool[] memory areTokensCollateralThatUserDepositedInAave = new bool[](aaveReserveTokenList.length);
        uint256[] memory tokensAmountThatUserStableBorrowedFromAave = new uint256[](aaveReserveTokenList.length);
        uint256[] memory tokensAmountsThatUserVariableBorrowedFromAave = new uint256[](aaveReserveTokenList.length);

        for (uint256 i = 0; i < aaveReserveTokenList.length; i++) {
            AaveUserDataOnOneAsset memory aaveUserDataOnOneAsset =
                getAavePositionOfUserByAsset(aaveReserveTokenList[i], _user);
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
    function getAavePositionOfUserByAsset(address _asset, address _user)
        public
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
    function getAssetsToBorrowFromFLToRepayAaveDebt(AaveUserDataList memory _aaveUserDataList)
        public
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
    function getATokenAssetToMoveToDestinationWallet(address _from)
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory reserveTokensList = getAaveMarketReserveTokenList();
        uint256 lengthOfAssetToMoveArray;
        for (uint256 i = 0; i < reserveTokensList.length; i++) {
            address aToken = getAToken(reserveTokensList[i]);
            if (IERC20(aToken).balanceOf(_from) > 0) {
                lengthOfAssetToMoveArray++;
            }
        }
        address[] memory aTokenAssetsToMove = new address[](lengthOfAssetToMoveArray);
        uint256[] memory aTokenAmountsToMove = new uint256[](lengthOfAssetToMoveArray);
        uint256 indexOfATokenToMove = 0;
        for (uint256 i = 0; i < reserveTokensList.length; i++) {
            address aToken = getAToken(reserveTokensList[i]);

            if (IERC20(aToken).balanceOf(_from) > 0) {
                aTokenAssetsToMove[indexOfATokenToMove] = aToken;
                aTokenAmountsToMove[indexOfATokenToMove] = IERC20(aToken).balanceOf(_from);
                indexOfATokenToMove++;
            }
        }
        return (aTokenAssetsToMove, aTokenAmountsToMove);
    }

    function getATokenAssetToMoveToDestinationWallet2(address _from)
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        IPoolDataProvider.TokenData[] memory aTokenList = getAaveMarketATokenList();
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

    function getAaveMarketATokenList() public view returns (IPoolDataProvider.TokenData[] memory) {
        return iPoolDataProvider.getAllATokens();
    }

    function getAaveMarketReserveTokenList() public view returns (address[] memory) {
        return iPool.getReservesList();
    }

    function getAToken(address _tokenReserve) public view returns (address) {
        return iPool.getReserveData(_tokenReserve).aTokenAddress;
    }

    function getVariableDebtToken(address _tokenReserve) public view returns (address) {
        return iPool.getReserveData(_tokenReserve).variableDebtTokenAddress;
    }
}
