// SPDX-LICENSE-IDENTIFIER: AGPL-3.0
pragma solidity ^0.8.20;
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
contract TeleportAaveV3 is FlashLoanReceiverBase {
    IPoolDataProvider public poolDataProvider;

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
        (address _from, address _to, address[] memory aTokenAssetsToMove, uint256[] memory aTokenAmountsToMove) =
            abi.decode(_params, (address, address, address[], uint256[]));

        for (uint256 i = 0; i < _assets.length; i++) {
            address tokenToBorrow = _assets[i];
            uint256 amountToBorrow = _amounts[i];
            IERC20(tokenToBorrow).approve(address(POOL), amountToBorrow); // approve to repay to the POOL (regular debt)
            POOL.repay(tokenToBorrow, amountToBorrow, 2, _from); // repay the debt to the POOL for the _from address

            /* borrow the debt to the POOL for the _to address 
            * (the _to address should have allowed the contract  to borrow on behalf of it)
                we borrow the amount + the premium (the premium is for paying the flashloan fee)
            */
            POOL.borrow(tokenToBorrow, amountToBorrow + _premiums[i], 2, 0, _to);
            IERC20(tokenToBorrow).approve(address(POOL), amountToBorrow + _premiums[i]); // approve to repay to the FLASHLOAN
        }
        for (uint256 i = 0; i < aTokenAssetsToMove.length; i++) {
            IERC20(aTokenAssetsToMove[i]).transferFrom(_from, _to, aTokenAmountsToMove[i]);
        }
        // possibly merge the two for loops ...
        return true;
    }

    /**
     * @notice this function aims to migrate the Aave position from one wallet to another
     * @dev before excuting this function, the _to address should have allowed the _form address to borrow on behalf of it
     * @param _from the address of the wallet that has the Aave position
     * @param _to the address of the wallet that will receive the Aave position
     * @param assetsBorrowed the list of addresses of assets to borrow from the flashloan (to repay the Aave debts position)
     * @param amountsBorrowed the list of amounts to borrow from the flashloan (to repay the Aave debts position)
     * @param interestRateModes the types of debt position to open if the flashloan is not returned. for us is 0: (no open debt) (amount+fee must be paid in this case or revert)
     *
     */
    function moveAavePositionToAnotherWallet(
        address _from,
        address _to,
        address[] memory assetsBorrowed,
        uint256[] memory amountsBorrowed,
        uint256[] memory interestRateModes,
        address[] memory aTokenAssetsToMove,
        uint256[] memory aTokenAmountsToMove
    ) external {
        bytes memory fromAndToAddressesEncoded = abi.encode(_from, _to, aTokenAssetsToMove, aTokenAmountsToMove);
        requestFlashLoan(
            address(this),
            assetsBorrowed,
            amountsBorrowed,
            interestRateModes,
            address(this),
            fromAndToAddressesEncoded,
            0
        );
    }
}
