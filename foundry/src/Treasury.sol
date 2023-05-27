// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

import {Ownable} from "@oz/access/Ownable.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

contract Treasury is Ownable {
    // to Withdraw native currency
    function withraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Transfer Failed");
    }

    // to withdraw any erc20 tokens
    function withdrawERC20(
        address tokenAddress,
        uint amount
    ) external onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    receive() external payable {}

    fallback() external payable {}
}
