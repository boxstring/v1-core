// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Foundry
import {Test, stdError} from "forge-std/Test.sol";

// External Package Imports
import {IPool} from "@aave-protocol/interfaces/IPool.sol";
import {IAaveOracle} from "@aave-protocol/interfaces/IAaveOracle.sol";
import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";

// Local file imports
import {MathLib} from "../../src/libraries/MathLib.sol";
import {PricingLib} from "../../src/libraries/PricingLib.sol";
import {IERC20Metadata, IERC20} from "../../src/interfaces/IERC20Metadata.sol";
import {DebtServiceHarness} from "../../test/harness/child/DebtServiceHarness.t.sol";
import {ChildUtils} from "../../test/common/ChildUtils.t.sol";
import {TestHelperFunctions} from "../common/TestHelperFunctions.t.sol";
import {
    TEST_USER,
    USDC_ADDRESS,
    wBTC_ADDRESS,
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
        testUser = TEST_USER;
        baseToken = USDC_ADDRESS;
        shortToken = wBTC_ADDRESS;
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

    function test_borrowAsset_nominal(uint256 baseTokenAmount) public {
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

    function test_borrowAsset_baseTokenAmountTooSmallError(uint256 baseTokenAmount) public {
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

    function test_repayAsset_nominal(uint256 repayAmount) public {
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

    function test_repayAsset_amountZeroError() public {
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

    function test_withdraw_AmountTooLargeError(uint256 withdrawAmount) public {
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
        vm.prank(testUser);
        outstandingDebtActual = testDebtServiceHarness.getOutstandingDebt(shortToken);

        // Assert
        assertEq(outstandingDebtActual, borrowAmount);
    }

    function testCannot_getOutstandingDebt_Unauthorized() public {
        // Act
        vm.expectRevert("Unauthorized.");
        testDebtServiceHarness.getOutstandingDebt(shortToken);
    }

    function test_getAaveAcountingData_nominal() public {
        // Act
        vm.prank(testUser);
        testDebtServiceHarness.getAaveAccountData();
    }

    function testCannot_getAaveAcountingData_Unauthorized() public {
        // Act
        vm.expectRevert("Unauthorized.");
        testDebtServiceHarness.getAaveAccountData();
    }

    function test_getOutstandingDebtBase() public {
        // Arrange
        uint256 baseTokenAmount; // (Units: baseToken decimals)
        uint256 borrowAmount; // (Units: shortToken decimals)
        uint256 outstandingDebtBaseActual; // (Units: baseToken decimals)

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
        vm.prank(testUser);
        outstandingDebtBaseActual = testDebtServiceHarness.getOutstandingDebtBase(shortToken);

        // Assert
        assertEq(
            outstandingDebtBaseActual, (borrowAmount * STATIC_PRICE_AAVE_ORACLE_WBTC) / STATIC_PRICE_AAVE_ORACLE_USDC
        );
    }

    function testCannot_getOutstandingDebtBase_Unauthorized() public {
        // Act
        vm.expectRevert("Unauthorized.");
        testDebtServiceHarness.getOutstandingDebtBase(shortToken);
    }
}
