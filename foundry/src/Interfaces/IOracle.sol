// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

interface IOracle {
    function getPrice(
        address synthAddress
    ) external view returns (uint256, uint8);
}
