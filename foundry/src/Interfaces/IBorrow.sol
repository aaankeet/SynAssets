// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

error NotEnoughCollateral();
error QueryForNonExistingBorrowing();
error NotYourBorrowing();

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
        bytes32 indexed borrowId,
        address indexed synthAddress,
        uint256 borrowAmount,
        uint256 collateralAmount
    );

    event Repayed(
        address indexed operator,
        bytes32 indexed borrowId,
        uint256 amount
    );

    event CollateralIncreased(
        address indexed operator,
        address indexed synthAddress,
        uint256 amount
    );

    event CollateralWithdrawn(
        address indexed operator,
        bytes32 indexed borrowId,
        uint256 amount
    );

    event LoanClosed(address indexed operator, bytes32 indexed borrowId);

    event Liquidated(
        address indexed liquidator,
        address indexed user,
        bytes32 indexed borrowId,
        uint256 synthAmount
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
