// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {MigrationFinance} from "src/MigrationFinance.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        IPoolAddressesProvider iPoolAddressProvider;
        IPoolDataProvider iPoolDataProvider;
        IPool iPool;
        uint256 deployerKey;
    }

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

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        }
        // for local testing we use a fork from sepolia localy (see README.md)
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        IPoolAddressesProvider iPoolAddressProvider = IPoolAddressesProvider(0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A);
        return NetworkConfig({
            iPoolAddressProvider: iPoolAddressProvider,
            iPoolDataProvider: IPoolDataProvider(iPoolAddressProvider.getPoolDataProvider()),
            iPool: IPool(iPoolAddressProvider.getPool()),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAaveMarketATokenList() public view returns (IPoolDataProvider.TokenData[] memory) {
        return activeNetworkConfig.iPoolDataProvider.getAllATokens();
    }

    function getAaveMarketReserveTokenList() public view returns (address[] memory) {
        return activeNetworkConfig.iPool.getReservesList();
    }

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
        ) = activeNetworkConfig.iPoolDataProvider.getUserReserveData(_asset, _user);
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

    function getAaveUserDataForAllAssets(address _user)
        public
        view
        returns (MigrationFinance.AaveUserDataList memory)
    {
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
        return MigrationFinance.AaveUserDataList({
            aaveReserveTokenList: aaveReserveTokenList,
            tokensAmountsThatUserDepositedInAave: tokensAmountsThatUserDepositedInAave,
            areTokensCollateralThatUserDepositedInAave: areTokensCollateralThatUserDepositedInAave,
            tokensAmountThatUserStableBorrowedFromAave: tokensAmountThatUserStableBorrowedFromAave,
            tokensAmountsThatUserVariableBorrowedFromAave: tokensAmountsThatUserVariableBorrowedFromAave
        });
    }

    /**
     *  @notice this function prepare the array of asset to borrow from FlashLoan to repay Aave debt for an user
     *  @param _aaveUserDataList the data of the Aave position to migrate : for gas efficiency you need to feed this variable with
     *                           only the data of the Aave position you want to migrate
     */
    function getAssetsToBorrowFromFLToRepayAaveDebt(MigrationFinance.AaveUserDataList calldata _aaveUserDataList)
        external
        view
        returns (
            address[] memory assetsToBorrowFromFL,
            uint256[] memory amountsToBorrowFromFL,
            uint256[] memory interestRateModes
        )
    {
        uint256 lengthOfassetsToBorrowArray = 0;

        for (uint256 i = 0; i < _aaveUserDataList.aaveReserveTokenList.length; i++) {
            if (_aaveUserDataList.tokensAmountsThatUserVariableBorrowedFromAave[i] > 0) {
                lengthOfassetsToBorrowArray++;
            }
        }
        assetsToBorrowFromFL = new address[](lengthOfassetsToBorrowArray);
        amountsToBorrowFromFL = new uint256[](lengthOfassetsToBorrowArray);
        interestRateModes = new uint256[](lengthOfassetsToBorrowArray);
        uint256 indexOfAssetToBorrow = 0;
        for (uint256 i = 0; i < _aaveUserDataList.aaveReserveTokenList.length; i++) {
            if (_aaveUserDataList.tokensAmountsThatUserVariableBorrowedFromAave[i] > 0) {
                assetsToBorrowFromFL[indexOfAssetToBorrow] = _aaveUserDataList.aaveReserveTokenList[i];
                amountsToBorrowFromFL[indexOfAssetToBorrow] =
                    _aaveUserDataList.tokensAmountsThatUserVariableBorrowedFromAave[i];
                interestRateModes[indexOfAssetToBorrow] = 0;
                indexOfAssetToBorrow++;
            }
        }
    }
}
