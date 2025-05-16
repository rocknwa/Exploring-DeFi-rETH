// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/Script.sol";
import {IPool} from "@src/interfaces/aave/IPool.sol";
import {AAVE_POOL} from "@src/helpers/Constants.sol";

contract AaveLib {
    IPool internal constant pool = IPool(AAVE_POOL);

    struct Info {
        uint256 hf;
        uint256 col;
        uint256 debt;
        uint256 available;
    }

    function getInfo(address user) internal view returns (Info memory) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = pool.getUserAccountData(user);

        console.log("Collateral (USD): %e", totalCollateralBase);
        console.log("Debt (USD): %e", totalDebtBase);
        console.log("Available to borrow (USD): %e", availableBorrowsBase);
        console.log("LTV: %e", ltv);
        console.log("Liquidation threshold: %e", currentLiquidationThreshold);
        console.log("Health factor: %e", healthFactor);

        return Info({
            hf: healthFactor,
            col: totalCollateralBase,
            debt: totalDebtBase,
            available: availableBorrowsBase
        });
    }
}
