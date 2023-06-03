// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Interfaces/ISynthBase.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";

/**
 * @title - Synth Contract, Create New Synths
 * @author - (^_^)
 */

contract Synth is ERC20, Ownable {
    // SynthBase Contract, manages minting and burning of synths
    address public synthBase;
    uint256 public maxSupply;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) ERC20(name_, symbol_) {
        maxSupply = maxSupply_;
    }

    modifier onlySynthBase() {
        if (msg.sender != synthBase) revert UnAuthorized();
        _;
    }

    function mint(address to, uint amount) external onlySynthBase {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlySynthBase {
        _burn(from, amount);
    }

    function changeSynthBaseAddress(address newAddress) external onlyOwner {
        synthBase = newAddress;
    }
}
