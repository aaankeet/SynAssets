// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/SynthBase.sol";

contract SynthBaseTest is Test {
    SynthBase public synthBase;

    function setUp() public {
        synthBase = new SynthBase();
    }

    function testAddCommodity() public {
        address commodityAddress = address(1);
        synthBase.addCommodity(commodityAddress);
        address[] memory assets = synthBase.getAssetList();
        assertEq(assets[0], address(1));
        // assertEq(synthBase.assetList.length, 0);
    }
}
