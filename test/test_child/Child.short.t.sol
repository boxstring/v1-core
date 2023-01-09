// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// External Package Imports
import "@aave-protocol/interfaces/IPool.sol";

// Local file imports
import "../../src/child/Child.sol";
import "../../src/interfaces/IERC20Metadata.sol";
import "../common/ChildUtils.t.sol";
import {UniswapUtils, ChildUtils} from "../common/ChildUtils.t.sol";

/* TODO: The following still needs to be tested here:
1. XXX Reduce position: Test actual runthrough without mock
2. XXX Reduce position 100% with no gains, and ensure no gains (easy)
3. XXX Reduce position by < 100%, with gains, and ensure correct amount gets paid
4. Reduce position by < 100%, with no gains and ensure no gains
5. Try to short with all supported collateral -- nested for loop for short tokens?
6. Then, parent can be tested*/

contract ChildShortTest is ChildUtils, TestUtils {
    using AddressLib for address[];

    // Contracts
    Child testShaaveChild;

    // Events
    event BorrowSuccess(address user, address borrowTokenAddress, uint256 amount);
    event SwapSuccess(
        address user, address tokenInAddress, uint256 tokenInAmount, address tokenOutAddress, uint256 tokenOutAmount
    );
    event PositionAddedSuccess(address user, address shortTokenAddress, uint256 amount);

    // Create a short position of _shortToken funded by all of provided _baseToken
    function shortHelper(uint256 amountMultiplier, address _baseToken, address _shortToken) internal {
        // Instantiate Child
        testShaaveChild =
            new Child(address(this), _baseToken, IERC20Metadata(_baseToken).decimals(), getShaaveLTV(_baseToken));

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

    /*//////////////////////////////////////////////////////////////////////////
                                    short wBTC
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: wBTC
    function test_short_all_wBTC_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: wBTC, Shorting: wBTC
    function testFail_short_all_wBTC_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: USDC, Shorting: wBTC
    function test_short_all_wBTC_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: DAI, Shorting: wBTC
    function test_short_all_wBTC_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, wBTC_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short USDC
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: USDC
    function test_short_all_USDC_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: USDC, Shorting: USDC
    function testFail_short_all_USDC_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: wBTC, Shorting: USDC
    function test_short_all_USDC_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: DAI, Shorting: USDC
    function test_short_all_USDC_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, USDC_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short DAI
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: DAI
    function test_short_all_DAI_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: DAI, Shorting: DAI
    function testFail_short_all_DAI_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: wBTC, Shorting: DAI
    function test_short_all_DAI_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: USDC, Shorting: DAI
    function test_short_all_DAI_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, DAI_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short LINK
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: LINK
    function test_short_all_LINK_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: USDC, Shorting: LINK
    function test_short_all_LINK_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: wBTC, Shorting: LINK
    function test_short_all_LINK_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: DAI, Shorting: LINK
    function test_short_all_LINK_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, LINK_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short USDT
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: USDT
    function test_short_all_USDT_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: wBTC, Shorting: USDT
    function test_short_all_USDT_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: USDC, Shorting: USDT
    function test_short_all_USDT_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: DAI, Shorting: USDT
    function test_short_all_USDT_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, USDT_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short CRV
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: wBTC
    function test_short_all_CRV_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: wBTC, Shorting: CRV
    function test_short_all_CRV_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: USDC, Shorting: CRV
    function test_short_all_CRV_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: DAI, Shorting: CRV
    function test_short_all_CRV_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, CRV_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short SUSHI
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: SUSHI
    function test_short_all_SUSHI_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: wBTC, Shorting: SUSHI
    function test_short_all_SUSHI_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: USDC, Shorting: SUSHI
    function test_short_all_SUSHI_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: DAI, Shorting: SUSHI
    function test_short_all_SUSHI_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, SUSHI_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short GHST
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: GHST
    function test_short_all_GHST_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: wBTC, Shorting: GHST
    function test_short_all_GHST_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: USDC, Shorting: GHST
    function test_short_all_GHST_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: DAI, Shorting: GHST
    function test_short_all_GHST_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, GHST_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short BAL
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: BAL
    function test_short_all_BAL_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: wBTC, Shorting: BAL
    function test_short_all_BAL_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: USDC, Shorting: BAL
    function test_short_all_BAL_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: DAI, Shorting: BAL
    function test_short_all_BAL_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, BAL_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short DPI
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: DPI
    function test_short_all_DPI_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: wBTC, Shorting: DPI
    function test_short_all_DPI_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: USDC, Shorting: DPI
    function test_short_all_DPI_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: DAI, Shorting: DPI
    function test_short_all_DPI_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, DPI_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short EURS
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: EURS
    function test_short_all_EURS_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: wBTC, Shorting: EURS
    function test_short_all_EURS_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: USDC, Shorting: EURS
    function test_short_all_EURS_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: DAI, Shorting: EURS
    function test_short_all_EURS_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, EURS_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short jEUR
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: jEUR
    function test_short_all_jEUR_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: wBTC, Shorting: jEUR
    function test_short_all_jEUR_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: USDC, Shorting: jEUR
    function test_short_all_jEUR_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: DAI, Shorting: jEUR
    function test_short_all_jEUR_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, jEUR_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short agEUR
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: agEUR
    function test_short_all_agEUR_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: wBTC, Shorting: agEUR
    function test_short_all_agEUR_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: USDC, Shorting: agEUR
    function test_short_all_agEUR_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: DAI, Shorting: agEUR
    function test_short_all_agEUR_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, agEUR_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short miMATIC
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: miMATIC
    function test_short_all_miMATIC_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: wBTC, Shorting: miMATIC
    function test_short_all_miMATIC_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: USDC, Shorting: miMATIC
    function test_short_all_miMATIC_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: DAI, Shorting: miMATIC
    function test_short_all_miMATIC_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, miMATIC_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short WETH
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: WETH
    function testFail_short_all_WETH_using_WETH(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, WETH_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: wBTC, Shorting: WETH
    function test_short_all_WETH_using_wBTC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, wBTC_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: USDC, Shorting: WETH
    function test_short_all_WETH_using_USDC(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, USDC_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: DAI, Shorting: WETH
    function test_short_all_WETH_using_DAI(uint256 amountMultiplier) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);
        shortHelper(amountMultiplier, DAI_ADDRESS, WETH_ADDRESS);
    }
}
