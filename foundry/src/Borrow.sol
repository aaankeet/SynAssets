// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

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

    //////////////////////////
    /// EXTERNAL FUNCTIONS ///
    //////////////////////////
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

        if (currentId.user != msg.sender) revert NotYourBorrowing();

        currentId.collateralAmount += amount;

        sUSD.transferFrom(msg.sender, address(this), amount);

        emit CollateralIncreased(
            msg.sender,
            currentId.synthAddress,
            currentId.collateralAmount
        );
    }

    function repayDebt(bytes32 borrowId, uint256 amount) external {
        BorrowDetails storage currentBorrowing = idToBorrowDetails[borrowId];

        if (currentBorrowing.user != msg.sender) revert NotYourBorrowing();

        currentBorrowing.borrowedAmount -= amount;
        synthBase.decreaseShorts(currentBorrowing.synthAddress, amount);
        synthBase.burnSynth(currentBorrowing.synthAddress, msg.sender, amount);

        emit Repayed(msg.sender, borrowId, amount);
    }

    /**
     * @param borrowId - borrow Id
     * @param amount  - amount of collateral to withdraw
     */

    function withdrawCollateral(bytes32 borrowId, uint256 amount) external {
        BorrowDetails storage currentBorrowing = idToBorrowDetails[borrowId];

        if (currentBorrowing.user != msg.sender) revert NotYourBorrowing();

        require(
            currentBorrowing.collateralAmount >= amount,
            "Not Enough Colateral"
        );

        currentBorrowing.collateralAmount -= amount;
        uint256 collateralRatio = getCollateralRatio(borrowId);

        require(
            collateralRatio >= currentBorrowing.minCollateralRatio ||
                collateralRatio == 0,
            "collateral ratio less than minCollateralRatio"
        );

        sUSD.transfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, borrowId, amount);

        if (
            currentBorrowing.collateralAmount == 0 &&
            currentBorrowing.borrowedAmount == 0
        ) {
            uint32 index = currentBorrowing.borrowIndex;
            uint32 TotalBorrowings = totalBorrowings[msg.sender]--;

            userBorrowings[msg.sender][index] = userBorrowings[msg.sender][
                TotalBorrowings - 1
            ];
            userBorrowings[msg.sender].pop();

            if (userBorrowings[msg.sender].length != index) {
                idToBorrowDetails[userBorrowings[msg.sender][index]]
                    .borrowIndex = index;
            }

            delete idToBorrowDetails[borrowId];

            emit LoanClosed(msg.sender, borrowId);
        }
    }

    function liquidate(bytes32 borrowId) external {
        BorrowDetails storage currentBorrowing = idToBorrowDetails[borrowId];

        if (currentBorrowing.user == address(0))
            revert QueryForNonExistingBorrowing();

        require(
            getCollateralRatio(borrowId) <
                currentBorrowing.liquidationCollateralRatio,
            "Cannot Liquidate yet"
        );

        (uint256 sUsdPrice_, uint8 sUsdDecimals_) = oracle.getPrice(
            address(sUSD)
        );
        (uint256 synthPrice_, uint8 synthDecimals_) = oracle.getPrice(
            address(currentBorrowing.synthAddress)
        );

        uint256 neededSynth = (currentBorrowing.minCollateralRatio *
            currentBorrowing.borrowedAmount *
            synthPrice_ *
            10 ** sUsdDecimals_ -
            currentBorrowing.collateralAmount *
            sUsdPrice_ *
            10 ** synthDecimals_) /
            (synthPrice_ *
                10 *
                sUsdDecimals_ *
                (currentBorrowing.minCollateralRatio -
                    (1e8 +
                        currentBorrowing.liquidationPenalty +
                        currentBorrowing.treasuryFee)));

        uint256 liquidateSUsd = (neededSynth *
            synthPrice_ *
            (1e8 +
                currentBorrowing.liquidationPenalty +
                currentBorrowing.treasuryFee) *
            10 ** sUsdDecimals_) / (sUsdPrice_ * 10 ** synthDecimals_);

        uint256 liquidatorReward = (liquidateSUsd *
            (1e8 + currentBorrowing.liquidationPenalty)) /
            (1e8 +
                currentBorrowing.liquidationPenalty +
                currentBorrowing.treasuryFee);

        uint256 treasuryReward = (liquidateSUsd *
            currentBorrowing.treasuryFee) /
            (1e8 +
                currentBorrowing.liquidationPenalty +
                currentBorrowing.treasuryFee);

        // if CR dropped too low
        // we pay the liquidator at the expense of other people's collateral
        // and reimburse the losses at the expense of the treasury manually

        if (
            liquidatorReward + treasuryReward <=
            currentBorrowing.collateralAmount
        ) {
            unchecked {
                currentBorrowing.collateralAmount -=
                    liquidatorReward +
                    treasuryReward;
            }
        } else {
            currentBorrowing.collateralAmount = 0;
        }

        if (neededSynth <= currentBorrowing.borrowedAmount) {
            unchecked {
                currentBorrowing.borrowedAmount -= neededSynth;
            }
        } else {
            currentBorrowing.borrowedAmount = 0;
        }

        synthBase.burnSynth(
            currentBorrowing.synthAddress,
            msg.sender,
            neededSynth
        );
        sUSD.transfer(address(treasury), treasuryReward);
        sUSD.transfer(msg.sender, liquidatorReward);

        emit Liquidated(
            msg.sender,
            currentBorrowing.user,
            borrowId,
            neededSynth
        );

        // Close Loan
        if (
            currentBorrowing.collateralAmount == 0 &&
            currentBorrowing.borrowedAmount == 0
        ) {
            uint32 borrowIndex_ = currentBorrowing.borrowIndex;
            uint256 totalLoans = userBorrowings[msg.sender].length;

            userBorrowings[msg.sender][borrowIndex_] = userBorrowings[
                msg.sender
            ][totalLoans - 1];

            userBorrowings[msg.sender].pop();

            // change the last index which was moved
            if (userBorrowings[msg.sender].length != borrowIndex_) {
                idToBorrowDetails[userBorrowings[msg.sender][borrowIndex_]]
                    .borrowIndex = borrowIndex_;
            }
            delete idToBorrowDetails[borrowId];

            emit LoanClosed(msg.sender, borrowId);
        }
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

    /**
     * @param synthAddress - address for synth
     * @dev - returns total shorts
     */
    function getTotalShorts(
        address synthAddress
    ) external view returns (uint256) {
        if (synthBase.getCommodity(synthAddress).id == 0)
            revert SynthDoesntExist();

        return synthBase.getCommodity(synthAddress).totalShorts;
    }

    function getLongs(address synthAddress) external view returns (uint256) {
        if (synthBase.getCommodity(synthAddress).id == 0)
            revert SynthDoesntExist();

        return ISynth(synthAddress).totalSupply();
    }

    /////////////////////////////
    ///  EMERGENCY FUNCTIONS  ///
    /////////////////////////////

    function setMinCollateralRatio(uint32 value) external onlyOwner {
        require(
            liquidationCollateralRatio <= minCollateralRatio,
            "liquidationCollateralRatio should be <= minCollateralRatio"
        );
        minCollateralRatio = value;
    }

    function setLiquidationCollateralRatio(uint32 value) external onlyOwner {
        require(
            liquidationCollateralRatio <= minCollateralRatio,
            "liquidationCollateralRatio should be <= minCollateralRatio"
        );
        require(
            1e8 + liquidationPenalty + treasuryFee <=
                liquidationCollateralRatio,
            "1 + liquidationPenalty + treasuryFee should be <= liquidationCollateralRatio"
        );
        liquidationCollateralRatio = value;
    }

    function setLiquidationPenalty(uint32 value) external onlyOwner {
        require(
            1e8 + liquidationPenalty + treasuryFee <=
                liquidationCollateralRatio,
            "1 + liquidationPenalty + treasuryFee should be <= liquidationCollateralRatio"
        );
        liquidationPenalty = value;
    }

    function setTreasuryFee(uint32 value) external onlyOwner {
        require(
            1e8 + liquidationPenalty + treasuryFee <=
                liquidationCollateralRatio,
            "1 + liquidationPenalty + treasuryFee should be <= liquidationCollateralRatio"
        );
        treasuryFee = value;
    }

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
