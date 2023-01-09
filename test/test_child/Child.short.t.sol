// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Local file imports
import {Child} from "../../src/child/Child.sol";
import {IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {AddressLib} from "../../src/libraries/AddressLib.sol";
import {UniswapUtils, ChildUtils} from "../common/ChildUtils.t.sol";
import {USDC_ADDRESS, wBTC_ADDRESS} from "../common/Constants.t.sol";

/* TODO: The following still needs to be tested here:
1. XXX Reduce position: Test actual runthrough without mock
2. XXX Reduce position 100% with no gains, and ensure no gains (easy)
3. XXX Reduce position by < 100%, with gains, and ensure correct amount gets paid
4. Reduce position by < 100%, with no gains and ensure no gains
5. Try to short with all supported collateral -- nested for loop for short tokens?
6. Then, parent can be tested*/

contract ChildShortTest is ChildUtils {
    using AddressLib for address[];

    // Test tokens
    address _shortToken;
    address _baseToken;

    // Contracts
    Child testShaaveChild;

    function setUp() public {
        // Token Setup
        _baseToken = USDC_ADDRESS;
        _shortToken = wBTC_ADDRESS;

        // Instantiate Child
        testShaaveChild =
            new Child(address(this), _baseToken, IERC20Metadata(_baseToken).decimals(), getShaaveLTV(_baseToken));
    }

    // Events
    event BorrowSuccess(address user, address borrowTokenAddress, uint256 amount);
    event SwapSuccess(
        address user, address tokenInAddress, uint256 tokenInAmount, address tokenOutAddress, uint256 tokenOutAmount
    );
    event PositionAddedSuccess(address user, address shortTokenAddress, uint256 amount);

    // Create a short position of _shortToken funded by all of provided _baseToken
    function test_short(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier < 1e3);

        // Setup
        uint256 collateralAmount = (10 ** IERC20Metadata(_baseToken).decimals()) * amountMultiplier; // 1 uint in correct decimals

        // Supply
        deal(_baseToken, address(testShaaveChild), collateralAmount);

        // Expectations
        uint256 borrowAmount = ChildUtils.getBorrowAmount(collateralAmount, _baseToken, _shortToken);
        (uint256 amountIn, uint256 amountOut) = UniswapUtils.swapExactInputExpect(_shortToken, _baseToken, borrowAmount);
        vm.expectEmit(true, true, true, true, address(testShaaveChild));
        emit BorrowSuccess(address(this), _shortToken, borrowAmount);
        vm.expectEmit(true, true, true, true, address(testShaaveChild));
        emit SwapSuccess(address(this), _shortToken, amountIn, _baseToken, amountOut);
        vm.expectEmit(true, true, true, true, address(testShaaveChild));
        emit PositionAddedSuccess(address(this), _shortToken, borrowAmount);

        // Act
        testShaaveChild.short(_shortToken, collateralAmount, address(this));

        // Post-action data extraction
        Child.PositionData[] memory accountingData = testShaaveChild.getAccountingData();
        (uint256 aTokenBalance, uint256 debtTokenBalance, uint256 baseTokenBalance, uint256 userBaseBalance) =
            getTokenData(address(testShaaveChild), _baseToken, _shortToken);

        // Assertions
        // Length
        assertEq(accountingData.length, 1, "Incorrect accountingData length.");
        assertEq(accountingData[0].shortTokenAmountsSwapped.length, 1, "Incorrect shortTokenAmountsSwapped length.");
        assertEq(accountingData[0].baseAmountsReceived.length, 1, "Incorrect baseAmountsReceived length.");
        assertEq(accountingData[0].collateralAmounts.length, 1, "Incorrect collateralAmounts length.");
        assertEq(accountingData[0].baseAmountsSwapped.length, 0, "Incorrect baseAmountsSwapped length.");
        assertEq(accountingData[0].shortTokenAmountsReceived.length, 0, "Incorrect shortTokenAmountsReceived length.");

        // Values
        assertEq(accountingData[0].shortTokenAmountsSwapped[0], amountIn, "Incorrect shortTokenAmountsSwapped.");
        assertEq(accountingData[0].baseAmountsReceived[0], amountOut, "Incorrect baseAmountsReceived.");
        assertEq(accountingData[0].collateralAmounts[0], collateralAmount, "Incorrect collateralAmounts.");
        assertEq(accountingData[0].backingBaseAmount, amountOut, "Incorrect backingBaseAmount.");
        assertEq(accountingData[0].shortTokenAddress, _shortToken, "Incorrect shortTokenAddress.");
        assertEq(accountingData[0].hasDebt, true, "Incorrect hasDebt.");

        // Test Aave tokens
        uint256 acceptableTolerance = 3;
        int256 collateralDiff = int256(collateralAmount) - int256(aTokenBalance);
        uint256 collateralDiffAbs = collateralDiff < 0 ? uint256(-collateralDiff) : uint256(collateralDiff);
        int256 debtDiff = int256(amountIn) - int256(debtTokenBalance);
        uint256 debtDiffAbs = debtDiff < 0 ? uint256(-debtDiff) : uint256(debtDiff);
        assert(collateralDiffAbs <= acceptableTolerance); // Small tolerance, due to potential interest
        assert(debtDiffAbs <= acceptableTolerance); // Small tolerance, due to potential interest
        assertEq(baseTokenBalance, amountOut, "Incorrect baseTokenBalance.");
        assertEq(userBaseBalance, 0, "Incorrect baseTokenBalance.");
    }
}
