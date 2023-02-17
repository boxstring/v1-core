// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Foundry
import "forge-std/Test.sol";

// External Package Imports
import "@aave-protocol/interfaces/IPool.sol";
import { IAaveOracle } from "@aave-protocol/interfaces/IAaveOracle.sol";

// Local file imports
import "../../test/harness/ShaaveHarness.t.sol";
// import "../../src/child/Child.sol";
import { PricingLib } from "../../src/libraries/PricingLib.sol";
import { MathLib } from "../../src/libraries/MathLib.sol";
import "../../src/interfaces/IERC20Metadata.sol";
import "../common/ChildUtils.t.sol";
import "../common/Constants.t.sol";

contract SwapServiceTest is ChildUtils, TestUtils {
    using MathLib for uint256;

    // Contracts
    ShaaveHarness testShaaveHarness;
    ChildUtils childUtils;

    // Event
    event SwapSuccess(
        address user, address tokenInAddress, uint256 tokenInAmount, address tokenOutAddress, uint256 tokenOutAmount
    );
    event ErrorString(string errorMessage, string executionInsight);
    event LowLevelError(bytes errorData, string executionInsight);

    function setUp() public {
        // Instantiate Child
        testShaaveHarness = new ShaaveHarness();
        childUtils = new ChildUtils();
    }

    function swapExactInputHelper(address _tokenIn, address _tokenOut, uint256 amountMultiplier) public {
        // Setup
        uint256 tokenInDecimals = IERC20Metadata(_tokenIn).decimals();
        uint256 tokenOutDecimals = IERC20Metadata(_tokenOut).decimals();
        uint256 amountOutActual;
        uint256 amountInActual;

        uint256 tokenInAmount;
        
        tokenInAmount = (10 ** tokenInDecimals) * amountMultiplier;

        // Supply
        deal(_tokenIn, address(testShaaveHarness), tokenInAmount);

        // Expectations
        (uint256 amountInExpected, uint256 amountOutExpected) =
            childUtils.swapExactInputExpect(_tokenIn, _tokenOut, tokenInAmount);
        vm.expectEmit(true, true, true, true);
        emit SwapSuccess(address(this), _tokenIn, amountInExpected, _tokenOut, amountOutExpected);

        // Act
        (amountInActual, amountOutActual) =
            testShaaveHarness.exposed_swapExactInput(_tokenIn, _tokenOut, tokenInAmount, tokenInDecimals, tokenOutDecimals);

        // Assertions
        assertEq(amountInActual, tokenInAmount);
        assertEq(amountInActual, amountInExpected);
        assertEq(amountOutActual, amountOutExpected);
    }

    function test_pricedInCeiling() public view {
        
        uint256 price = IAaveOracle(AAVE_ORACLE).getAssetPrice(wBTC_ADDRESS).dividedBy(10 ** 8, 0);
        uint256 ceilingUSD = 2e5;
        uint256 numTokens = ceilingUSD.dividedBy(price, 0);
        console.log("ceilingUSD /  price = ", numTokens);
    }
}

// /*//////////////////////////////////////////////////////////////////////////
//                                 TokenIn wBTC
// //////////////////////////////////////////////////////////////////////////*/
// contract wBTC_SwapServiceTest is SwapServiceTest {
//     function test_swap_tokenIn_wBTC_tokenOut_agEUR(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, agEUR_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_EURS(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, EURS_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_jEUR(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, jEUR_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_miMATIC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, miMATIC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_USDT(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, USDT_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_CRV(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, CRV_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_SUSHI(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, SUSHI_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_GHST(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, GHST_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_BAL(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, BAL_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_DPI(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, DPI_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_MaticX(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, MaticX_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_stMATIC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, stMATIC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_USDC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, USDC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_DAI(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, DAI_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_LINK(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, LINK_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_WMATIC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, WMATIC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_wBTC_tokenOut_WETH(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
//         swapExactInputHelper(wBTC_ADDRESS, WETH_ADDRESS, amountMultiplier);
//     }
// }

// /*//////////////////////////////////////////////////////////////////////////
//                                 TokenIn WETH
// //////////////////////////////////////////////////////////////////////////*/
// contract WETH_SwapServiceTest is SwapServiceTest {
//     function test_swap_tokenIn_WETH_tokenOut_agEUR(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, agEUR_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_EURS(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, EURS_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_jEUR(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, jEUR_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_miMATIC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, miMATIC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_USDT(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, USDT_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_CRV(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, CRV_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_SUSHI(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, SUSHI_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_GHST(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, GHST_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_BAL(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, BAL_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_DPI(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, DPI_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_MaticX(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, MaticX_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_stMATIC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, stMATIC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_wBTC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, wBTC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_USDC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, USDC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_LINK(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, LINK_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_WMATIC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, WMATIC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_WETH_tokenOut_DAI(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
//         swapExactInputHelper(WETH_ADDRESS, DAI_ADDRESS, amountMultiplier);
//     }
// }

/*//////////////////////////////////////////////////////////////////////////
                                TokenIn DAI
//////////////////////////////////////////////////////////////////////////*/
contract DAI_SwapServiceTest is SwapServiceTest {
    function test_swap_tokenIn_DAI_tokenOut_agEUR(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, agEUR_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_EURS(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, EURS_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_jEUR(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, jEUR_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_miMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, miMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_USDT(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, USDT_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_CRV(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, CRV_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_SUSHI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, SUSHI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_GHST(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, GHST_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_BAL(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, BAL_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_DPI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, DPI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_MaticX(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, MaticX_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_stMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, stMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_wBTC(uint256 amountMultiplier) public {
        // vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        // uint256 tokenInDecimals = IERC20Metadata(DAI_ADDRESS).decimals();
        // uint256 tokenOutDecimals = IERC20Metadata(wBTC_ADDRESS).decimals();
        // amountMultiplier = Test.bound(amountMultiplier, 5e18, 2e23);
        // amountMultiplier = Test.bound(amountMultiplier, 1, 2e5);
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        // uint256 amountOutMinimum = (
        //     ((PricingLib.pricedIn(DAI_ADDRESS, wBTC_ADDRESS) * amountMultiplier * AMOUNT_OUT_MINIMUM_PERCENTAGE) / 100)
        //         / (10 ** tokenInDecimals)  // tokenIn conversion
        // ) / 10 ** (18 - tokenOutDecimals); // tokenOut conversion
        // console.log("PricingLib.pricedIn(DAI_ADDRESS, wBTC_ADDRESS), ", PricingLib.pricedIn(DAI_ADDRESS, wBTC_ADDRESS));
        // console.log("amountMultiplier: ", amountMultiplier);
        // vm.assume(amountOutMinimum > 0);
        swapExactInputHelper(DAI_ADDRESS, wBTC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, USDC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_LINK(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, LINK_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_WMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, WMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_DAI_tokenOut_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(DAI_ADDRESS, WETH_ADDRESS, amountMultiplier);
    }
}

// /*//////////////////////////////////////////////////////////////////////////
//                                 TokenIn USDC
// //////////////////////////////////////////////////////////////////////////*/
// contract USDC_SwapServiceTest is SwapServiceTest {
//     function test_swap_tokenIn_USDC_tokenOut_agEUR(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, agEUR_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_EURS(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, EURS_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_jEUR(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, jEUR_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_miMATIC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, miMATIC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_USDT(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, USDT_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_CRV(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, CRV_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_SUSHI(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, SUSHI_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_GHST(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, GHST_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_BAL(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, BAL_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_DPI(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, DPI_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_MaticX(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, MaticX_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_stMATIC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, stMATIC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_wBTC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, wBTC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_DAI(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, DAI_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_LINK(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, LINK_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_WMATIC(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, WMATIC_ADDRESS, amountMultiplier);
//     }

//     function test_swap_tokenIn_USDC_tokenOut_WETH(uint256 amountMultiplier) public {
//         vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
//         swapExactInputHelper(USDC_ADDRESS, WETH_ADDRESS, amountMultiplier);
//     }
// }
