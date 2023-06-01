// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

error NotEnoughCollateral();
error QueryForNonExistingBorrowing();
error NotOwner();

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
    event AssetBorrowed(
        address indexed synthAddress,
        uint256 borrowAmount,
        uint256 collateralAmount
    );
    event CollateralIncreased(
        address indexed operator,
        address indexed synthAddress,
        uint256 amount
    );

    function borrow(
        address synthAddress,
        uint256 amount,
        uint256 collateralAmount
    ) external;

    function increaseCollateral(bytes32 borrowId, uint256 amount) external;

    function getCollateralRatio(
        bytes32 borrowId
    ) external view returns (uint256 collateralRatio);
}
