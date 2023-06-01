// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/SynthBase.sol";
import "../src/Synth.sol";

contract SynthBaseTest is Test {
    SynthBase public synthBase;
    Synth public synth;

    string name = "Synthetix USD";
    string symbol = "sUSD";

    function setUp() public {
        synthBase = new SynthBase();
        synth = new Synth(name, symbol);
    }

    function testAddCommodity() public {
        address commodityAddress = address(synth);
        synthBase.addSynth(commodityAddress);
        address[] memory assets = synthBase.getAssetList();
        assertEq(assets[0], commodityAddress);
    }
}
