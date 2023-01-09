// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Foundry
import "forge-std/Test.sol";

// External Package Imports
import "@aave-protocol/interfaces/IPool.sol";

// Local file imports
import "../../test/harness/ShaaveHarness.t.sol";
import "../../src/child/Child.sol";
import "../../src/interfaces/IERC20Metadata.sol";
import "../common/ChildUtils.t.sol";
import "../common/Constants.t.sol";

contract SwapServiceTest is ChildUtils, TestUtils {
    using AddressLib for address[];

    // Contracts
    ShaaveHarness testShaaveHarness;
    ChildUtils childUtils;

    function setUp() public {
        // Instantiate Child
        testShaaveHarness = new ShaaveHarness();
        childUtils = new ChildUtils();
    }

    function swapExactInputHelper(address _tokenIn, address _tokenOut, uint256 amountMultiplier) public {
        // Setup
        uint256 tokenInDecimals = IERC20Metadata(_tokenIn).decimals();
        uint256 tokenOutDecimals = IERC20Metadata(_tokenOut).decimals();
        uint256 tokenInAmount = (10 ** tokenInDecimals) * amountMultiplier; // 1 uint in correct decimals

        // Supply
        deal(_tokenIn, address(testShaaveHarness), tokenInAmount);

        // Expectations
        (uint256 amountInExpected, uint256 amountOutExpected) =
            childUtils.swapExactInputExpect(_tokenIn, _tokenOut, tokenInAmount);

        // Act
        (uint256 amountInActual, uint256 amountOutActual) =
            testShaaveHarness.exposed_swapExactInput(_tokenIn, _tokenOut, tokenInAmount, tokenInDecimals, tokenOutDecimals);

        // Assertions
        assertEq(amountInActual, amountInExpected);
        assertEq(amountOutActual, amountOutExpected);
    }

    function test_pricedInCeiling() public {
        
    }
}

/*//////////////////////////////////////////////////////////////////////////
                                TokenIn wBTC
//////////////////////////////////////////////////////////////////////////*/
contract wBTC_SwapServiceTest is SwapServiceTest {
    function test_swap_tokenIn_wBTC_tokenOut_agEUR(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, agEUR_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_EURS(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, EURS_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_jEUR(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, jEUR_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_miMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, miMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_USDT(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, USDT_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_CRV(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, CRV_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_SUSHI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, SUSHI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_GHST(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, GHST_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_BAL(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, BAL_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_DPI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, DPI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_MaticX(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, MaticX_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_stMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, stMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, USDC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, DAI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_LINK(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, LINK_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_WMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, WMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_wBTC_tokenOut_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 10);
        swapExactInputHelper(wBTC_ADDRESS, WETH_ADDRESS, amountMultiplier);
    }
}

/*//////////////////////////////////////////////////////////////////////////
                                TokenIn WETH
//////////////////////////////////////////////////////////////////////////*/
contract WETH_SwapServiceTest is SwapServiceTest {
    function test_swap_tokenIn_WETH_tokenOut_agEUR(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, agEUR_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_EURS(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, EURS_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_jEUR(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, jEUR_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_miMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, miMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_USDT(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, USDT_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_CRV(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, CRV_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_SUSHI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, SUSHI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_GHST(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, GHST_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_BAL(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, BAL_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_DPI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, DPI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_MaticX(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, MaticX_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_stMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, stMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, wBTC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, USDC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_LINK(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, LINK_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_WMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, WMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_WETH_tokenOut_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 130);
        swapExactInputHelper(WETH_ADDRESS, DAI_ADDRESS, amountMultiplier);
    }
}

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
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
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

/*//////////////////////////////////////////////////////////////////////////
                                TokenIn USDC
//////////////////////////////////////////////////////////////////////////*/
contract USDC_SwapServiceTest is SwapServiceTest {
    function test_swap_tokenIn_USDC_tokenOut_agEUR(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, agEUR_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_EURS(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, EURS_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_jEUR(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, jEUR_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_miMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, miMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_USDT(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, USDT_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_CRV(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, CRV_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_SUSHI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, SUSHI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_GHST(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, GHST_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_BAL(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, BAL_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_DPI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, DPI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_MaticX(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, MaticX_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_stMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, stMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, wBTC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, DAI_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_LINK(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, LINK_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_WMATIC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, WMATIC_ADDRESS, amountMultiplier);
    }

    function test_swap_tokenIn_USDC_tokenOut_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 2e5);
        swapExactInputHelper(USDC_ADDRESS, WETH_ADDRESS, amountMultiplier);
    }
}
