// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// External Package Imports
import "solmate/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Local Imports
import {IERC20Metadata} from "../interfaces/IERC20Metadata.sol";
import {SwapService} from "./SwapService.sol";
import {DebtService} from "./DebtService.sol";
import {AccountingService} from "./AccountingService.sol";
import {PricingLib} from "../libraries/PricingLib.sol";
import {CapitalLib} from "../libraries/CapitalLib.sol";
import {AddressLib} from "../libraries/AddressLib.sol";
import {MathLib} from "../libraries/MathLib.sol";

/// @title shAave child contract, owned by the Parent
contract Child is AccountingService, SwapService, DebtService, Ownable {
    using AddressLib for address[];
    using PricingLib for address;
    using MathLib for uint256;

    // Events
    event PositionAddedSuccess(address user, address shortTokenAddress, uint256 amount);

    constructor(address _user, address _baseToken, uint256 _baseTokenDecimals, uint256 _shaaveLTV)
        DebtService(_baseToken, _baseTokenDecimals, _shaaveLTV)
        AccountingService(_user)
    {}

    /**
     * @dev This function is used to short an asset; it's exclusively called by ShaavePerent.addShortPosition().
     * @param _shortToken The address of the short token the user wants to reduce his or her position in.
     * @param _baseTokenAmount The amount of collateral that will be used for adding to a short position.
     * @param _user The end user's address.
     * @notice currentAssetPrice is the current price of the short token, in terms of the collateral token.
     * @notice borrowAmount is the amount of the short token that will be borrowed from Aave (in shortToken decimals).
     *
     */
    function short(address _shortToken, uint256 _baseTokenAmount, address _user) public onlyOwner returns (bool) {
        // Decimals
        uint256 shortTokenDecimals = IERC20Metadata(_shortToken).decimals();

        // Borrow asset
        uint256 borrowAmount = borrowAsset(_shortToken, _user, _baseTokenAmount, shortTokenDecimals);

        // Swap borrowed asset for base token
        (uint256 amountIn, uint256 amountOut) =
            swapExactInput(_shortToken, baseToken, borrowAmount, shortTokenDecimals, baseTokenDecimals);
        emit PositionAddedSuccess(_user, _shortToken, borrowAmount);

        // Update user's accounting
        if (userPositions[_shortToken].shortTokenAddress == address(0)) {
            userPositions[_shortToken].shortTokenAddress = _shortToken;
        }

        if (!userPositions[_shortToken].hasDebt) {
            userPositions[_shortToken].hasDebt = true;
        }

        if (!openedShortPositions.includes(_shortToken)) {
            openedShortPositions.push(_shortToken);
        }

        userPositions[_shortToken].shortTokenAmountsSwapped.push(amountIn);
        userPositions[_shortToken].baseAmountsReceived.push(amountOut);
        userPositions[_shortToken].collateralAmounts.push(_baseTokenAmount);
        userPositions[_shortToken].backingBaseAmount += amountOut;

        return true;
    }

    /**
     * @dev This function is used to reduce a short position.
     * @param _shortToken The address of the short token the user wants to reduce his or her position in.
     * @param _percentageReduction The percentage reduction of the user's short position; 100% constitutes closing out the position
     * @param _withdrawCollateral A boolean to withdraw collateral or not.
     * @notice positionReduction The amount of short token that the position is being reduced by.
     * @notice totalShortTokenDebt The total amount that this contract owes Aave (principle + interest).
     *
     */
    function reducePosition(address _shortToken, uint256 _percentageReduction, bool _withdrawCollateral)
        public
        userOnly
        returns (bool)
    {
        require(_percentageReduction > 0 && _percentageReduction <= 100, "Invalid percentage.");

        uint256 shortTokenDecimals = IERC20Metadata(_shortToken).decimals();

        // Calculate the amount of short tokens the short position will be reduced by
        uint256 positionReduction = (getOutstandingDebt(_shortToken) * _percentageReduction) / 100; // Uints: short token decimals

        // Swap base tokens for short tokens
        (uint256 amountIn, uint256 amountOut) = swapToShortToken(
            _shortToken,
            baseToken,
            positionReduction,
            userPositions[_shortToken].backingBaseAmount,
            baseTokenConversion,
            baseTokenDecimals,
            shortTokenDecimals
        );

        // Repay Aave loan with the amount of short token received from Uniswap
        repayAsset(_shortToken, amountOut);

        /// @dev shortTokenConversion = (10 ** (18 - IERC20Metadata(_shortToken).decimals()))
        uint256 debtAfterRepay = getOutstandingDebt(_shortToken) * (10 ** (18 - shortTokenDecimals)); // Wei, as that's what getPositionGains wants

        // Withdraw correct percentage of collateral, and return to user
        if (_withdrawCollateral) {
            uint256 withdrawalAmount = CapitalLib.getMaxWithdrawal(address(this), shaaveLTV);

            if (withdrawalAmount > 0) {
                withdraw(withdrawalAmount / baseTokenConversion);
            }
        }

        // If trade was profitable, pay user gains
        uint256 backingBaseAmountWei = (userPositions[_shortToken].backingBaseAmount - amountIn) * baseTokenConversion;
        uint256 gains = CapitalLib.getPositionGains(
            _shortToken, baseToken, _percentageReduction, backingBaseAmountWei, debtAfterRepay
        );
        if (gains > 0) {
            SafeTransferLib.safeTransfer(ERC20(baseToken), msg.sender, gains / baseTokenConversion);
        }

        // Update child contract's accounting
        userPositions[_shortToken].baseAmountsSwapped.push(amountIn);
        userPositions[_shortToken].shortTokenAmountsReceived.push(amountOut);
        userPositions[_shortToken].backingBaseAmount -= (amountIn + gains / baseTokenConversion);

        if (debtAfterRepay == 0) {
            userPositions[_shortToken].hasDebt = false;
        }

        return true;
    }
}
