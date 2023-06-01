// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.15;

error AmountMustBeAboveZero();
error UnAuthorized();
error InvalidAddress();
error SynthDoesntExist();

interface ISynthBase {
    event SynthAdded(address indexed operator, address indexed synthAddress);
    event SynthRemoved(address indexed operator, address indexed synthAddress);
    event ShortsEnabled(address operator, address synthAddress, bool value);
    event ShortsDisabled(address operator, address synthAddress, bool value);
    event ShortsIncreased(address indexed synthAddress, uint256 amount);
    event ShortsDecreased(address indexed synthAddress, uint256 amount);
    event SynthSwaped(
        address indexed operator,
        address indexed synth0,
        address indexed synth1,
        uint256 amount
    );

    struct Commodity {
        uint16 id;
        uint256 totalShorts;
        bool shortsEnabled;
    }

    function addSynth(address assetAddress) external;

    function removeSynth(address assetAddress) external;

    function mintSynth(address synthAddress, address to, uint amount) external;

    function burnSynth(
        address synthAddress,
        address from,
        uint amount
    ) external;

    function swapSynth(
        address synth0,
        address synth1,
        uint256 amoount
    ) external;

    function increaseShorts(address synthAddress, uint256 amount) external;

    function decreaseShorts(address SynthAdded, uint256) external;

    function getAssetList() external view returns (address[] memory);

    function getCommodities(
        address synthAddress
    ) external view returns (Commodity memory);
}
