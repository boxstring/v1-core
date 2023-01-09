// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Foundry
import "forge-std/Test.sol";

// External Package Imports
import "@uniswap-v3-core/interfaces/IUniswapV3Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Local File Imports
import "../common/Constants.t.sol";
import "../../src/libraries/AddressLib.sol";
import "../../src/interfaces/IERC20Metadata.sol";

contract UniswapPools is Test, TestUtils {
    function poolTestHelper(address tokenA, address tokenB) public {
        // Arrange
        uint256 tokenA_balance;
        uint256 tokenB_balance;
        uint256 minTokens = 1;
        uint256 tokenA_decimals = (10 ** IERC20Metadata(tokenA).decimals());
        uint256 tokenB_decimals = (10 ** IERC20Metadata(tokenB).decimals());
        string memory errorEvent1 =
            string.concat("Balance of ", tokenAddress2tokenName[tokenA], " in swap pool is too small");
        string memory errorEvent2 =
            string.concat("Balance of ", tokenAddress2tokenName[tokenB], " in swap pool is too small");

        // Act
        address poolActual = IUniswapV3Factory(UNISWAP_FACTORY).getPool(tokenA, tokenB, POOL_FEE);

        tokenA_balance = IERC20(tokenA).balanceOf(poolActual);
        tokenB_balance = IERC20(tokenB).balanceOf(poolActual);

        // Assert
        assertTrue(poolActual != address(0), "Pool does not exist");
        assertTrue(tokenA_balance > (minTokens ** tokenA_decimals), errorEvent1);
        assertTrue(tokenB_balance > (minTokens ** tokenB_decimals), errorEvent2);
    }
}

// // /*//////////////////////////////////////////////////////////////////////////
// //                                 USDC
// // //////////////////////////////////////////////////////////////////////////*/
contract USDC_poolTest is UniswapPools {
    function test_pool_all() public {
        for (uint256 i = 0; i < ALLOWED_COLLATERL_POLYGON_MVP.length; i++) {
            poolTestHelper(ALLOWED_COLLATERL_POLYGON_MVP[i], WMATIC_ADDRESS);
        }
    }
}
