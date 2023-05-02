// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Foundry
import {Test, stdError} from "forge-std/Test.sol";

// Local file imports
import {IERC20Metadata} from "../../src/interfaces/token/IERC20Metadata.sol";
import {IPool} from "../../src/interfaces/aave/IPool.sol";
import {IAaveOracle} from "../../src/interfaces/aave/IAaveOracle.sol";
import {AddressLib} from "../../src/libraries/AddressLib.sol";
import {PricingLib} from "../../src/libraries/PricingLib.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";
import {MockUniswapGeneral, MockUniswapLowLevelError} from ".././mocks/MockUniswap.t.sol";
import {SwapServiceHarness} from "../../test/harness/child/SwapServiceHarness.t.sol";
import {TestHelperFunctions} from "../common/TestHelperFunctions.t.sol";
import {
    USDC_ADDRESS,
    WBTC_ADDRESS,
    AAVE_ORACLE,
    UNISWAP_SWAP_ROUTER,
    AMOUNT_OUT_MINIMUM_PERCENTAGE,
    STATIC_PRICE_AAVE_ORACLE_USDC,
    STATIC_PRICE_AAVE_ORACLE_WBTC
} from "../common/Constants.t.sol";

contract SwapServiceTest is Test {
    using AddressLib for address[];
    using PricingLib for address;
    using MathLib for uint256;

    // Test tokens
    address tokenIn;
    address tokenOut;

    // Decimals
    uint256 tokenInDecimals;
    uint256 tokenOutDecimals;
    uint256 tokenInPowTenDecimals;
    uint256 tokenOutPowTenDecimals;
    uint256 tokenInConversion;
    uint256 tokenOutConversion;

    // Contracts
    SwapServiceHarness testSwapServiceHarness;

    // Events
    event SwapSuccess(
        address user, address tokenInAddress, uint256 tokenInAmount, address tokenOutAddress, uint256 tokenOutAmount
    );
    event ErrorString(string errorMessage, string executionInsight);
    event LowLevelError(bytes errorData, string executionInsight);

    function setUp() public {
        // Instantiate SwapServiceHarness
        testSwapServiceHarness = new SwapServiceHarness();

        // Variables
        tokenIn = USDC_ADDRESS;
        tokenOut = WBTC_ADDRESS;
        tokenInDecimals = IERC20Metadata(tokenIn).decimals();
        tokenOutDecimals = IERC20Metadata(tokenOut).decimals();
        tokenInPowTenDecimals = (10 ** tokenInDecimals);
        tokenOutPowTenDecimals = (10 ** tokenOutDecimals);
        tokenInConversion = 10 ** (18 - tokenInDecimals);
        tokenOutConversion = 10 ** (18 - tokenOutDecimals);

        // Mock AAVE ORACLE pricing
        vm.mockCall(
            AAVE_ORACLE,
            abi.encodeWithSelector(IAaveOracle(AAVE_ORACLE).getAssetPrice.selector, tokenOut),
            abi.encode(STATIC_PRICE_AAVE_ORACLE_WBTC)
        );
        vm.mockCall(
            AAVE_ORACLE,
            abi.encodeWithSelector(IAaveOracle(AAVE_ORACLE).getAssetPrice.selector, tokenIn),
            abi.encode(STATIC_PRICE_AAVE_ORACLE_USDC)
        );

        // Mock UNISWAP swaps
        bytes memory MockUniswapGeneralCode = address(new MockUniswapGeneral()).code;
        vm.etch(UNISWAP_SWAP_ROUTER, MockUniswapGeneralCode);
    }

    function test_exactInputSingle_nominal(uint256 tokenInAmount) public {
        // Setup
        uint256 tokenOutExpected; // (Units: tokenOut)
        uint256 tokenInAmountMin; // (Units: tokenIn)
        uint256 tokenInAmountMax; // (Units: tokenIn)
        uint256 amountInActual; // (Units: tokenIn)
        uint256 amountOutActual; // (Units: tokenOut)

        // Amounts below tokenInAmountMin cause numerator < decimals in SwapService.sol::swapExactInput::amountOutMinimum
        tokenInAmountMin = (100 * tokenInPowTenDecimals * tokenOutConversion)
            / (AMOUNT_OUT_MINIMUM_PERCENTAGE * tokenIn.pricedIn(tokenOut)) + 1;

        tokenInAmountMax = type(uint256).max / AMOUNT_OUT_MINIMUM_PERCENTAGE / tokenIn.pricedIn(tokenOut);

        // Limit fuzz input.
        tokenInAmount = Test.bound(tokenInAmount, tokenInAmountMin, tokenInAmountMax);

        // Assume 100% of value in is expected out
        tokenOutExpected =
            TestHelperFunctions.convertTokenAmount(tokenIn, tokenOut, tokenInAmount, tokenInDecimals, tokenOutDecimals);

        // Supply
        deal(tokenIn, address(testSwapServiceHarness), tokenInAmount);
        deal(tokenOut, UNISWAP_SWAP_ROUTER, tokenOutExpected);

        // Expectations
        vm.expectEmit(true, true, true, true, address(testSwapServiceHarness));
        emit SwapSuccess(address(this), tokenIn, tokenInAmount, tokenOut, tokenOutExpected);

        // Act
        (amountInActual, amountOutActual) = testSwapServiceHarness.exposed_swapExactInput(
            tokenIn, tokenOut, tokenInAmount, tokenInDecimals, tokenOutDecimals
        );

        // Assertions
        assertEq(tokenInAmount, amountInActual);
        assertEq(tokenOutExpected, amountOutActual);
    }

    function test_exactInputSingle_fail_tokenInAmountTooSmall(uint256 tokenInAmount) public {
        // Setup
        uint256 tokenInAmountMin; // (Units: tokenIn)

        // Amounts below tokenInAmountMin cause decimals(numerator) < decimals(denomiator) in SwapService.sol::swapExactInput::amountOutMinimum
        tokenInAmountMin = (100 * tokenInPowTenDecimals * tokenOutConversion)
            / (AMOUNT_OUT_MINIMUM_PERCENTAGE * tokenIn.pricedIn(tokenOut));

        // Limit fuzz input.
        tokenInAmount = Test.bound(tokenInAmount, 0, tokenInAmountMin);

        // Expectations
        vm.expectRevert("amountOutMinimum not possible.");

        // Act
        testSwapServiceHarness.exposed_swapExactInput(
            tokenIn, tokenOut, tokenInAmount, tokenInDecimals, tokenOutDecimals
        );
    }

    function test_exactInputSingle_arithmeticError(uint256 tokenInAmount) public {
        // Setup
        uint256 tokenInAmountMin; // (Units: tokenIn)
        uint256 tokenInAmountMax; // (Units: tokenIn)

        // Amounts below tokenInAmountMin cause decimals(numerator) < decimals(denomiator) in SwapService.sol::swapExactInput::amountOutMinimum
        tokenInAmountMin = (100 * tokenInPowTenDecimals * tokenOutConversion)
            / (AMOUNT_OUT_MINIMUM_PERCENTAGE * tokenIn.pricedIn(tokenOut)) + 1;

        // Source code calculations need to be tested for underflow/overflow.
        tokenInAmountMax = type(uint256).max / AMOUNT_OUT_MINIMUM_PERCENTAGE / tokenIn.pricedIn(tokenOut);

        // Limit fuzz input.
        vm.assume(tokenInAmount > tokenInAmountMax);

        // Expectations
        vm.expectRevert(stdError.arithmeticError);

        // Act
        testSwapServiceHarness.exposed_swapExactInput(
            tokenIn, tokenOut, tokenInAmount, tokenInDecimals, tokenOutDecimals
        );
    }

    function test_swapToShortToken_nominal(uint256 outputTokenAmount, uint256 inputMax) public {
        // Setup
        uint256 tokenInAmount; // this is outputTokenAmount converted to tokenIn (Units: tokenIn)
        uint256 tokenInAmountMaxArithmetic =
            type(uint256).max / AMOUNT_OUT_MINIMUM_PERCENTAGE / tokenIn.pricedIn(tokenOut); // max inputToken amount that avoids uint256 overflow (Units: tokenIn)
        uint256 outputTokenAmountMax; // inputMax converted to tokenOut (Units: tokenOut)
        uint256 outputTokenAmountMaxArithmetic; // max outputToken amount that also doesn't cause uint256 overflow (Units: tokenOut)
        uint256 amountInActual; // (Units: tokenIn)
        uint256 amountOutActual; // (Units: tokenOut)

        // Limit fuzz input. This is max funds for swap.
        inputMax = Test.bound(inputMax, 0, tokenInAmountMaxArithmetic);

        // We want to keep our desired output amount less than what we supply in inputToken
        outputTokenAmountMax =
            TestHelperFunctions.convertTokenAmount(tokenIn, tokenOut, inputMax, tokenInDecimals, tokenOutDecimals);

        // Limit fuzz input.
        outputTokenAmountMaxArithmetic = outputTokenAmountMax / tokenOut.pricedIn(tokenIn);
        outputTokenAmount = Test.bound(outputTokenAmount, 0, outputTokenAmountMaxArithmetic);

        // How much of inputMax that will transfer to achieve outputTokenAmount.
        // Enables us to `deal` the test contract the minimum funds
        // without calling SwapService::getAmountIn() prior to Act.
        tokenInAmount = TestHelperFunctions.convertTokenAmount(
            tokenOut, tokenIn, outputTokenAmount, tokenOutDecimals, tokenInDecimals
        );

        // Supply
        deal(tokenIn, address(testSwapServiceHarness), tokenInAmount);
        deal(tokenOut, UNISWAP_SWAP_ROUTER, outputTokenAmount);

        // Expectations
        vm.expectEmit(true, true, true, true, address(testSwapServiceHarness));
        emit SwapSuccess(address(this), tokenIn, tokenInAmount, tokenOut, outputTokenAmount);

        // Act
        (amountInActual, amountOutActual) = testSwapServiceHarness.exposed_swapToShortToken(
            tokenOut, tokenIn, outputTokenAmount, inputMax, tokenInConversion, tokenInDecimals, tokenOutDecimals
        );

        // Assertions
        assertGe(inputMax, amountInActual);
        assertEq(tokenInAmount, amountInActual);
        assertEq(outputTokenAmount, amountOutActual);
    }

    function test_swapToShortToken_outputTokenAmountExceedsFundsError(uint256 outputTokenAmount, uint256 inputMax)
        public
    {
        // Setup
        uint256 tokenInAmountMin;
        uint256 tokenInAmountMaxArithmetic; // max inputToken amount that doesn't cause uint256 overflow (Units: tokenIn)
        uint256 outputTokenAmountMax; // inputMax converted to tokenOut (Units: tokenOut)
        uint256 outputTokenAmountMaxArithmetic; // max outputToken amount that also doesn't cause uint256 overflow (Units: tokenOut)
        uint256 amountInActual; // (Units: tokenIn)
        uint256 amountOutActual; // (Units: tokenOut)
        string memory messageExpected;

        // Since we are forcing an error and invoking exactInputSingle, we need a lower bound
        tokenInAmountMin = (100 * tokenInPowTenDecimals * tokenOutConversion)
            / (AMOUNT_OUT_MINIMUM_PERCENTAGE * tokenIn.pricedIn(tokenOut)) + 1;

        tokenInAmountMaxArithmetic = (type(uint256).max / AMOUNT_OUT_MINIMUM_PERCENTAGE / tokenIn.pricedIn(tokenOut));

        // Limit fuzz input. Leave at least 1 outputToken amount between artihmetic upper bounds for the outputTokenAmount fuzz.
        inputMax = Test.bound(
            inputMax,
            tokenInAmountMin,
            tokenInAmountMaxArithmetic
                - TestHelperFunctions.convertTokenAmount(tokenOut, tokenIn, 1, tokenOutDecimals, tokenInDecimals)
        );

        // We want to request an output amount greater than what we supply
        outputTokenAmountMax =
            TestHelperFunctions.convertTokenAmount(tokenIn, tokenOut, inputMax, tokenInDecimals, tokenOutDecimals);

        outputTokenAmountMaxArithmetic = type(uint256).max / tokenOut.pricedIn(tokenIn);

        // Limit fuzz input. Any target outPutTokenAmount over converted inputMax fails exactOutputSingle
        vm.assume(outputTokenAmount > outputTokenAmountMax && outputTokenAmount < outputTokenAmountMaxArithmetic);

        // Supply
        deal(tokenIn, address(testSwapServiceHarness), inputMax);
        deal(tokenOut, UNISWAP_SWAP_ROUTER, outputTokenAmount);

        // Expectations
        messageExpected = "STF"; // SafeTransferFrom
        vm.expectEmit(false, true, true, true, address(testSwapServiceHarness));
        emit ErrorString(messageExpected, "Uniswap's exactOutputSingle() failed. Trying exactInputSingle() instead.");
        vm.expectEmit(true, true, true, true, address(testSwapServiceHarness));
        emit SwapSuccess(address(this), tokenIn, inputMax, tokenOut, outputTokenAmount);

        // Act
        (amountInActual, amountOutActual) = testSwapServiceHarness.exposed_swapToShortToken(
            tokenOut, tokenIn, outputTokenAmount, inputMax, tokenInConversion, tokenInDecimals, tokenOutDecimals
        );

        // Assertions
        assertEq(inputMax, amountInActual);
        assertEq(outputTokenAmount, amountOutActual);
    }

    function test_swapToShortToken_LowLevelError(uint256 outputTokenAmount, uint256 inputMax) public {
        // Override Mock UNISWAP general swaps so we can force a low-level revert.
        bytes memory MockUniswapLowLevelErrorCode = address(new MockUniswapLowLevelError()).code;
        vm.etch(UNISWAP_SWAP_ROUTER, MockUniswapLowLevelErrorCode);

        // Setup
        uint256 tokenInAmountMaxArithmetic; // max inputToken amount that doesn't cause uint256 overflow (Units: tokenIn)
        uint256 tokenInAmountExpected; // this is outputTokenAmount converted to tokenIn (Units: tokenIn)
        uint256 tokenInAmountMin; // Minimum amount of tokenIn that won't cause amountOutMin to be 0 (Units: tokenIn).
        uint256 outputTokenAmountMin; // Minimum amount of tokenOut that won't cause amountOutMin to be 0 (Units: tokenOut).
        uint256 outputTokenAmountMax; // inputMax converted to tokenOut (Units: tokenOut)

        uint256 amountInActual; // (Units: tokenIn)
        uint256 amountOutActual; // (Units: tokenOut)
        bytes memory dataExpected; // Arbitrary revert data

        // Since we are forcing an error and invoking exactInputSingle, we need a lower bound
        tokenInAmountMin = (100 * tokenInPowTenDecimals * tokenOutConversion)
            / (AMOUNT_OUT_MINIMUM_PERCENTAGE * tokenIn.pricedIn(tokenOut)) + 1;

        tokenInAmountMaxArithmetic = type(uint256).max / AMOUNT_OUT_MINIMUM_PERCENTAGE / tokenIn.pricedIn(tokenOut);

        // Limit fuzz input. This is max funds for swap.
        inputMax = Test.bound(
            inputMax,
            tokenInAmountMin
                + TestHelperFunctions.convertTokenAmount(tokenOut, tokenIn, 1, tokenOutDecimals, tokenInDecimals),
            tokenInAmountMaxArithmetic
        );

        // We want to keep our desired output amount less than what we supply in inputToken.
        outputTokenAmountMax =
            TestHelperFunctions.convertTokenAmount(tokenIn, tokenOut, inputMax, tokenInDecimals, tokenOutDecimals);

        outputTokenAmountMax /= tokenOut.pricedIn(tokenIn); // Reduce high bounds to avoid arithmetic overflows

        outputTokenAmountMin = TestHelperFunctions.convertTokenAmount(
            tokenIn, tokenOut, tokenInAmountMin, tokenInDecimals, tokenOutDecimals
        );

        // Limit fuzz input.
        vm.assume(outputTokenAmount > outputTokenAmountMin && outputTokenAmount < outputTokenAmountMax);

        // Identify the optimal inputToken fund
        tokenInAmountExpected = TestHelperFunctions.convertTokenAmount(
            tokenOut, tokenIn, outputTokenAmount, tokenOutDecimals, tokenInDecimals
        );

        // Supply
        deal(tokenIn, address(testSwapServiceHarness), tokenInAmountExpected);
        deal(tokenOut, UNISWAP_SWAP_ROUTER, outputTokenAmount);

        // Expectations
        dataExpected = hex"01020304";
        vm.expectEmit(true, true, true, true, address(testSwapServiceHarness));
        emit LowLevelError(dataExpected, "Uniswap's exactOutputSingle() failed. Trying exactInputSingle() instead.");
        vm.expectEmit(true, false, true, true, address(testSwapServiceHarness));
        emit SwapSuccess(address(this), tokenIn, tokenInAmountExpected, tokenOut, outputTokenAmount);

        // Act
        (amountInActual, amountOutActual) = testSwapServiceHarness.exposed_swapToShortToken(
            tokenOut, tokenIn, outputTokenAmount, inputMax, tokenInConversion, tokenInDecimals, tokenOutDecimals
        );

        // Assertions
        assertEq(tokenInAmountExpected, amountInActual);
        assertEq(outputTokenAmount, amountOutActual);
    }

    function test_getAmountIn_fundOptimalAmount(uint256 outputTokenAmount, uint256 inputMax) public {
        // Arrange
        uint256 amountInActual; // (Units: tokenIn decimals)
        uint256 outputTokenAmountMax; // (Units: tokenOut decimals)
        uint256 amountInExpected; // Amount of tokenIn equal value closest in value to desired output.
        uint256 tokenInAmountMaxArithmetic = type(uint256).max / tokenIn.pricedIn(tokenOut);

        // Limit fuzz input.
        vm.assume(inputMax < tokenInAmountMaxArithmetic);

        outputTokenAmountMax =
            TestHelperFunctions.convertTokenAmount(tokenIn, tokenOut, inputMax, tokenInDecimals, tokenOutDecimals);

        // Limit fuzz input.
        vm.assume(outputTokenAmount < outputTokenAmountMax);

        amountInExpected = TestHelperFunctions.convertTokenAmount(
            tokenOut, tokenIn, outputTokenAmount, tokenOutDecimals, tokenInDecimals
        );

        // Act
        amountInActual = testSwapServiceHarness.exposed_getAmountIn(
            tokenOut, tokenIn, tokenInConversion, outputTokenAmount, inputMax
        );

        // Assert
        assertEq(amountInExpected, amountInActual);
    }

    function test_getAmountIn_fundMaxAmount(uint256 outputTokenAmount, uint256 inputMax) public {
        // Arrange
        uint256 amountInActual; // (Units: tokenIn decimals)
        uint256 outputTokenAmountMax; // (Units: tokenOut decimals)
        uint256 outputTokenAmountMaxArithmetic = type(uint256).max / tokenOut.pricedIn(tokenIn);
        uint256 tokenInAmountMaxArithmetic = type(uint256).max / tokenIn.pricedIn(tokenOut);

        // Limit fuzz input.
        vm.assume(
            inputMax
                < tokenInAmountMaxArithmetic
                    - TestHelperFunctions.convertTokenAmount(tokenOut, tokenIn, 1, tokenOutDecimals, tokenInDecimals)
        );

        outputTokenAmountMax =
            TestHelperFunctions.convertTokenAmount(tokenIn, tokenOut, inputMax, tokenInDecimals, tokenOutDecimals);

        // Limit fuzz input.
        vm.assume(outputTokenAmount > outputTokenAmountMax && outputTokenAmount < outputTokenAmountMaxArithmetic);

        // Act
        amountInActual = testSwapServiceHarness.exposed_getAmountIn(
            tokenOut, tokenIn, tokenInConversion, outputTokenAmount, inputMax
        );

        // Assert
        assertEq(inputMax, amountInActual);
    }

    function test_getAmountIn_arithmeticError(uint256 outputTokenAmount, uint256 inputMax) public {
        // Arrange
        uint256 priceOfOutputTokenInInputToken = tokenOut.pricedIn(tokenIn) / tokenInConversion;
        uint256 outputTokenAmountMax; // Amounts above this overflow uint256 (Units: tokenOut decimals)
        uint256 tokenInAmountMaxArithmetic = type(uint256).max / tokenIn.pricedIn(tokenOut);

        // Limit fuzz input.
        vm.assume(inputMax < tokenInAmountMaxArithmetic);

        // This is the source code calculation that can cause overflow. Force overflow.
        outputTokenAmountMax = type(uint256).max / priceOfOutputTokenInInputToken;

        // Limit fuzz input.
        vm.assume(outputTokenAmount > outputTokenAmountMax && outputTokenAmount < type(uint256).max);

        // Act
        vm.expectRevert(stdError.arithmeticError);
        testSwapServiceHarness.exposed_getAmountIn(tokenOut, tokenIn, tokenInConversion, outputTokenAmount, inputMax);
    }
}
