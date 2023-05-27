// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract Borrow is Ownable {
    address public synthBase;

    mapping(address => mapping(address => uint)) assetBorrowed;
    // Borrow
    // Return Borrowed Assets
}
