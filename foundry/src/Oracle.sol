// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

import "./Interfaces/ISynthBase.sol";

import {Ownable} from "@oz/access/Ownable.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Oracle is Ownable {
    // Chainlink priceFeeds
    mapping(address => AggregatorV3Interface) public priceFeeds;

    address public sUSD;
    uint256 public constant sUSD_PRICE = 1e8;

    constructor() {}

    function getPrice(
        address oracleAddress
    ) external view returns (uint256, uint8) {
        if (oracleAddress == sUSD) {
            return (sUSD_PRICE, 18);
            //////////////////////////////////////////////////////////////////////////////
        } else {
            //////////////////////////////////////////////////////////////////////////////
            if (address(priceFeeds[oracleAddress]) == address(0))
                revert InvalidAddress();
            (, int256 price, , , ) = priceFeeds[oracleAddress]
                .latestRoundData();
            uint8 decimals = priceFeeds[oracleAddress].decimals();
            return (uint256(price), decimals);
        }
    }

    function setOracle(address oracleAddress) external onlyOwner {
        priceFeeds[oracleAddress] = AggregatorV3Interface(oracleAddress);
    }

    function change_sUSDAddress(address sUsd) external onlyOwner {
        if (sUSD == address(0)) revert InvalidAddress();
        sUSD = sUsd;
    }
}
