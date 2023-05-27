// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

error AmountMustBeAboveZero();
error UnAuthorized();
error InvalidAddress();

interface ISynthBase {
    function addSynth(address assetAddress) external;

    function removeSynth(address assetAddress) external;

    function mintSynth(address synthAddress, address to, uint amount) external;

    function burnSynth(
        address synthAddress,
        address from,
        uint amount
    ) external;
}
