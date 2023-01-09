// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Foundry
import "forge-std/Test.sol";

import "@aave-protocol/interfaces/IPool.sol";

// Local file imports
import "../../src/child/Child.sol";
import "../../src/interfaces/IERC20Metadata.sol";
import "../common/ChildUtils.t.sol";

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
    function shortAll(uint256 amountMultiplier, address _baseToken, address _shortToken) public {
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1e3);

        // Instantiate Child
        testShaaveChild =
            new Child(address(this), _baseToken, IERC20Metadata(_baseToken).decimals(), getShaaveLTV(_baseToken));

        // Setup
        uint256 collateralAmount = (10 ** IERC20Metadata(_baseToken).decimals()) * amountMultiplier; // 1 uint in correct decimals

        // Supply
        deal(_baseToken, address(testShaaveChild), collateralAmount);

        // Expectations
        uint256 borrowAmount = getBorrowAmount(collateralAmount, _baseToken, _shortToken);
        (uint256 amountIn, uint256 amountOut) = swapExactInput(_shortToken, _baseToken, borrowAmount);
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
        shortAll(amountMultiplier, WETH_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: wBTC, Shorting: wBTC
    function test_short_all_wBTC_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: agEUR, Shorting: wBTC
    function test_short_all_wBTC_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: EURS, Shorting: wBTC
    function test_short_all_wBTC_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: jEUR, Shorting: wBTC
    function test_short_all_wBTC_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: wBTC
    function test_short_all_wBTC_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: USDT, Shorting: wBTC
    function test_short_all_wBTC_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: CRV, Shorting: wBTC
    function test_short_all_wBTC_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: wBTC
    function test_short_all_wBTC_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: GHST, Shorting: wBTC
    function test_short_all_wBTC_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: BAL, Shorting: wBTC
    function test_short_all_wBTC_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: DPI, Shorting: wBTC
    function test_short_all_wBTC_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: MaticX, Shorting: wBTC
    function test_short_all_wBTC_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: wBTC
    function test_short_all_wBTC_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: USDC, Shorting: wBTC
    function test_short_all_wBTC_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: DAI, Shorting: wBTC
    function test_short_all_wBTC_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: LINK, Shorting: wBTC
    function test_short_all_wBTC_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: wBTC
    function test_short_all_wBTC_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, wBTC_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: wBTC
    function test_short_all_wBTC_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, wBTC_ADDRESS);
    }

    // Collateral: MATIC, Shorting: wBTC
    function test_short_all_wBTC_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, wBTC_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short USDC
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: USDC
    function test_short_all_USDC_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: USDC, Shorting: USDC
    function test_short_all_USDC_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: BAL, Shorting: USDC
    function test_short_all_USDC_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: DPI, Shorting: USDC
    function test_short_all_USDC_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: MaticX, Shorting: USDC
    function test_short_all_USDC_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: agEUR, Shorting: USDC
    function test_short_all_USDC_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: jEUR, Shorting: USDC
    function test_short_all_USDC_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: CRV, Shorting: USDC
    function test_short_all_USDC_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, USDC_ADDRESS);
    } //NOTE: This fails regardless of forge-std test/test method

    // Collateral: wBTC, Shorting: USDC
    function test_short_all_USDC_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: EURS, Shorting: USDC
    function test_short_all_USDC_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: USDC
    function test_short_all_USDC_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: USDT, Shorting: USDC
    function test_short_all_USDC_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: USDC
    function test_short_all_USDC_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: GHST, Shorting: USDC
    function test_short_all_USDC_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: USDC
    function test_short_all_USDC_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: DAI, Shorting: USDC
    function test_short_all_USDC_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: LINK, Shorting: USDC
    function test_short_all_USDC_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: USDC
    function test_short_all_USDC_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, USDC_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: USDC
    function test_short_all_USDC_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, USDC_ADDRESS);
    }

    // Collateral: MATIC, Shorting: USDC
    function test_short_all_USDC_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, USDC_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short DAI
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: DAI
    function test_short_all_DAI_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: USDC, Shorting: DAI
    function test_short_all_DAI_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: BAL, Shorting: DAI
    function test_short_all_DAI_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: DPI, Shorting: DAI
    function test_short_all_DAI_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: MaticX, Shorting: DAI
    function test_short_all_DAI_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: agEUR, Shorting: DAI
    function test_short_all_DAI_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: jEUR, Shorting: DAI
    function test_short_all_DAI_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: CRV, Shorting: DAI
    function test_short_all_DAI_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: wBTC, Shorting: DAI
    function test_short_all_DAI_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: EURS, Shorting: DAI
    function test_short_all_DAI_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: DAI
    function test_short_all_DAI_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: USDT, Shorting: DAI
    function test_short_all_DAI_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: DAI
    function test_short_all_DAI_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: GHST, Shorting: DAI
    function test_short_all_DAI_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: DAI
    function test_short_all_DAI_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: USDC, Shorting: DAI
    function test_short_all_DAI_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: LINK, Shorting: DAI
    function test_short_all_DAI_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: DAI
    function test_short_all_DAI_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, DAI_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: DAI
    function test_short_all_DAI_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, DAI_ADDRESS);
    }

    // Collateral: MATIC, Shorting: DAI
    function test_short_all_DAI_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, DAI_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short LINK
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: LINK
    function test_short_all_LINK_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: LINK, Shorting: LINK
    function test_short_all_LINK_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: USDC, Shorting: LINK
    function test_short_all_LINK_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: BAL, Shorting: LINK
    function test_short_all_LINK_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: DPI, Shorting: LINK
    function test_short_all_LINK_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: MaticX, Shorting: LINK
    function test_short_all_LINK_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: agEUR, Shorting: LINK
    function test_short_all_LINK_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: jEUR, Shorting: LINK
    function test_short_all_LINK_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: CRV, Shorting: LINK
    function test_short_all_LINK_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: wBTC, Shorting: LINK
    function test_short_all_LINK_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: EURS, Shorting: LINK
    function test_short_all_LINK_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: LINK
    function test_short_all_LINK_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: USDT, Shorting: LINK
    function test_short_all_LINK_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: LINK
    function test_short_all_LINK_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: GHST, Shorting: LINK
    function test_short_all_LINK_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: LINK
    function test_short_all_LINK_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: DAI, Shorting: LINK
    function test_short_all_LINK_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: LINK
    function test_short_all_LINK_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, LINK_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: LINK
    function test_short_all_LINK_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, LINK_ADDRESS);
    }

    // Collateral: MATIC, Shorting: LINK
    function test_short_all_LINK_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, LINK_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short MATIC
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: MATIC
    function test_short_all_MATIC_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: MATIC, Shorting: MATIC
    function test_short_all_MATIC_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: LINK, Shorting: MATIC
    function test_short_all_MATIC_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: BAL, Shorting: MATIC
    function test_short_all_MATIC_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: DPI, Shorting: MATIC
    function test_short_all_MATIC_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: MaticX, Shorting: MATIC
    function test_short_all_MATIC_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: agEUR, Shorting: MATIC
    function test_short_all_MATIC_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: jEUR, Shorting: MATIC
    function test_short_all_MATIC_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: CRV, Shorting: MATIC
    function test_short_all_MATIC_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: wBTC, Shorting: MATIC
    function test_short_all_MATIC_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: EURS, Shorting: MATIC
    function test_short_all_MATIC_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: MATIC
    function test_short_all_MATIC_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: USDT, Shorting: MATIC
    function test_short_all_MATIC_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: MATIC
    function test_short_all_MATIC_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: GHST, Shorting: MATIC
    function test_short_all_MATIC_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: MATIC
    function test_short_all_MATIC_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: USDC, Shorting: MATIC
    function test_short_all_MATIC_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: DAI, Shorting: MATIC
    function test_short_all_MATIC_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, MATIC_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: MATIC
    function test_short_all_MATIC_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, MATIC_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: MATIC
    function test_short_all_MATIC_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, MATIC_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short USDT
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: USDT
    function test_short_all_USDT_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: USDT, Shorting: USDT
    function test_short_all_USDT_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: LINK, Shorting: USDT
    function test_short_all_USDT_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: BAL, Shorting: USDT
    function test_short_all_USDT_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: DPI, Shorting: USDT
    function test_short_all_USDT_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: MaticX, Shorting: USDT
    function test_short_all_USDT_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: agEUR, Shorting: USDT
    function test_short_all_USDT_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: jEUR, Shorting: USDT
    function test_short_all_USDT_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: CRV, Shorting: USDT
    function test_short_all_USDT_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: wBTC, Shorting: USDT
    function test_short_all_USDT_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: EURS, Shorting: USDT
    function test_short_all_USDT_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: USDT
    function test_short_all_USDT_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: MATIC, Shorting: USDT
    function test_short_all_USDT_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: USDT
    function test_short_all_USDT_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: GHST, Shorting: USDT
    function test_short_all_USDT_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: USDT
    function test_short_all_USDT_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: USDC, Shorting: USDT
    function test_short_all_USDT_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: DAI, Shorting: USDT
    function test_short_all_USDT_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, USDT_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: USDT
    function test_short_all_USDT_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, USDT_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: USDT
    function test_short_all_USDT_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, USDT_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short CRV
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: wBTC
    function test_short_all_CRV_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: CRV, Shorting: CRV
    function test_short_all_CRV_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: LINK, Shorting: CRV
    function test_short_all_CRV_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: BAL, Shorting: CRV
    function test_short_all_CRV_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: DPI, Shorting: CRV
    function test_short_all_CRV_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: MaticX, Shorting: CRV
    function test_short_all_CRV_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: agEUR, Shorting: CRV
    function test_short_all_CRV_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: jEUR, Shorting: CRV
    function test_short_all_CRV_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: USDT, Shorting: CRV
    function test_short_all_CRV_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: wBTC, Shorting: CRV
    function test_short_all_CRV_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: EURS, Shorting: CRV
    function test_short_all_CRV_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: CRV
    function test_short_all_CRV_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: MATIC, Shorting: CRV
    function test_short_all_CRV_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: CRV
    function test_short_all_CRV_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: GHST, Shorting: CRV
    function test_short_all_CRV_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: CRV
    function test_short_all_CRV_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: USDC, Shorting: CRV
    function test_short_all_CRV_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: DAI, Shorting: CRV
    function test_short_all_CRV_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, CRV_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: CRV
    function test_short_all_CRV_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, CRV_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: CRV
    function test_short_all_CRV_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, CRV_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short SUSHI
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: SUSHI
    function test_short_all_SUSHI_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: CRV, Shorting: SUSHI
    function test_short_all_SUSHI_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: LINK, Shorting: SUSHI
    function test_short_all_SUSHI_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: BAL, Shorting: SUSHI
    function test_short_all_SUSHI_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: DPI, Shorting: SUSHI
    function test_short_all_SUSHI_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: MaticX, Shorting: SUSHI
    function test_short_all_SUSHI_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: agEUR, Shorting: SUSHI
    function test_short_all_SUSHI_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: jEUR, Shorting: SUSHI
    function test_short_all_SUSHI_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: USDT, Shorting: SUSHI
    function test_short_all_SUSHI_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: wBTC, Shorting: SUSHI
    function test_short_all_SUSHI_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: EURS, Shorting: SUSHI
    function test_short_all_SUSHI_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: SUSHI
    function test_short_all_SUSHI_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: MATIC, Shorting: SUSHI
    function test_short_all_SUSHI_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: SUSHI
    function test_short_all_SUSHI_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: GHST, Shorting: SUSHI
    function test_short_all_SUSHI_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: SUSHI
    function test_short_all_SUSHI_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: USDC, Shorting: SUSHI
    function test_short_all_SUSHI_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: DAI, Shorting: SUSHI
    function test_short_all_SUSHI_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, SUSHI_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: SUSHI
    function test_short_all_SUSHI_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, SUSHI_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: SUSHI
    function test_short_all_SUSHI_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, SUSHI_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short GHST
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: GHST
    function test_short_all_GHST_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: CRV, Shorting: GHST
    function test_short_all_GHST_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: LINK, Shorting: GHST
    function test_short_all_GHST_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: BAL, Shorting: GHST
    function test_short_all_GHST_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: DPI, Shorting: GHST
    function test_short_all_GHST_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: MaticX, Shorting: GHST
    function test_short_all_GHST_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: agEUR, Shorting: GHST
    function test_short_all_GHST_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: jEUR, Shorting: GHST
    function test_short_all_GHST_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: USDT, Shorting: GHST
    function test_short_all_GHST_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: wBTC, Shorting: GHST
    function test_short_all_GHST_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: EURS, Shorting: GHST
    function test_short_all_GHST_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: GHST
    function test_short_all_GHST_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: MATIC, Shorting: GHST
    function test_short_all_GHST_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: GHST
    function test_short_all_GHST_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: GHST, Shorting: GHST
    function test_short_all_GHST_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: GHST
    function test_short_all_GHST_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: USDC, Shorting: GHST
    function test_short_all_GHST_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: DAI, Shorting: GHST
    function test_short_all_GHST_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, GHST_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: GHST
    function test_short_all_GHST_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, GHST_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: GHST
    function test_short_all_GHST_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, GHST_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short BAL
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: BAL
    function test_short_all_BAL_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: CRV, Shorting: BAL
    function test_short_all_BAL_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: LINK, Shorting: BAL
    function test_short_all_BAL_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: BAL, Shorting: BAL
    function test_short_all_BAL_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: DPI, Shorting: BAL
    function test_short_all_BAL_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: MaticX, Shorting: BAL
    function test_short_all_BAL_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: agEUR, Shorting: BAL
    function test_short_all_BAL_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: jEUR, Shorting: BAL
    function test_short_all_BAL_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: USDT, Shorting: BAL
    function test_short_all_BAL_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: wBTC, Shorting: BAL
    function test_short_all_BAL_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: EURS, Shorting: BAL
    function test_short_all_BAL_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: BAL
    function test_short_all_BAL_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: MATIC, Shorting: BAL
    function test_short_all_BAL_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: BAL
    function test_short_all_BAL_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: GHST, Shorting: BAL
    function test_short_all_BAL_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: BAL
    function test_short_all_BAL_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: USDC, Shorting: BAL
    function test_short_all_BAL_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: DAI, Shorting: BAL
    function test_short_all_BAL_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, BAL_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: BAL
    function test_short_all_BAL_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, BAL_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: BAL
    function test_short_all_BAL_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, BAL_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short DPI
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: DPI
    function test_short_all_DPI_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: CRV, Shorting: DPI
    function test_short_all_DPI_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: LINK, Shorting: DPI
    function test_short_all_DPI_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: BAL, Shorting: DPI
    function test_short_all_DPI_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: DPI, Shorting: DPI
    function test_short_all_DPI_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: MaticX, Shorting: DPI
    function test_short_all_DPI_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: agEUR, Shorting: DPI
    function test_short_all_DPI_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: jEUR, Shorting: DPI
    function test_short_all_DPI_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: USDT, Shorting: DPI
    function test_short_all_DPI_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: wBTC, Shorting: DPI
    function test_short_all_DPI_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: EURS, Shorting: DPI
    function test_short_all_DPI_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: DPI
    function test_short_all_DPI_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: MATIC, Shorting: DPI
    function test_short_all_DPI_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: DPI
    function test_short_all_DPI_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: GHST, Shorting: DPI
    function test_short_all_DPI_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: DPI
    function test_short_all_DPI_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: USDC, Shorting: DPI
    function test_short_all_DPI_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: DAI, Shorting: DPI
    function test_short_all_DPI_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, DPI_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: DPI
    function test_short_all_DPI_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, DPI_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: DPI
    function test_short_all_DPI_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, DPI_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short EURS
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: EURS
    function test_short_all_EURS_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: CRV, Shorting: EURS
    function test_short_all_EURS_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: LINK, Shorting: EURS
    function test_short_all_EURS_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: BAL, Shorting: EURS
    function test_short_all_EURS_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: DPI, Shorting: EURS
    function test_short_all_EURS_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: MaticX, Shorting: EURS
    function test_short_all_EURS_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: agEUR, Shorting: EURS
    function test_short_all_EURS_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: jEUR, Shorting: EURS
    function test_short_all_EURS_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: USDT, Shorting: EURS
    function test_short_all_EURS_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: wBTC, Shorting: EURS
    function test_short_all_EURS_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: EURS, Shorting: EURS
    function test_short_all_EURS_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: EURS
    function test_short_all_EURS_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: MATIC, Shorting: EURS
    function test_short_all_EURS_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: EURS
    function test_short_all_EURS_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: GHST, Shorting: EURS
    function test_short_all_EURS_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: EURS
    function test_short_all_EURS_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: USDC, Shorting: EURS
    function test_short_all_EURS_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: DAI, Shorting: EURS
    function test_short_all_EURS_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, EURS_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: EURS
    function test_short_all_EURS_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, EURS_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: EURS
    function test_short_all_EURS_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, EURS_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short jEUR
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: jEUR
    function test_short_all_jEUR_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: CRV, Shorting: jEUR
    function test_short_all_jEUR_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: LINK, Shorting: jEUR
    function test_short_all_jEUR_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: BAL, Shorting: jEUR
    function test_short_all_jEUR_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: DPI, Shorting: jEUR
    function test_short_all_jEUR_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: MaticX, Shorting: jEUR
    function test_short_all_jEUR_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: agEUR, Shorting: jEUR
    function test_short_all_jEUR_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: jEUR, Shorting: jEUR
    function test_short_all_jEUR_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: USDT, Shorting: jEUR
    function test_short_all_jEUR_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: wBTC, Shorting: jEUR
    function test_short_all_jEUR_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: EURS, Shorting: jEUR
    function test_short_all_jEUR_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: jEUR
    function test_short_all_jEUR_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: MATIC, Shorting: jEUR
    function test_short_all_jEUR_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: jEUR
    function test_short_all_jEUR_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: GHST, Shorting: jEUR
    function test_short_all_jEUR_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: jEUR
    function test_short_all_jEUR_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: USDC, Shorting: jEUR
    function test_short_all_jEUR_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: DAI, Shorting: jEUR
    function test_short_all_jEUR_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, jEUR_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: jEUR
    function test_short_all_jEUR_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, jEUR_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: jEUR
    function test_short_all_jEUR_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, jEUR_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short agEUR
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: agEUR
    function test_short_all_agEUR_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: CRV, Shorting: agEUR
    function test_short_all_agEUR_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: LINK, Shorting: agEUR
    function test_short_all_agEUR_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: BAL, Shorting: agEUR
    function test_short_all_agEUR_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: DPI, Shorting: agEUR
    function test_short_all_agEUR_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: MaticX, Shorting: agEUR
    function test_short_all_agEUR_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: agEUR, Shorting: agEUR
    function test_short_all_agEUR_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: jEUR, Shorting: agEUR
    function test_short_all_agEUR_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: USDT, Shorting: agEUR
    function test_short_all_agEUR_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: wBTC, Shorting: agEUR
    function test_short_all_agEUR_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: EURS, Shorting: agEUR
    function test_short_all_agEUR_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: agEUR
    function test_short_all_agEUR_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: MATIC, Shorting: agEUR
    function test_short_all_agEUR_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: agEUR
    function test_short_all_agEUR_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: GHST, Shorting: agEUR
    function test_short_all_agEUR_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: agEUR
    function test_short_all_agEUR_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: USDC, Shorting: agEUR
    function test_short_all_agEUR_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: DAI, Shorting: agEUR
    function test_short_all_agEUR_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, agEUR_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: agEUR
    function test_short_all_agEUR_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, agEUR_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: agEUR
    function test_short_all_agEUR_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, agEUR_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short miMATIC
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: miMATIC
    function test_short_all_miMATIC_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: CRV, Shorting: miMATIC
    function test_short_all_miMATIC_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: LINK, Shorting: miMATIC
    function test_short_all_miMATIC_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: BAL, Shorting: miMATIC
    function test_short_all_miMATIC_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: DPI, Shorting: miMATIC
    function test_short_all_miMATIC_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: MaticX, Shorting: miMATIC
    function test_short_all_miMATIC_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: agEUR, Shorting: miMATIC
    function test_short_all_miMATIC_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: jEUR, Shorting: miMATIC
    function test_short_all_miMATIC_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: USDT, Shorting: miMATIC
    function test_short_all_miMATIC_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: wBTC, Shorting: miMATIC
    function test_short_all_miMATIC_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: EURS, Shorting: miMATIC
    function test_short_all_miMATIC_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: miMATIC
    function test_short_all_miMATIC_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: MATIC, Shorting: miMATIC
    function test_short_all_miMATIC_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: miMATIC
    function test_short_all_miMATIC_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: GHST, Shorting: miMATIC
    function test_short_all_miMATIC_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: miMATIC
    function test_short_all_miMATIC_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: USDC, Shorting: miMATIC
    function test_short_all_miMATIC_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: DAI, Shorting: miMATIC
    function test_short_all_miMATIC_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, miMATIC_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: miMATIC
    function test_short_all_miMATIC_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, miMATIC_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: miMATIC
    function test_short_all_miMATIC_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, miMATIC_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    short WETH
    //////////////////////////////////////////////////////////////////////////*/

    // Collateral: WETH, Shorting: WETH
    function test_short_all_WETH_using_WETH(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WETH_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: CRV, Shorting: WETH
    function test_short_all_WETH_using_CRV(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, CRV_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: LINK, Shorting: WETH
    function test_short_all_WETH_using_LINK(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, LINK_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: BAL, Shorting: WETH
    function test_short_all_WETH_using_BAL(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, BAL_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: DPI, Shorting: WETH
    function test_short_all_WETH_using_DPI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DPI_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: MaticX, Shorting: WETH
    function test_short_all_WETH_using_MaticX(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MaticX_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: agEUR, Shorting: WETH
    function test_short_all_WETH_using_agEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, agEUR_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: jEUR, Shorting: WETH
    function test_short_all_WETH_using_jEUR(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, jEUR_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: USDT, Shorting: WETH
    function test_short_all_WETH_using_USDT(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDT_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: wBTC, Shorting: WETH
    function test_short_all_WETH_using_wBTC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, wBTC_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: EURS, Shorting: WETH
    function test_short_all_WETH_using_EURS(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, EURS_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: miMATIC, Shorting: WETH
    function test_short_all_WETH_using_miMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, miMATIC_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: MATIC, Shorting: WETH
    function test_short_all_WETH_using_MATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, MATIC_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: SUSHI, Shorting: WETH
    function test_short_all_WETH_using_SUSHI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, SUSHI_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: GHST, Shorting: WETH
    function test_short_all_WETH_using_GHST(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, GHST_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: stMATIC, Shorting: WETH
    function test_short_all_WETH_using_stMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, stMATIC_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: USDC, Shorting: WETH
    function test_short_all_WETH_using_USDC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, USDC_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: DAI, Shorting: WETH
    function test_short_all_WETH_using_DAI(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, DAI_ADDRESS, WETH_ADDRESS);
    }

    // Collateral: AAVE token, Shorting: WETH
    function test_short_all_WETH_using_AAVE(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, AAVE_TOKEN, WETH_ADDRESS);
    }

    // Collateral: WMATIC, Shorting: WETH
    function test_short_all_WETH_using_WMATIC(uint256 amountMultiplier) public {
        shortAll(amountMultiplier, WMATIC_ADDRESS, WETH_ADDRESS);
    }
}
