// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// External Package Imports
import "solmate/utils/SafeTransferLib.sol";
import "@aave-protocol/interfaces/IPool.sol";

// Local imports
import "../interfaces/IERC20Metadata.sol";
import "../libraries/PricingLib.sol";
import "../libraries/MathLib.sol";
import "../libraries/CapitalLib.sol";
import {AccountingService} from "./AccountingService.sol";

import "forge-std/console.sol";

abstract contract DebtService is AccountingService {
    using PricingLib for address;
    using MathLib for uint256;

    // Constants
    address private constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address private constant AAVE_ORACLE = 0xb023e699F5a33916Ea823A16485e259257cA8Bd1;

    // Immutables
    address public immutable baseToken;
    uint256 public immutable shaaveLTV;
    uint256 public immutable baseTokenConversion; // Use this to express _baseTokenAmount with 18 decimals
    uint256 internal immutable baseTokenDecimals;

    // Events
    event BorrowSuccess(address user, address borrowTokenAddress, uint256 amount);

    constructor(address _baseToken, uint256 _baseTokenDecimals, uint256 _shaaveLTV) {
        baseToken = _baseToken;
        baseTokenDecimals = _baseTokenDecimals;
        baseTokenConversion = 10 ** (18 - _baseTokenDecimals);
        shaaveLTV = _shaaveLTV;
    }

    /**
     * @return borrowAmount This is expressed in shortToken decimals
     */
    function borrowAsset(address _shortToken, address _user, uint256 _baseTokenAmount, uint256 _shortTokenDecimals)
        internal
        returns (uint256 borrowAmount)
    {
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, _baseTokenAmount);
        IPool(AAVE_POOL).supply(baseToken, _baseTokenAmount, address(this), 0);

        // Calculate the amount that can be borrowed
        uint256 shortTokenConversion = (10 ** (18 - _shortTokenDecimals));
        uint256 priceOfShortTokenInBase = _shortToken.pricedIn(baseToken); // Wei
        borrowAmount = ((_baseTokenAmount * baseTokenConversion * shaaveLTV) / 100).dividedBy(
            priceOfShortTokenInBase, 18
        ) / shortTokenConversion;
        // Since parent supplied collateral on this contract's behalf, borrow asset
        IPool(AAVE_POOL).borrow(_shortToken, borrowAmount, 2, 0, address(this));
        emit BorrowSuccess(_user, _shortToken, borrowAmount);
    }

    function repayAsset(address _shortToken, uint256 _amount) internal {
        // Repay Aave loan with the amount of short token received from Uniswap
        SafeTransferLib.safeApprove(ERC20(_shortToken), AAVE_POOL, _amount);
        IPool(AAVE_POOL).repay(_shortToken, _amount, 2, address(this));
    }

    /**
     * @dev Returns this contract's total debt for a given short token (principle + interest).
     * @param _shortToken The address of the token the user has shorted.
     * @return outstandingDebt This contract's total debt for a given short token, in whatever decimals that short token has.
     *
     */
    function getOutstandingDebt(address _shortToken) public view userOnly returns (uint256 outstandingDebt) {
        address variableDebtTokenAddress = IPool(AAVE_POOL).getReserveData(_shortToken).variableDebtTokenAddress;
        outstandingDebt = IERC20(variableDebtTokenAddress).balanceOf(address(this));
    }

    /**
     * @dev  This function repays child's outstanding debt for a given short, in the case where all
     *       base token has been used already.
     * @param _shortToken The address of the token the user has shorted.
     * @param _paymentAmount The amount that's sent to repay the outstanding debt.
     * @param _withdrawCollateral A boolean to withdraw collateral or not.
     */
    function payOutstandingDebt(address _shortToken, uint256 _paymentAmount, bool _withdrawCollateral)
        public
        userOnly
        returns (bool)
    {
        require(userPositions[_shortToken].backingBaseAmount == 0, "Position is still open.");

        // Repay debt
        SafeTransferLib.safeTransferFrom(ERC20(_shortToken), msg.sender, address(this), _paymentAmount);
        repayAsset(_shortToken, _paymentAmount);

        // Optionally withdraw collateral
        if (_withdrawCollateral) {
            uint256 withdrawalAmount = CapitalLib.getMaxWithdrawal(address(this), shaaveLTV);
            withdraw(withdrawalAmount / baseTokenConversion);
        }

        // 3. Update accounting
        if (getOutstandingDebt(_shortToken) == 0) {
            userPositions[_shortToken].hasDebt = false;
        }

        return true;
    }

    function withdraw(uint256 _amount) internal {
        IPool(AAVE_POOL).withdraw(baseToken, _amount, user);
    }

    /**
     * @dev  This function allows a user to withdraw collateral on their Aave account, up to an
     * amount that does not raise their debt-to-collateral ratio above 70%.
     * @param _amount The amount of collateral (in Wei) the user wants to withdraw.
     */
    function withdrawCollateral(uint256 _amount) public userOnly {
        uint256 maxWithdrawalAmount = CapitalLib.getMaxWithdrawal(address(this), shaaveLTV);

        require(_amount <= maxWithdrawalAmount, "Exceeds max withdrawal amount.");

        withdraw(_amount);
    }

    /**
     * @dev  This function returns a list of data related to the Aave account that this contract has.
     * @return totalCollateralBase The value of all supplied collateral, in base token.
     * @return totalDebtBase The value of all debt, in base token.
     * @return availableBorrowBase The amount, in base token, that can still be borrowed.
     * @return currentLiquidationThreshold Aave's liquidation threshold.
     * @return ltv The (Aave) account-wide loan-to-value ratio.
     * @return healthFactor Aave's account-wide health factor.
     * @return maxWithdrawalAmount The maximum amount of collateral a user can withdraw, given Shaave's LTV.
     *
     */
    function getAaveAccountData()
        public
        view
        userOnly
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor,
            uint256 maxWithdrawalAmount
        )
    {
        maxWithdrawalAmount = CapitalLib.getMaxWithdrawal(address(this), shaaveLTV);
        (totalCollateralBase, totalDebtBase, availableBorrowBase, currentLiquidationThreshold, ltv, healthFactor) =
            IPool(AAVE_POOL).getUserAccountData(address(this)); // Must multiply by 1e10 to get Wei
    }
}
