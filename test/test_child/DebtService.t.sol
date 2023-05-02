// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Foundry
import {Test} from "forge-std/Test.sol";

// External Package Imports
import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";

// Local file imports
import {IPool} from "../../src/interfaces/aave/IPool.sol";
import {IAaveOracle} from "../../src/interfaces/aave/IAaveOracle.sol";
import {IERC20Metadata, IERC20} from "../../src/interfaces/token/IERC20Metadata.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";
import {PricingLib} from "../../src/libraries/PricingLib.sol";
import {CapitalLib} from "../../src/libraries/CapitalLib.sol";
import {DebtServiceHarness} from "../../test/harness/child/DebtServiceHarness.t.sol";
import {ChildUtils} from "../../test/common/ChildUtils.t.sol";
import {TestHelperFunctions} from "../common/TestHelperFunctions.t.sol";
import {
    TEST_USER,
    USDC_ADDRESS,
    WBTC_ADDRESS,
    AAVE_ORACLE,
    AAVE_POOL,
    AMOUNT_OUT_MINIMUM_PERCENTAGE,
    STATIC_PRICE_AAVE_ORACLE_USDC,
    STATIC_PRICE_AAVE_ORACLE_WBTC
} from "../common/Constants.t.sol";

contract DebtServiceTest is ChildUtils {
    using PricingLib for address;
    using MathLib for uint256;

    // Variable Declaration
    address testUser;
    address baseToken;
    address shortToken;
    uint256 testShaaveLTV;
    uint256 baseTokenDecimals;
    uint256 shortTokenDecimals;
    uint256 baseTokenConversion;
    uint256 shortTokenConversion;

    // Contracts
    DebtServiceHarness testDebtServiceHarness;

    // Events
    event BorrowSuccess(address user, address borrowTokenAddress, uint256 amount);

    function setUp() public {
        // Instantiate Variables
        testUser = address(this);
        baseToken = USDC_ADDRESS;
        shortToken = WBTC_ADDRESS;
        testShaaveLTV = ChildUtils.getShaaveLTV(baseToken);
        shortTokenDecimals = IERC20Metadata(shortToken).decimals();
        baseTokenDecimals = IERC20Metadata(baseToken).decimals();
        shortTokenConversion = 10 ** (18 - shortTokenDecimals);
        baseTokenConversion = 10 ** (18 - baseTokenDecimals);

        // Instantiate DebtServiceHarness
        testDebtServiceHarness = new DebtServiceHarness(testUser, baseToken, baseTokenDecimals, testShaaveLTV);

        // Mock AAVE ORACLE pricing
        vm.mockCall(
            AAVE_ORACLE,
            abi.encodeWithSelector(IAaveOracle(AAVE_ORACLE).getAssetPrice.selector, shortToken),
            abi.encode(STATIC_PRICE_AAVE_ORACLE_WBTC)
        );
        vm.mockCall(
            AAVE_ORACLE,
            abi.encodeWithSelector(IAaveOracle(AAVE_ORACLE).getAssetPrice.selector, baseToken),
            abi.encode(STATIC_PRICE_AAVE_ORACLE_USDC)
        );
    }

    function test_borrowAsset(uint256 baseTokenAmount) public {
        // Arrange
        uint256 borrowAmountActual; // (Units: shortToken decimals)
        uint256 borrowAmountExpected; // (Units: shortToken decimals)
        uint256 baseTokenAmountMin; // (Units: baseToken decimals)
        uint256 baseTokenAmountMax; // (Units: baseToken decimals)

        // Enforce Upper limit is 1,000,000 baseTokens.
        // NOTE: This limit is dependent on AAVE and may need to be mocked in the future to prevent indeterminant reverts.
        baseTokenAmountMax = 1e6 * baseTokenDecimals;

        // baseTokenAmount below this will cause numerator < denominator in
        baseTokenAmountMin =
            (shortTokenConversion * shortToken.pricedIn(baseToken) * 100) / (baseTokenConversion * testShaaveLTV * 1e18);

        // Limit fuzz input.
        vm.assume(baseTokenAmount > baseTokenAmountMin && baseTokenAmount < baseTokenAmountMax);

        // Expectations
        borrowAmountExpected = ChildUtils.getBorrowAmount(baseTokenAmount, baseToken, shortToken);
        vm.expectEmit(true, true, true, true, address(testDebtServiceHarness));
        emit BorrowSuccess(testUser, shortToken, borrowAmountExpected);

        // Supply
        deal(baseToken, address(testDebtServiceHarness), baseTokenAmount);

        // Act
        borrowAmountActual =
            testDebtServiceHarness.exposed_borrowAsset(shortToken, testUser, baseTokenAmount, shortTokenDecimals);

        // Assert
        assertEq(borrowAmountExpected, borrowAmountActual);
    }

    function testCannot_borrowAsset_baseTokenAmountTooSmall(uint256 baseTokenAmount) public {
        // Arrange
        uint256 baseTokenAmountMin; // (Units: baseToken decimals)

        // baseTokenAmount below this will cause numerator < denominator in
        baseTokenAmountMin =
            (shortTokenConversion * shortToken.pricedIn(baseToken) * 100) / (baseTokenConversion * testShaaveLTV * 1e18);

        // Limit fuzz input.
        vm.assume(baseTokenAmount < baseTokenAmountMin);

        // Supply
        deal(baseToken, address(testDebtServiceHarness), baseTokenAmount);

        // Act
        vm.expectRevert();
        testDebtServiceHarness.exposed_borrowAsset(shortToken, testUser, baseTokenAmount, shortTokenDecimals);
    }

    function test_repayAsset(uint256 repayAmount) public {
        // Arrange
        address variableDebtTokenAddress;
        uint256 baseTokenAmount; // (Units: baseToken decimals)
        uint256 borrowAmount; // (Units: shortToken decimals)
        uint256 debtBeforeRepay; // (Units: shortToken decimals)
        uint256 debtAfterRepay; // (Units: shortToken decimals)

        baseTokenAmount = (10 ** baseTokenDecimals) * 2e4;
        borrowAmount = ChildUtils.getBorrowAmount(baseTokenAmount, baseToken, shortToken);

        // Limit fuzz input.
        vm.assume(repayAmount > 0 && repayAmount <= borrowAmount);

        // Supply ShAave user baseToken
        deal(baseToken, address(testDebtServiceHarness), baseTokenAmount);

        // Aave borrow. Take on debt to repay.
        vm.startPrank(address(testDebtServiceHarness));
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, baseTokenAmount);
        IPool(AAVE_POOL).supply(baseToken, baseTokenAmount, address(testDebtServiceHarness), 0);
        IPool(AAVE_POOL).borrow(shortToken, borrowAmount, 2, 0, address(testDebtServiceHarness));
        vm.stopPrank();

        // Supply ShAave user with shortToken
        deal(shortToken, address(testDebtServiceHarness), repayAmount);

        // Trick Aave into thinking it's not a flash loan
        vm.warp(block.timestamp + 120);

        // Obtain debt amount
        variableDebtTokenAddress = IPool(AAVE_POOL).getReserveData(shortToken).variableDebtTokenAddress;
        debtBeforeRepay = IERC20(variableDebtTokenAddress).balanceOf(address(testDebtServiceHarness));

        // Act
        testDebtServiceHarness.exposed_repayAsset(shortToken, repayAmount);
        debtAfterRepay = IERC20(variableDebtTokenAddress).balanceOf(address(testDebtServiceHarness));

        // Assert
        assertApproxEqAbs(debtAfterRepay, debtBeforeRepay - repayAmount, 1);
    }

    function testCannot_repayAsset_amountZeroError() public {
        // Arrange
        uint256 repayAmount = 0; // Error. Can't repay nothing
        uint256 baseTokenAmount; // (Units: baseToken decimals)
        uint256 borrowAmount; // (Units: shortToken decimals)

        baseTokenAmount = (10 ** baseTokenDecimals) * 2e4; // Arbitrary amount of collateral
        borrowAmount = ChildUtils.getBorrowAmount(baseTokenAmount, baseToken, shortToken);

        // Supply ShAave user baseToken
        deal(baseToken, address(testDebtServiceHarness), baseTokenAmount);

        // Aave borrow. Mint ATokens and take on debt to repay.
        vm.startPrank(address(testDebtServiceHarness));
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, baseTokenAmount);
        IPool(AAVE_POOL).supply(baseToken, baseTokenAmount, address(testDebtServiceHarness), 0);
        IPool(AAVE_POOL).borrow(shortToken, borrowAmount, 2, 0, address(testDebtServiceHarness));
        vm.stopPrank();

        // Supply ShAave user with shortToken
        deal(shortToken, address(testDebtServiceHarness), repayAmount);

        // Trick Aave into thinking it's not a flash loan
        vm.warp(block.timestamp + 120);

        // Act
        vm.expectRevert();
        testDebtServiceHarness.exposed_repayAsset(shortToken, repayAmount);
    }

    function test_getOutstandingDebt() public {
        // Arrange
        uint256 baseTokenAmount; // (Units: baseToken decimals)
        uint256 borrowAmount; // (Units: shortToken decimals)
        uint256 outstandingDebtActual; // (Units: shortToken decimals)

        baseTokenAmount = (10 ** baseTokenDecimals) * 2e4; // Arbitrary amount of collateral
        borrowAmount = ChildUtils.getBorrowAmount(baseTokenAmount, baseToken, shortToken);

        // Supply ShAave user baseToken
        deal(baseToken, address(testDebtServiceHarness), baseTokenAmount);

        // Aave borrow. Take on debt to repay.
        vm.startPrank(address(testDebtServiceHarness));
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, baseTokenAmount);
        IPool(AAVE_POOL).supply(baseToken, baseTokenAmount, address(testDebtServiceHarness), 0);
        IPool(AAVE_POOL).borrow(shortToken, borrowAmount, 2, 0, address(testDebtServiceHarness));
        vm.stopPrank();

        // Act
        outstandingDebtActual = testDebtServiceHarness.getOutstandingDebt(shortToken);

        // Assert
        assertEq(outstandingDebtActual, borrowAmount);
    }

    function testCannot_getOutstandingDebt_Unauthorized(address sender) public {
        vm.assume(sender != testUser);

        // Act
        vm.expectRevert("Unauthorized.");
        vm.prank(sender);
        testDebtServiceHarness.getOutstandingDebt(shortToken);
    }

    // Ensure it fails if we take a position out as normal
    function test_payOutstandingDebt_withdraw(uint256 repayAmount) public {
        // Arrange
        uint256 collateralSupplyAmount; // (Units: baseToken decimals)
        uint256 borrowAmount; // (Units: shortToken decimals)
        uint256 preActDebt; // (Units: shortToken decimals)
        uint256 postActDebt; // (Units: shortToken decimals)
        uint256 preCollateralOnAave; // (Units: baseToken decimals)
        uint256 postCollateralOnAave; // (Units: baseToken decimals)
        uint256 preUserBaseBalance; // (Units: baseToken decimals)
        uint256 postUserBaseBalance; // (Units: baseToken decimals)
        collateralSupplyAmount = (10 ** baseTokenDecimals) * 2e4; // Arbitrary amount of collateral
        borrowAmount = ChildUtils.getBorrowAmount(collateralSupplyAmount, baseToken, shortToken);

        // Deal ShAave baseToken, so it can provide collateral
        deal(baseToken, address(testDebtServiceHarness), collateralSupplyAmount);

        // Aave borrow. Take on debt to repay.
        vm.startPrank(address(testDebtServiceHarness));
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, collateralSupplyAmount);
        IPool(AAVE_POOL).supply(baseToken, collateralSupplyAmount, address(testDebtServiceHarness), 0);
        IPool(AAVE_POOL).borrow(shortToken, borrowAmount, 2, 0, address(testDebtServiceHarness));
        vm.stopPrank();

        // Trick Aave into thinking it's not a flash loan
        vm.warp(block.timestamp + 120);

        (preCollateralOnAave, preActDebt,, preUserBaseBalance) =
            getTokenData(address(testDebtServiceHarness), baseToken, shortToken);

        // Deal user shortToken, so it can repay outstanding debt
        vm.assume(repayAmount > 0 && repayAmount <= preActDebt);
        deal(shortToken, testUser, repayAmount);

        // Act
        SafeTransferLib.safeApprove(ERC20(shortToken), address(testDebtServiceHarness), repayAmount);
        bool success = testDebtServiceHarness.payOutstandingDebt(shortToken, repayAmount, true);

        // Post-action data extraction
        (postCollateralOnAave, postActDebt,, postUserBaseBalance) =
            getTokenData(address(testDebtServiceHarness), baseToken, shortToken);
        uint256 userBaseBalanceIncrease = postUserBaseBalance - preUserBaseBalance;
        uint256 collateralOnAaveDecrease = preCollateralOnAave - postCollateralOnAave;

        // Assert
        assert(success);
        assertApproxEqAbs(postActDebt, preActDebt - repayAmount, 1);
        assertApproxEqAbs(postCollateralOnAave, preCollateralOnAave - userBaseBalanceIncrease, 1);
        assertApproxEqAbs(postUserBaseBalance, preUserBaseBalance + collateralOnAaveDecrease, 1);
    }

    function test_payOutstandingDebt_no_withdraw(uint256 repayAmount) public {
        // Arrange
        uint256 collateralSupplyAmount; // (Units: baseToken decimals)
        uint256 borrowAmount; // (Units: shortToken decimals)
        uint256 preActDebt; // (Units: shortToken decimals)
        uint256 postActDebt; // (Units: shortToken decimals)
        uint256 preCollateralOnAave; // (Units: baseToken decimals)
        uint256 postCollateralOnAave; // (Units: baseToken decimals)
        uint256 preUserBaseBalance; // (Units: baseToken decimals)
        uint256 postUserBaseBalance; // (Units: baseToken decimals)
        collateralSupplyAmount = (10 ** baseTokenDecimals) * 2e4; // Arbitrary amount of collateral
        borrowAmount = ChildUtils.getBorrowAmount(collateralSupplyAmount, baseToken, shortToken);

        // Deal ShAave baseToken, so it can provide collateral
        deal(baseToken, address(testDebtServiceHarness), collateralSupplyAmount);

        // Aave borrow. Take on debt to repay.
        vm.startPrank(address(testDebtServiceHarness));
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, collateralSupplyAmount);
        IPool(AAVE_POOL).supply(baseToken, collateralSupplyAmount, address(testDebtServiceHarness), 0);
        IPool(AAVE_POOL).borrow(shortToken, borrowAmount, 2, 0, address(testDebtServiceHarness));
        vm.stopPrank();

        // Trick Aave into thinking it's not a flash loan
        vm.warp(block.timestamp + 120);

        (preCollateralOnAave, preActDebt,, preUserBaseBalance) =
            getTokenData(address(testDebtServiceHarness), baseToken, shortToken);

        // Deal user shortToken, so it can repay outstanding debt
        vm.assume(repayAmount > 0 && repayAmount <= preActDebt);
        deal(shortToken, testUser, repayAmount);

        // Act
        SafeTransferLib.safeApprove(ERC20(shortToken), address(testDebtServiceHarness), repayAmount);
        bool success = testDebtServiceHarness.payOutstandingDebt(shortToken, repayAmount, false);

        // Post-action data extraction
        (postCollateralOnAave, postActDebt,, postUserBaseBalance) =
            getTokenData(address(testDebtServiceHarness), baseToken, shortToken);

        // Assert
        assert(success);
        assertApproxEqAbs(postActDebt, preActDebt - repayAmount, 1);
        assertEq(postUserBaseBalance, preUserBaseBalance);
        assertEq(postCollateralOnAave, preCollateralOnAave);
    }

    function testCannot_payOutstandingDebt_unauthorized(address sender) public {
        vm.assume(sender != testUser);

        // Act
        vm.startPrank(sender);
        vm.expectRevert("Unauthorized.");
        testDebtServiceHarness.payOutstandingDebt(shortToken, 1e8, true);
    }

    function test_withdraw_LessThanMax(uint256 withdrawAmount) public {
        // Arrange
        uint256 baseTokenAmount; // (Units: baseToken decimals)
        uint256 withdrawAmountMax; // Exceeding this amount causes Aave health factor < 1 (Units: baseToken decimals)
        uint256 totalCollateralBase; // total collateral of the user (Units: baseToken decimals)
        uint256 totalDebtBase; // total debt of the user (Units: shortToken decimals)
        uint256 currentLiquidationThreshold; // use to calculate max withdraw

        baseTokenAmount = (10 ** baseTokenDecimals) * 2e4; // Arbitrary amount of collateral

        // Supply ShAave user baseToken
        deal(baseToken, address(testDebtServiceHarness), baseTokenAmount);

        // Aave supply. Mint ATokens to later burn with withdraw
        vm.startPrank(address(testDebtServiceHarness));
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, baseTokenAmount);
        IPool(AAVE_POOL).supply(baseToken, baseTokenAmount, address(testDebtServiceHarness), 0);
        vm.stopPrank();

        (totalCollateralBase, totalDebtBase,, currentLiquidationThreshold,,) =
            IPool(AAVE_POOL).getUserAccountData(address(testDebtServiceHarness));

        // (https://docs.aave.com/developers/guides/liquidations#how-is-health-factor-calculated)
        withdrawAmountMax = (totalCollateralBase - ((totalDebtBase * 1e13) / (currentLiquidationThreshold * 1e9))) / 1e2;

        // Limit fuzz input.
        vm.assume(withdrawAmount > 0 && withdrawAmount < withdrawAmountMax);

        // Act
        testDebtServiceHarness.exposed_withdraw(withdrawAmount);
    }

    function test_withdraw_Max() public {
        // Arrange
        uint256 baseTokenAmount; // (Units: baseToken decimals)
        uint256 withdrawAmount = type(uint256).max; // Aave recognizes this as full withdraw (Units: baseToken decimals)

        baseTokenAmount = (10 ** baseTokenDecimals) * 2e4; // Arbitrary amount of collateral

        // Supply ShAave user baseToken
        deal(baseToken, address(testDebtServiceHarness), baseTokenAmount);

        // Aave supply. Mint ATokens to later burn with withdraw
        vm.startPrank(address(testDebtServiceHarness));
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, baseTokenAmount);
        IPool(AAVE_POOL).supply(baseToken, baseTokenAmount, address(testDebtServiceHarness), 0);
        vm.stopPrank();

        // Act
        testDebtServiceHarness.exposed_withdraw(withdrawAmount);

        (uint256 totalCollateralBase,, uint256 availableBorrowsBase,,,) =
            IPool(AAVE_POOL).getUserAccountData(address(testDebtServiceHarness));

        // Assert
        assertEq(0, totalCollateralBase);
        assertEq(0, availableBorrowsBase);
    }

    function testCannot_withdraw_AmountTooLargeError(uint256 withdrawAmount) public {
        // Arrange
        uint256 baseTokenAmount; // (Units: baseToken decimals)
        uint256 withdrawAmountMax; // Exceeding this amount causes Aave health factor < 1 (Units: baseToken decimals)
        uint256 totalCollateralBase; // total collateral of the user (Units: baseToken decimals)
        uint256 totalDebtBase; // total debt of the user (Units: shortToken decimals)
        uint256 currentLiquidationThreshold; // use to calculate max withdraw

        baseTokenAmount = (10 ** baseTokenDecimals) * 2e4; // Arbitrary amount of collateral

        // Supply ShAave user baseToken
        deal(baseToken, address(testDebtServiceHarness), baseTokenAmount);

        // Aave supply. Mint ATokens to later burn with withdraw
        vm.startPrank(address(testDebtServiceHarness));
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, baseTokenAmount);
        IPool(AAVE_POOL).supply(baseToken, baseTokenAmount, address(testDebtServiceHarness), 0);
        vm.stopPrank();

        (totalCollateralBase, totalDebtBase,, currentLiquidationThreshold,,) =
            IPool(AAVE_POOL).getUserAccountData(address(testDebtServiceHarness));

        // (https://docs.aave.com/developers/guides/liquidations#how-is-health-factor-calculated)
        // withdrawAmountMax will be totalCollateralBase when no debt is taken
        withdrawAmountMax = (totalCollateralBase - ((totalDebtBase * 1e13) / (currentLiquidationThreshold * 1e9))) / 1e2;

        // Limit fuzz input.
        vm.assume(withdrawAmount > withdrawAmountMax && withdrawAmount != type(uint256).max);

        // Act
        vm.expectRevert();
        testDebtServiceHarness.exposed_withdraw(withdrawAmount);
    }

    function test_withdrawCollateral(uint256 withdrawalAmount) public {
        // Setup
        uint256 baseTokenAmount; // (Units: baseToken decimals)
        uint256 preCollateralOnAave; // (Units: baseToken decimals)
        uint256 postCollateralOnAave; // (Units: baseToken decimals)
        uint256 preUserBaseBalance; // (Units: baseToken decimals)
        uint256 postUserBaseBalance; // (Units: baseToken decimals)

        baseTokenAmount = (10 ** baseTokenDecimals) * 2e4; // Arbitrary amount of collateral

        // Aave supply. Mint ATokens to later burn with withdraw
        deal(baseToken, address(testDebtServiceHarness), baseTokenAmount);
        vm.startPrank(address(testDebtServiceHarness));
        SafeTransferLib.safeApprove(ERC20(baseToken), AAVE_POOL, baseTokenAmount);
        IPool(AAVE_POOL).supply(baseToken, baseTokenAmount, address(testDebtServiceHarness), 0);
        vm.stopPrank();

        // Pre-action data extraction
        uint256 maxWithdrawal =
            CapitalLib.getMaxWithdrawal(address(testDebtServiceHarness), testShaaveLTV) / baseTokenConversion;
        vm.assume(withdrawalAmount > 0 && withdrawalAmount <= maxWithdrawal);

        (preCollateralOnAave,,, preUserBaseBalance) =
            getTokenData(address(testDebtServiceHarness), baseToken, shortToken);

        // Act
        testDebtServiceHarness.withdrawCollateral(withdrawalAmount);

        // Post-action data extraction
        (postCollateralOnAave,,, postUserBaseBalance) =
            getTokenData(address(testDebtServiceHarness), baseToken, shortToken);
        uint256 userBaseBalanceIncrease = postUserBaseBalance - preUserBaseBalance;
        uint256 collateralOnAaveDecrease = preCollateralOnAave - postCollateralOnAave;

        // Assert
        assertApproxEqAbs(postCollateralOnAave, preCollateralOnAave - userBaseBalanceIncrease, 1);
        assertApproxEqAbs(postUserBaseBalance, preUserBaseBalance + collateralOnAaveDecrease, 1);
    }

    function testCannot_withdrawCollateral_unauthorized(address sender) public {
        vm.assume(sender != testUser);

        uint256 withdrawAmount = 1e6;

        // Act
        vm.startPrank(sender);
        vm.expectRevert("Unauthorized.");
        testDebtServiceHarness.withdrawCollateral(withdrawAmount);
    }

    function test_getAaveAcountingData() public view {
        // Act
        testDebtServiceHarness.getAaveAccountData();
    }

    function testCannot_getAaveAcountingData_unauthorized(address sender) public {
        vm.assume(sender != testUser);

        // Act
        vm.startPrank(sender);
        vm.expectRevert("Unauthorized.");
        testDebtServiceHarness.getAaveAccountData();
    }
}
