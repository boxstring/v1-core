// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Local file imports
import {SwapService} from "../../../src/child/SwapService.sol";

contract SwapServiceHarness is SwapService {
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

    function exposed_swapToShortToken(
        address _outputToken,
        address _inputToken,
        uint256 _outputTokenAmount,
        uint256 _inputMax,
        uint256 _baseTokenConversion,
        uint256 _baseTokenDecimals,
        uint256 _shortTokenDecimals
    ) external returns (uint256 amountIn, uint256 amountOut) {
        return SwapService.swapToShortToken(
            _outputToken,
            _inputToken,
            _outputTokenAmount,
            _inputMax,
            _baseTokenConversion,
            _baseTokenDecimals,
            _shortTokenDecimals
        );
    }

    function exposed_getAmountIn(
        address _shortToken,
        address _baseToken,
        uint256 _baseTokenConversion,
        uint256 _positionReduction,
        uint256 _backingBaseAmount
    ) external view returns (uint256 amountIn) {
        return SwapService.getAmountIn(
            _shortToken, _baseToken, _baseTokenConversion, _positionReduction, _backingBaseAmount
        );
    }
}
