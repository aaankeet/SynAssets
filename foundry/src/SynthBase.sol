// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

import "./Interfaces/ISynthBase.sol";
import "./Interfaces/ISynth.sol";
import "./Interfaces/IOracle.sol";

import {Ownable} from "@oz/access/Ownable.sol";

contract SynthBase is Ownable {
    address public synthetixAddress;
    address public treasury;
    IOracle public oracle;
    uint256 public SWAP_FEE = 100; // 0.01%

    struct Commodity {
        uint16 id;
        uint256 totalShorts;
        bool shortsEnabled;
    }

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
     * @param to - address of user who will receive synth1
     * @param amount - amount of synth user wants to trade
     */
    function swapTo(
        address synth0,
        address synth1,
        address to,
        uint amount
    ) external onlySynthetix {
        if (commodities[synth0].id == 0 && commodities[synth1].id == 0)
            revert InvalidAddress();
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert AmountMustBeAboveZero();

        (uint256 synth0Price, uint8 synth0Decimals) = oracle.getPrice(synth0);
        (uint256 synth1Price, uint8 synth1Decimals) = oracle.getPrice(synth1);

        uint256 amountReceive = (synth0Price * amount * 10 ** synth0Decimals) /
            (synth1Price * 10 ** synth1Decimals);

        uint256 fee = (amountReceive * SWAP_FEE) / SWAP_FEE;

        ISynth(synth0).burn(msg.sender, amount);
        ISynth(synth1).mint(to, amount - fee);
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
