// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyContract {
    function approveToken(IERC20 token, address spender, uint256 amount) public {
        require(token.approve(spender, amount), "Token approval failed");
    }
}