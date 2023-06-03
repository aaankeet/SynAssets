// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract SYX is ERC20, Ownable {
    uint public maxSupply;

    constructor(uint maxSupply_) ERC20("Synthetic Asset", "SYX") {
        maxSupply = maxSupply_;
    }

    function mint(address to, uint amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint amount) public onlyOwner {
        _burn(from, amount);
    }

    function publicMint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
