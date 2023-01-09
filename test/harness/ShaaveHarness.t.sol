// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Foundry
import "forge-std/Test.sol";

// External packages
import "@uniswap-v3-periphery/interfaces/ISwapRouter.sol";
import "@uniswap-v3-periphery/libraries/TransferHelper.sol";
import "@aave-protocol/interfaces/IPool.sol";

// Local file imports
import {DebtService, SwapService} from "../../src/child/Child.sol";
import "../../src/libraries/PricingLib.sol";
import "../../src/interfaces/IERC20Metadata.sol";
import "../common/UniswapUtils.t.sol";
import "../common/Constants.t.sol";

contract ShaaveHarness is SwapService {
    // Deploy this contract then call this method to test myInternalMethod.
    function exposed_swapExactInput(address _inputToken, address _outputToken, uint256 collateralAmount, uint256 _tokenInDecimals, uint256 _tokenOutDecimals)
        external
        returns (uint256 amountIn, uint256 amountOut)
    {
        return SwapService.swapExactInput(_inputToken, _outputToken, collateralAmount, _tokenInDecimals, _tokenOutDecimals);
    }
}
