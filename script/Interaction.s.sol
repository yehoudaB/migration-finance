//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {MigrationFinance} from "src/MigrationFinance.sol";

contract MigrateAavePositions is Script {
    HelperConfig helperConfig;
    MigrationFinance migrationFinance;

    function run() external {
        address migrationFinanceAddress = DevOpsTools.get_most_recent_deployment("MigrationFinance", block.chainid);
        migrationFinance = MigrationFinance(migrationFinanceAddress);
    }

    function migrateAavePosition(address _from, address _to) external {
        MigrationFinance.AaveUserDataList memory aaveUserDataList = helperConfig.getAaveUserDataForAllAssets(msg.sender);
    }
}
