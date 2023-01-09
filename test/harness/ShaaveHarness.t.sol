// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Local file imports
import {SwapService} from "../../src/child/Child.sol";

contract ShaaveHarness is SwapService {
    // Deploy this contract then call this method to test myInternalMethod.
    function exposed_swapExactInput(
        address _inputToken,
        address _outputToken,
        uint256 collateralAmount,
        uint256 _tokenInDecimals,
        uint256 _tokenOutDecimals
    ) external returns (uint256 amountIn, uint256 amountOut) {
        return
            SwapService.swapExactInput(_inputToken, _outputToken, collateralAmount, _tokenInDecimals, _tokenOutDecimals);
    }
}
