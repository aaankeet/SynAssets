// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

import "./Interfaces/ISynthBase.sol";
import "./Interfaces/ISynth.sol";
import "./Interfaces/IOracle.sol";

import {Ownable} from "@oz/access/Ownable.sol";

contract SynthBase is ISynthBase, Ownable {
    address public synthetixAddress;
    address public treasury;
    address public sUSD;
    uint8 public SWAP_FEE = 100; // 0.01%
    IOracle public oracle;

    address[] commodityList;
    mapping(address => Commodity) public commodities;

    modifier onlySynthetix() {
        if (msg.sender != synthetixAddress) revert UnAuthorized();
        _;
    }

    /**
     * @param synthAddress address of synth Token
     * @notice only Onwer can add synths
     */

    function addSynth(address synthAddress) external onlyOwner {
        if (synthAddress == address(0)) revert InvalidAddress();
        commodities[synthAddress].id = uint16(commodityList.length + 1);
        commodityList.push(synthAddress);
        emit SynthAdded(msg.sender, synthAddress);
    }

    function removeSynth(address synthAddress) external onlyOwner {
        if (commodities[synthAddress].id == 0) revert SynthDoesntExist();
        uint synthIndex = commodities[synthAddress].id;
        uint length = commodityList.length - 1;

        // Move the last element to the position being deleted
        commodityList[synthIndex - 1] = commodityList[length];
        // Update the ID of the moved element
        commodities[commodityList[synthIndex]].id = uint16(synthIndex);
        // Remove the last element from the list
        commodityList.pop();
        // Delete the synth from the mapping
        delete commodities[synthAddress];
        emit SynthRemoved(msg.sender, synthAddress);
    }

    /**
     * @notice only synthetix can mint
     * @param synthAddress - address of the synth to mint
     * @param to - address of account to mint to
     * @param amount - number of synth to mint
     */
    function mintSynth(
        address synthAddress,
        address to,
        uint amount
    ) external onlySynthetix {
        if (amount == 0) revert AmountMustBeAboveZero();
        ISynth(synthAddress).mint(to, amount);
    }

    function burnSynth(
        address synthAddress,
        address from,
        uint amount
    ) external onlySynthetix {
        if (commodities[synthAddress].id == 0) revert InvalidAddress();
        if (amount == 0) revert AmountMustBeAboveZero();
        ISynth(synthAddress).burn(from, amount);
    }

    /**
     * @param synth0 - synth user wants to trade
     * @param synth1 - synth user wants to trade for
     * @param amount - amount of synth user wants to trade
     * @notice - charges fee for swaps
     */
    function swapSynth(
        address synth0,
        address synth1,
        uint amount
    ) external onlySynthetix {
        if (commodities[synth0].id == 0 || synth1 == sUSD)
            revert SynthDoesntExist();
        if (commodities[synth1].id == 0 || synth0 == sUSD)
            revert SynthDoesntExist();
        if (amount == 0) revert AmountMustBeAboveZero();

        (uint256 synth0Price, uint8 synth0Decimals) = oracle.getPrice(synth0);
        (uint256 synth1Price, uint8 synth1Decimals) = oracle.getPrice(synth1);

        uint256 amountReceive = (synth0Price * amount * 10 ** synth0Decimals) /
            (synth1Price * 10 ** synth1Decimals);

        uint256 fee = (amountReceive * SWAP_FEE) / SWAP_FEE;

        ISynth(synth0).burn(msg.sender, amount);
        ISynth(synth1).mint(msg.sender, amount - fee);
        ISynth(synth1).mint(treasury, fee);
    }

    function increaseShorts(
        address synthAddress,
        uint256 amount
    ) external onlyOwner {
        if (commodities[synthAddress].id == 0) revert SynthDoesntExist();
        if (amount == 0) revert AmountMustBeAboveZero();
        commodities[synthAddress].totalShorts += amount;
        emit ShortsIncreased(synthAddress, amount);
    }

    function decreaseShorts(address synthAddress, uint256 amount) external {
        if (commodities[synthAddress].id == 0) revert SynthDoesntExist();
        if (amount == 0) revert AmountMustBeAboveZero();
        commodities[synthAddress].totalShorts -= amount;
        emit ShortsDecreased(msg.sender, amount);
    }

    function toggleShorts(address synthAddress, bool value) external onlyOwner {
        if (commodities[synthAddress].id == 0) revert SynthDoesntExist();
        if (value == true) {
            require(
                commodities[synthAddress].shortsEnabled == false,
                "Shorts Already Enabled"
            );
            commodities[synthAddress].shortsEnabled = value;
            emit ShortsEnabled(msg.sender, synthAddress, value);
        }
        if (value == false) {
            require(
                commodities[synthAddress].shortsEnabled == true,
                "Shorts Already Disable"
            );
            commodities[synthAddress].shortsEnabled = value;
            emit ShortsDisabled(msg.sender, synthAddress, value);
        }
    }

    //////////////// /////
    /// VIEW FUNCTIONS ///
    //////////////////////
    /**
     * @notice - get total number of assets
     */
    function getAssetList() external view returns (address[] memory) {
        return commodityList;
    }

    /**
     * @notice - get details of a Commodity
     * @param synthAddress - address of the valid Commodity
     */
    function getCommodities(
        address synthAddress
    ) external view returns (Commodity memory) {
        if (commodities[synthAddress].id == 0) revert InvalidAddress();
        return commodities[synthAddress];
    }
}
