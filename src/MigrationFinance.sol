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

/**
 * @title A contract that allow users to migrate their Aave V3 position to another wallet
 * @author YehoudaB
 * @notice this contract hasn't been  audited yet use at your own risk
 * @dev Implements Aave V3 Pool and Flashloan receiver
 */
contract MigrationFinance is FlashLoanReceiverBase {
    constructor(address _poolAddressProvider) FlashLoanReceiverBase(IPoolAddressesProvider(_poolAddressProvider)) {}

    function requestFlashLoan(
        address _receiverAddress,
        address[] calldata _assets,
        uint256[] calldata _amounts,
        uint256[] calldata _interestRateModes,
        address _onBehalfOf,
        bytes calldata _params,
        uint16 _referralCode
    ) external {
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
        for (uint256 i = 0; i < _assets.length; i++) {
            IERC20(_assets[i]).approve(address(POOL), _amounts[i] + _premiums[i]);
        }
        return true;
    }
}
