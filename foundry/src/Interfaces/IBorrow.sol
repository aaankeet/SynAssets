// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

error NotEnoughCollateral();

interface IBorrow {
    struct BorrowDetails {
        address user;
        address synthAddress;
        uint256 borrowedAmount;
        uint256 collateralAmount;
        uint256 timestamp;
        uint32 minCollateralRatio;
        uint32 liquidationCollateralRatio;
        uint32 liquidationPenalty;
        uint32 treasuryFee;
        uint32 borrowIndex;
    }

    function borrow(
        address synthAddress,
        uint256 amount,
        uint256 collatralAmount
    ) external;

    function increaseCollateral() external;
}
