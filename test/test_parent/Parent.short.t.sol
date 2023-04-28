// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "solmate/utils/SafeTransferLib.sol";
import "@aave-protocol/interfaces/IPool.sol";

import "../../src/parent/Parent.sol";
import "../../src/child/Child.sol";
import "../../src/libraries/AddressLib.sol";
import "../../src/interfaces/IChild.sol";
import "../common/ChildUtils.t.sol";

contract ParentShortTest is ChildUtils, TestUtils {
    using AddressLib for address[];

    address retrievedBaseToken;
    address[] children;
    address[] baseTokens;

    uint256 expectedChildCount;
    uint256 preActionChildCount;
    uint256 postActionChildCount;

    // Contracts
    Parent shaaveParent;

    function setUp() public {
        shaaveParent = new Parent(10);
    }

    /// @dev tests that child contracts get created, in accordance with first-time shorts
    function test_addShortPosition_child_creation() public {
        // Setup
        uint256 baseTokenAmount = (10 ** IERC20Metadata(BASE_TOKEN).decimals()); // 1 unit in correct decimals
        deal(BASE_TOKEN, address(this), baseTokenAmount);
        SafeTransferLib.safeApprove(ERC20(BASE_TOKEN), address(shaaveParent), baseTokenAmount);

        // Expectations
        address child = shaaveParent.userContracts(address(this), BASE_TOKEN);
        assertEq(child, address(0), "child should not exist, but does.");

        // Act
        shaaveParent.addShortPosition(SHORT_TOKEN, BASE_TOKEN, baseTokenAmount);

        // Assertions
        child = shaaveParent.userContracts(address(this), BASE_TOKEN);
        assertEq(IChild(child).baseToken(), BASE_TOKEN, "Incorrect baseToken address on child.");
    }

    /// @dev tests that existing child is utilized for subsequent shorts
    function test_addShortPosition_not_first() public {
        uint256 amountMultiplier = 1;
        // Setup
        uint256 baseTokenAmount = (10 ** IERC20Metadata(BASE_TOKEN).decimals()) * amountMultiplier; // 1 unit in correct decimals * amountMultiplier
        deal(BASE_TOKEN, address(this), baseTokenAmount);
        SafeTransferLib.safeApprove(ERC20(BASE_TOKEN), address(shaaveParent), baseTokenAmount);

        // Expectations 1
        uint256 borrowAmount_1 = getBorrowAmount(baseTokenAmount / 2, BASE_TOKEN, SHORT_TOKEN);
        (, uint256 amountOut_1) = swapExactInputExpect(SHORT_TOKEN, USDC_ADDRESS, borrowAmount_1);

        // Act 1: short using USDC
        shaaveParent.addShortPosition(SHORT_TOKEN, BASE_TOKEN, baseTokenAmount / 2);

        // Data extraction 1
        address child = shaaveParent.userContracts(address(this), BASE_TOKEN);
        Child.PositionData[] memory accountingData = IChild(child).getAccountingData();

        // Expectations 2
        uint256 borrowAmount_2 = getBorrowAmount(baseTokenAmount / 2, BASE_TOKEN, SHORT_TOKEN);
        (, uint256 amountOut_2) = swapExactInputExpect(SHORT_TOKEN, USDC_ADDRESS, borrowAmount_2);

        // Act 2: short using USDC again
        vm.warp(block.timestamp + 120);
        shaaveParent.addShortPosition(SHORT_TOKEN, BASE_TOKEN, baseTokenAmount / 2);

        // Data extraction 2 (using same child from first short)
        accountingData = IChild(child).getAccountingData();

        // Assertions: ensure accounting data reflects more than one short
        assertEq(accountingData[0].shortTokenAmountsSwapped.length, 2, "Incorrect shortTokenAmountsSwapped length.");
        assertEq(accountingData[0].backingBaseAmount, amountOut_1 + amountOut_2, "Incorrect backingBaseAmount.");
    }

    /// @dev tests that child contract accounting data gets updated properly after a short position is opened
    function test_addShortPosition_accounting(uint256 amountMultiplier) public {
        // Assumptions
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1000);

        // Setup
        uint256 baseTokenAmount = (10 ** IERC20Metadata(BASE_TOKEN).decimals()) * amountMultiplier; // 1 unit in correct decimals * amountMultiplier
        deal(BASE_TOKEN, address(this), baseTokenAmount);
        SafeTransferLib.safeApprove(ERC20(BASE_TOKEN), address(shaaveParent), baseTokenAmount);

        // Expectations
        uint256 borrowAmount = getBorrowAmount(baseTokenAmount, BASE_TOKEN, SHORT_TOKEN);
        (uint256 amountIn, uint256 amountOut) = swapExactInputExpect(SHORT_TOKEN, BASE_TOKEN, borrowAmount);

        // Act
        shaaveParent.addShortPosition(SHORT_TOKEN, BASE_TOKEN, baseTokenAmount);

        // Post-action data extraction
        address child = shaaveParent.userContracts(address(this), BASE_TOKEN);
        Child.PositionData[] memory accountingData = IChild(child).getAccountingData();
        (uint256 aTokenBalance, uint256 debtTokenBalance, uint256 baseTokenBalance, uint256 userBaseBalance) =
            getTokenData(child, BASE_TOKEN, SHORT_TOKEN);

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
        assertEq(accountingData[0].collateralAmounts[0], baseTokenAmount, "Incorrect collateralAmounts.");
        assertEq(accountingData[0].backingBaseAmount, amountOut, "Incorrect backingBaseAmount.");
        assertEq(accountingData[0].shortTokenAddress, SHORT_TOKEN, "Incorrect shortTokenAddress.");
        assertEq(accountingData[0].hasDebt, true, "Incorrect hasDebt.");

        // Token balances
        // uint256 acceptableTolerance = 3;
        // int256 collateralDiff = int256(baseTokenAmount) - int256(aTokenBalance);
        // uint256 collateralDiffAbs = collateralDiff < 0 ? uint256(-collateralDiff) : uint256(collateralDiff);
        // int256 debtDiff = int256(amountIn) - int256(debtTokenBalance);
        // uint256 debtDiffAbs = debtDiff < 0 ? uint256(-debtDiff) : uint256(debtDiff);

        assertApproxEqAbs(baseTokenAmount, aTokenBalance, 3);
        assertApproxEqAbs(amountIn, debtTokenBalance, 3);
        // assert(collateralDiffAbs <= acceptableTolerance); // Small tolerance, due to potential interest
        // assert(debtDiffAbs <= acceptableTolerance); // Small tolerance, due to potential interest
        assertEq(baseTokenBalance, amountOut, "Incorrect baseTokenBalance.");
        assertEq(userBaseBalance, 0, "Incorrect baseTokenBalance.");
    }
}
