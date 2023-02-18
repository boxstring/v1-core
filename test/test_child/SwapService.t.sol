// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Foundry
import {Test} from "forge-std/Test.sol";

// External Package Imports
import {IPool} from "@aave-protocol/interfaces/IPool.sol";
import {IAaveOracle} from "@aave-protocol/interfaces/IAaveOracle.sol";

// Local file imports
import {AddressLib} from "../../src/libraries/AddressLib.sol";
import {PricingLib} from "../../src/libraries/PricingLib.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";
import {MockUniswapGeneral} from ".././mocks/MockUniswap.t.sol";
import {ShaaveHarness} from "../../test/harness/ShaaveHarness.t.sol";
import {IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {
    USDC_ADDRESS,
    wBTC_ADDRESS,
    AAVE_ORACLE,
    UNISWAP_SWAP_ROUTER,
    AMOUNT_OUT_MINIMUM_PERCENTAGE
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
    uint256 tokenInConversion;
    uint256 tokenOutConversion;

    // Contracts
    ShaaveHarness testShaaveHarness;

    // Events
    event SwapSuccess(
        address user, address tokenInAddress, uint256 tokenInAmount, address tokenOutAddress, uint256 tokenOutAmount
    );

    function setUp() public {
        // Instantiate Child
        testShaaveHarness = new ShaaveHarness();

        // Token Setup
        tokenIn = USDC_ADDRESS;
        tokenOut = wBTC_ADDRESS;
        tokenInDecimals = IERC20Metadata(tokenIn).decimals();
        tokenOutDecimals = IERC20Metadata(tokenOut).decimals();
        tokenInConversion = (10 ** tokenInDecimals);
        tokenOutConversion = 10 ** (18 - tokenOutDecimals);
    }

    function test_exactInputSingle(uint256 tokenInAmount) public {
        // Setup
        uint256 tokenOutExpected;
        uint256 tokenInAmountMin;

        // Mocks
        vm.mockCall(
            AAVE_ORACLE,
            abi.encodeWithSelector(IAaveOracle(AAVE_ORACLE).getAssetPrice.selector, tokenOut),
            abi.encode(2e12)
        );
        vm.mockCall(
            AAVE_ORACLE,
            abi.encodeWithSelector(IAaveOracle(AAVE_ORACLE).getAssetPrice.selector, tokenIn),
            abi.encode(1e8)
        );
        bytes memory MockUniswapGainsCode = address(new MockUniswapGeneral()).code;
        vm.etch(UNISWAP_SWAP_ROUTER, MockUniswapGainsCode);

        // Amounts above this cause decimals(numerator) < decimals(denomiator) in SwapService.sol::swapExactInput::amountOutMinimum
        tokenInAmountMin = (100 * tokenInConversion * tokenOutConversion)
            / (AMOUNT_OUT_MINIMUM_PERCENTAGE * tokenIn.pricedIn(tokenOut)) + 1;
        vm.assume(tokenInAmount >= tokenInAmountMin && tokenInAmount < 2e5);

        // Supply
        tokenOutExpected = tokenIn.pricedIn(tokenOut).dividedBy(10 ** 18 - tokenOutDecimals, 18) * tokenInAmount;
        deal(tokenIn, address(testShaaveHarness), tokenInAmount);
        deal(tokenOut, UNISWAP_SWAP_ROUTER, tokenOutExpected);

        // Expect Emit
        vm.expectEmit(true, true, true, true, address(testShaaveHarness));
        emit SwapSuccess(address(this), tokenIn, tokenInAmount, tokenOut, tokenOutExpected);

        // Act
        (uint256 amountInActual, uint256 amountOutActual) = testShaaveHarness.exposed_swapExactInput(
            tokenIn, tokenOut, tokenInAmount, tokenInDecimals, tokenOutDecimals
        );

        // Assertions
        assertEq(amountInActual, tokenInAmount);
        assertEq(amountOutActual, tokenOutExpected);
    }

    function test_exactInputSingle_fail_amountOutMinimum(uint256 tokenInAmount) public {
        // Setup
        uint256 tokenInAmountMin;

        // Mocks
        vm.mockCall(
            AAVE_ORACLE,
            abi.encodeWithSelector(IAaveOracle(AAVE_ORACLE).getAssetPrice.selector, tokenOut),
            abi.encode(2e12)
        );
        vm.mockCall(
            AAVE_ORACLE,
            abi.encodeWithSelector(IAaveOracle(AAVE_ORACLE).getAssetPrice.selector, tokenIn),
            abi.encode(1e8)
        );

        // Amounts above this cause decimals(numerator) < decimals(denomiator) in SwapService.sol::swapExactInput::amountOutMinimum
        tokenInAmountMin = (100 * tokenInConversion * tokenOutConversion)
            / (AMOUNT_OUT_MINIMUM_PERCENTAGE * tokenIn.pricedIn(tokenOut)) + 1;
        vm.assume(tokenInAmount < tokenInAmountMin);

        // Expect Emit
        vm.expectRevert("amountOutMinimum not possible.");

        // Act
        testShaaveHarness.exposed_swapExactInput(tokenIn, tokenOut, tokenInAmount, tokenInDecimals, tokenOutDecimals);
    }
}
