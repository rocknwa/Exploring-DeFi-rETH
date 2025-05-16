// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IPoolDataProvider {
    function getReserveConfigurationData(address asset)
        external
        view
        returns (
            // Decimals of the asset
            uint256 decimals,
            // 1e4 = 100%
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        );
}
