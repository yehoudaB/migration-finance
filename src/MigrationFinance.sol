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

/**
 * @title A contract that allow users to migrate their Aave V3 position to another wallet
 * @author YehoudaB
 * @notice this contract hasn't been  audited yet use at your own risk
 * @dev Implements Aave V3 Pool and Flashloan receiver
 */
contract MigrationFinance {
    FlashLoanReceiverBase private s_flashLoanReceiverBase;

    constructor(address _poolAddressProvider) {
        s_flashLoanReceiverBase = FlashLoanReceiverBase(_poolAddressProvider);
    }

    function getFlashLoan(
        address[] calldata _assets,
        uint256[] calldata _amounts,
        uint256[] calldata _premiums,
        address _initiator,
        bytes calldata _params
    ) external returns (bool) {
        return s_flashLoanReceiverBase.executeOperation(_assets, _amounts, _premiums, _initiator, _params);
    }
}
