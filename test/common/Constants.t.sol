// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Addresses
address constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
address constant AAVE_DATA_PROVIDER = 0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654;
address constant AAVE_ORACLE = 0xb023e699F5a33916Ea823A16485e259257cA8Bd1;
address constant AAVE_TOKEN = 0xD6DF932A45C0f255f85145f286eA0b292B21C90B;
address constant UNISWAP_SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
address constant agEUR_ADDRESS = 0xE0B52e49357Fd4DAf2c15e02058DCE6BC0057db4;
address constant BAL_ADDRESS = 0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3;
address constant CRV_ADDRESS = 0x172370d5Cd63279eFa6d502DAB29171933a610AF;
address constant DAI_ADDRESS = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
address constant DPI_ADDRESS = 0x85955046DF4668e1DD369D2DE9f3AEB98DD2A369;
address constant EURS_ADDRESS = 0xE111178A87A3BFf0c8d18DECBa5798827539Ae99;
address constant GHST_ADDRESS = 0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7;
address constant jEUR_ADDRESS = 0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c;
address constant LINK_ADDRESS = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39;
address constant MaticX_ADDRESS = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;
address constant miMATIC_ADDRESS = 0xa3Fa99A148fA48D14Ed51d610c367C61876997F1;
address constant stMATIC_ADDRESS = 0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4;
address constant SUSHI_ADDRESS = 0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a;
address constant USDC_ADDRESS = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
address constant USDT_ADDRESS = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
address constant wBTC_ADDRESS = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
address constant WETH_ADDRESS = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
address constant WMATIC_ADDRESS = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
address constant SHORT_TOKEN = wBTC_ADDRESS;
address constant BASE_TOKEN = USDC_ADDRESS;
address constant CHILD_ADDRESS = 0xa4F9f089677Bf68c8F38Fe9bffEF2be52EA679bF;

// uints
uint24 constant POOL_FEE = 3000;
uint256 constant LTV_BUFFER = 10;
uint256 constant TEST_COLLATERAL_AMOUNT = 1e6;
uint256 constant TEST_BASE_LTV = 72;
uint256 constant UNISWAP_AMOUNT_IN_PROFIT = (((TEST_COLLATERAL_AMOUNT * TEST_BASE_LTV) / 100) * 50) / 100; // Max borrow divided by 2
uint256 constant UNISWAP_AMOUNT_OUT_LOSSES_FACTOR = 2;
uint256 constant WITHDRAWAL_BUFFER = 1e15;
uint256 constant SHORT_TOKEN_AMOUNT = 1e8;
uint256 constant AMOUNT_OUT_MINIMUM_PERCENTAGE = 95;

contract TestUtils {
    mapping(address => string) tokenAddress2tokenName;

    constructor() {
        tokenAddress2tokenName[agEUR_ADDRESS] = "agEUR";
        tokenAddress2tokenName[BAL_ADDRESS] = "BAL";
        tokenAddress2tokenName[CRV_ADDRESS] = "CRV";
        tokenAddress2tokenName[DAI_ADDRESS] = "DAI";
        tokenAddress2tokenName[DPI_ADDRESS] = "DPI";
        tokenAddress2tokenName[EURS_ADDRESS] = "EUR";
        tokenAddress2tokenName[GHST_ADDRESS] = "GHST";
        tokenAddress2tokenName[jEUR_ADDRESS] = "jEUR";
        tokenAddress2tokenName[LINK_ADDRESS] = "LINK";
        tokenAddress2tokenName[MaticX_ADDRESS] = "MaticX";
        tokenAddress2tokenName[miMATIC_ADDRESS] = "miMATIC";
        tokenAddress2tokenName[stMATIC_ADDRESS] = "stMATIC";
        tokenAddress2tokenName[USDC_ADDRESS] = "USDC";
        tokenAddress2tokenName[USDT_ADDRESS] = "USDT";
        tokenAddress2tokenName[wBTC_ADDRESS] = "wBTC";
        tokenAddress2tokenName[WETH_ADDRESS] = "WETH";
        tokenAddress2tokenName[WMATIC_ADDRESS] = "WMATIC";
    }

    // Polygon allowed list. Shaave preferred choice from https://app.aave.com/?marketName=proto_polygon_v3
    address[] ALLOWED_COLLATERL_POLYGON_MVP = [USDC_ADDRESS, DAI_ADDRESS, wBTC_ADDRESS, WETH_ADDRESS];

    // Polygon allowed list. As shown on https://app.aave.com/?marketName=proto_polygon_v3
    address[] ALLOWED_BORROW_POLYGON_MVP = [
        WETH_ADDRESS,
        USDC_ADDRESS,
        DAI_ADDRESS,
        LINK_ADDRESS,
        wBTC_ADDRESS,
        USDT_ADDRESS,
        CRV_ADDRESS,
        SUSHI_ADDRESS,
        GHST_ADDRESS,
        BAL_ADDRESS,
        DPI_ADDRESS,
        EURS_ADDRESS,
        agEUR_ADDRESS,
        miMATIC_ADDRESS,
        WMATIC_ADDRESS
    ];

    // Polygon allowed list
    address[] ALLOWED_COLLATERL_POLYGON =
        [USDC_ADDRESS, DAI_ADDRESS, LINK_ADDRESS, AAVE_TOKEN, WMATIC_ADDRESS, wBTC_ADDRESS, WETH_ADDRESS];

    // Polygon allowed list
    address[] ALLOWED_BORROW_POLYGON = [
        WETH_ADDRESS,
        USDC_ADDRESS,
        DAI_ADDRESS,
        LINK_ADDRESS,
        wBTC_ADDRESS,
        USDT_ADDRESS,
        CRV_ADDRESS,
        SUSHI_ADDRESS,
        GHST_ADDRESS,
        BAL_ADDRESS,
        DPI_ADDRESS,
        EURS_ADDRESS,
        jEUR_ADDRESS,
        agEUR_ADDRESS
    ];

    // Polygon banned list
    address[] BANNED_COLLATERAL = [
        agEUR_ADDRESS,
        EURS_ADDRESS,
        jEUR_ADDRESS,
        miMATIC_ADDRESS,
        USDT_ADDRESS,
        CRV_ADDRESS,
        SUSHI_ADDRESS,
        GHST_ADDRESS,
        BAL_ADDRESS,
        DPI_ADDRESS,
        MaticX_ADDRESS,
        stMATIC_ADDRESS
    ];

    address[] BANNED_BORROW = [AAVE_TOKEN, stMATIC_ADDRESS, MaticX_ADDRESS, WMATIC_ADDRESS]; // Polygon banned list
}
