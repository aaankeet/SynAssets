// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import "./Interfaces/IBorrow.sol";
import "./Interfaces/ISynthBase.sol";
import "./Interfaces/ISynth.sol";
import "./Interfaces/IOracle.sol";
import "./Interfaces/ITreasury.sol";

contract Borrow is IBorrow, Ownable {
    ISynthBase public synthBase;
    ISynth public sUSD;
    IOracle public oracle;
    ITreasury public treasury;

    uint32 public minCollateralRatio;
    uint32 public liquidationCollateralRatio;
    uint32 public liquidationPenalty;

    uint32 public treasuryFee;

    mapping(bytes32 => BorrowDetails) public idToBorrowDetails;
    mapping(address => bytes32[]) public userBorrowings;
    mapping(address => uint32) public totalBorrowings;

    constructor(
        address _synthBase,
        address _sUsd,
        address _oracle,
        address _treasury,
        uint32 _minCollateralRatio,
        uint32 _liquidationCollateralRatio,
        uint32 _liquidationPenalty,
        uint32 _treasuryFee
    ) {
        synthBase = ISynthBase(_synthBase);
        sUSD = ISynth(_sUsd);
        oracle = IOracle(_oracle);
        treasury = ITreasury(_treasury);
        minCollateralRatio = _minCollateralRatio;
        liquidationCollateralRatio = _liquidationCollateralRatio;
        liquidationPenalty = _liquidationPenalty;
        treasuryFee = _treasuryFee;
    }

    /**
     * @param synthAddress - address of synth  to Borrow
     * @param borrowAmount - amount of synth to Borrow
     * @param collateralAmount - amount to provide as collateral
     */

    function borrow(
        address synthAddress,
        uint256 borrowAmount,
        uint256 collateralAmount
    ) external {
        if (synthAddress == address(0)) revert InvalidAddress();
        if (borrowAmount == 0) revert AmountMustBeAboveZero();

        // @dev - create a unique borrow id
        bytes32 borrowId = keccak256(
            abi.encode(
                msg.sender,
                msg.data,
                block.number,
                userBorrowings[msg.sender].length
            )
        );

        userBorrowings[msg.sender].push(borrowId);

        idToBorrowDetails[borrowId] = BorrowDetails({
            user: msg.sender,
            synthAddress: synthAddress,
            borrowedAmount: borrowAmount,
            collateralAmount: collateralAmount,
            timestamp: block.timestamp,
            minCollateralRatio: minCollateralRatio,
            liquidationCollateralRatio: liquidationCollateralRatio,
            liquidationPenalty: liquidationPenalty,
            treasuryFee: treasuryFee,
            borrowIndex: totalBorrowings[msg.sender]++
        });

        uint collaterlRatio = getCollateralRatio(borrowId);

        require(
            collaterlRatio >= minCollateralRatio,
            "Collateral Ratio Less than minimum collateral ratio"
        );

        sUSD.transferFrom(msg.sender, address(this), collateralAmount);
        synthBase.increaseShorts(synthAddress, borrowAmount);
        synthBase.mintSynth(synthAddress, msg.sender, borrowAmount);

        emit AssetBorrowed(
            borrowId,
            synthAddress,
            borrowAmount,
            collateralAmount
        );
    }

    // Return Borrowed Assets
    function increaseCollateral(bytes32 borrowId, uint256 amount) external {
        BorrowDetails storage currentId = idToBorrowDetails[borrowId];
        if (currentId.user == address(0)) revert QueryForNonExistingBorrowing();
        if (currentId.user != msg.sender) revert NotOwner();

        currentId.collateralAmount += amount;

        sUSD.transferFrom(msg.sender, address(this), amount);

        emit CollateralIncreased(
            msg.sender,
            currentId.synthAddress,
            currentId.collateralAmount
        );
    }

    ////////////////////////
    ///  VIEW FUNCTIONS  ///
    ////////////////////////
    /**
     *
     * @param borrowId - bororw Id must exist
     * @notice - returns collateral ratio
     */
    function getCollateralRatio(
        bytes32 borrowId
    ) public view returns (uint256 collateralRatio) {
        BorrowDetails storage currentId = idToBorrowDetails[borrowId];
        if (currentId.user == address(0)) revert QueryForNonExistingBorrowing();

        (uint256 sUsdPrice, uint8 sUsdDecimals) = oracle.getPrice(
            address(sUSD)
        );
        (uint256 synthPrice, uint8 synthDecimals) = oracle.getPrice(
            address(currentId.synthAddress)
        );

        uint256 borrowed = currentId.borrowedAmount;
        uint256 collateral = currentId.collateralAmount;

        if (synthPrice * borrowed != 0) {
            collateralRatio =
                uint32(sUsdPrice * collateral * 10 ** (8 + sUsdDecimals)) /
                (synthPrice * borrowed * 10 ** synthDecimals);
        } else if (borrowed == 0) {
            collateralRatio = 0;
        } else {
            collateralRatio = type(uint32).max;
        }
    }

    /////////////////////////////
    ///  EMERGENCY FUNCTIONS  ///
    /////////////////////////////

    function changeSynthBaseAddress(address _newAddress) external onlyOwner {
        synthBase = ISynthBase(_newAddress);
    }

    function changesUsdAddress(address _newAddress) external onlyOwner {
        synthBase = ISynthBase(_newAddress);
    }

    function changeOracleAddress(address _newAddress) external onlyOwner {
        synthBase = ISynthBase(_newAddress);
    }

    function changeTreasuryAddress(address _newAddress) external onlyOwner {
        synthBase = ISynthBase(_newAddress);
    }
}
