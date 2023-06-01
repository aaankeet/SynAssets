// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

interface ITreasury {
    function withdrawEth(uint256 amount) external;

    function withdrawTokens(address tokenAddress, uint256 amount) external;
}
