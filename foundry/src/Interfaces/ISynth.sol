//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface ISynth {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function changeSythBaseAddress(address newAddress) external;
}
