// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

interface IBorrow {
    struct Borrower {
        address user;
        uint256 borrowedAmount;
    }
}
