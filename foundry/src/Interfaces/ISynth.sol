//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";

interface ISynth is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function changeSythBaseAddress(address newAddress) external;
}
