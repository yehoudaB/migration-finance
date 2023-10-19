// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-LICENSE-IDENTIFIER: AGPL-3.0

pragma solidity ^0.8.20;

import {FlashLoanReceiverBase} from "@aave-v3-core/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import {FlashLoanReceiverBase} from "@aave-v3-core/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolDataProvider} from "@aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";

/**
 * @title A contract that allow users to migrate their Aave V3 position to another wallet
 * @author YehoudaB
 * @notice this contract hasn't been  audited yet use at your own risk
 * @dev Implements Aave V3 Pool and Flashloan receiver
 */
contract MigrationFinance is FlashLoanReceiverBase {
    IPoolDataProvider public poolDataProvider;

    struct AaveUserATokenData {
        address aTokenAddress;
        uint256 aTokenAmount;
        bool isCollateral;
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

    struct AaveUserDataList {
        address[] aaveReserveTokenList;
        uint256[] tokensAmountsThatUserDepositedInAave;
        bool[] areTokensCollateralThatUserDepositedInAave;
        uint256[] tokensAmountThatUserStableBorrowedFromAave;
        uint256[] tokensAmountsThatUserVariableBorrowedFromAave;
    }

    constructor(address _poolAddressProvider) FlashLoanReceiverBase(IPoolAddressesProvider(_poolAddressProvider)) {
        poolDataProvider = IPoolDataProvider(_poolAddressProvider);
    }

    function requestFlashLoan(
        address _receiverAddress,
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _interestRateModes,
        address _onBehalfOf,
        bytes memory _params,
        uint16 _referralCode
    ) public {
        POOL.flashLoan(_receiverAddress, _assets, _amounts, _interestRateModes, _onBehalfOf, _params, _referralCode);
    }

    /**
     * @notice this function is called after your contract has received the flash loaned amount
     * @dev Ensure that the contract can return the debt + premium, e.g., has
     *      enough funds to repay and has approved the Pool to pull the total amount
     */
    function executeOperation(
        address[] calldata _assets,
        uint256[] calldata _amounts,
        uint256[] calldata _premiums,
        address _initiator,
        bytes calldata _params
    ) external returns (bool) {
        // do whatever you want with the flash loaned amount

        (address _from, address _to, address[] memory assetsToMove, uint256[] memory amountsToMove) =
            abi.decode(_params, (address, address, address[], uint256[]));

        // return the funds to the pool
        for (uint256 i = 0; i < assetsToMove.length; i++) {
            IERC20(assetsToMove[i]).transferFrom(_from, _to, amountsToMove[i]); // transfer the asset to the new wallet
            POOL.deposit(assetsToMove[i], amountsToMove[i], _to, 0); // deposit the asset in the new wallet
        }
        for (uint256 i = 0; i < _assets.length; i++) {
            address tokenToBorrow = _assets[i];
            uint256 amountToBorrow = _amounts[i];
            IERC20(tokenToBorrow).approve(address(POOL), amountToBorrow); // approve to repay to the POOL (regular debt)
            POOL.repay(tokenToBorrow, amountToBorrow, 2, _from);

            POOL.borrow(tokenToBorrow, amountToBorrow, 2, 0, _to); // if contract is the borrower
            IERC20(tokenToBorrow).approve(address(POOL), amountToBorrow + _premiums[i]); // approve to repay to the FLASHLOAN
        }
        // possibly merge the two for loops ...
        return true;
    }

    /**
     * @notice this function aims to migrate the Aave position from one wallet to another
     * @dev before excuting this function, the _to address should have allowed the _form address to borrow on behalf of it
     * @param _from the address of the wallet that has the Aave position
     * @param _to the address of the wallet that will receive the Aave position
     * @param assetsToBorrowFromFL the list of addresses of assets to borrow from the flashloan (to repay the Aave debts position)
     * @param amountsToBorrowFromFL the list of amounts to borrow from the flashloan (to repay the Aave debts position)
     * @param interestRateModes the types of debt position to open if the flashloan is not returned. for us is 0: (no open debt) (amount+fee must be paid in this case or revert)
     *
     */
    function moveAavePositionToAnotherWallet(
        address _from,
        address _to,
        address[] memory assetsToBorrowFromFL,
        uint256[] memory amountsToBorrowFromFL,
        uint256[] memory interestRateModes,
        address[] memory assetsToMove,
        uint256[] memory amountsToMove
    ) external {
        bytes memory fromAndToAddressesEncoded = abi.encode(_from, _to, assetsToMove, amountsToMove);
        requestFlashLoan(
            address(this),
            assetsToBorrowFromFL,
            amountsToBorrowFromFL,
            interestRateModes,
            address(this),
            fromAndToAddressesEncoded,
            0
        );
    }
}
