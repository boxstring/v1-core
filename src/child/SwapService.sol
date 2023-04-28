// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

pragma abicoder v2;

// Local imports
import {ISwapRouter} from "../interfaces/uniswap/ISwapRouter.sol";
import {IERC20Metadata} from "../interfaces/token/IERC20Metadata.sol";
import {TransferHelper} from "../libraries/uniswap/TransferHelper.sol";
import {PricingLib} from "../libraries/PricingLib.sol";

abstract contract SwapService {
    using PricingLib for address;

    // Constants
    uint24 private constant POOL_FEE = 3000;
    uint256 private constant AMOUNT_OUT_MINIMUM_PERCENTAGE = 95;
    ISwapRouter private constant SWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // Event
    event SwapSuccess(
        address user, address tokenInAddress, uint256 tokenInAmount, address tokenOutAddress, uint256 tokenOutAmount
    );
    event ErrorString(string errorMessage, string executionInsight);
    event LowLevelError(bytes errorData, string executionInsight);

    /**
     * @param _inputToken The address of the token that this function is attempting to give to Uniswap
     * @param _outputToken The address of the token that this function is attempting to obtain from Uniswap
     * @param _tokenInAmount The amount of the token that this function is attempting to give to Uniswap (Units: _inputToken decimals)
     * @param _tokenInDecimals The amount of decimals of the _inputToken
     * @param _tokenOutDecimals The amount of decimals of the _outputToken
     * @return amountIn The amount of tokens supplied to Uniswap for a desired token output amount
     * @return amountOut The amount of tokens received from Uniswap
     * @notice amountOutMinimum will return 0 when ratio of inputToken to outputToken, or _tokenInAmount is too small (Units: _outputToken decimals)
     *
     */
    function swapExactInput(
        address _inputToken,
        address _outputToken,
        uint256 _tokenInAmount,
        uint256 _tokenInDecimals,
        uint256 _tokenOutDecimals
    ) internal returns (uint256 amountIn, uint256 amountOut) {
        uint256 amountOutMinimum = (
            ((_inputToken.pricedIn(_outputToken) * _tokenInAmount * AMOUNT_OUT_MINIMUM_PERCENTAGE) / 100)
                / (10 ** _tokenInDecimals)
        ) // cancel tokenIn decimals
            / 10 ** (18 - _tokenOutDecimals); // tokenOut conversion
        require(amountOutMinimum != 0, "amountOutMinimum not possible.");
        TransferHelper.safeApprove(_inputToken, address(SWAP_ROUTER), _tokenInAmount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _inputToken,
            tokenOut: _outputToken,
            fee: POOL_FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _tokenInAmount,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        (amountIn, amountOut) = (_tokenInAmount, SWAP_ROUTER.exactInputSingle(params));
        emit SwapSuccess(msg.sender, _inputToken, amountIn, _outputToken, amountOut);
    }

    /**
     * @param _outputToken The address of the token that this function is attempting to obtain from Uniswap
     * @param _inputToken The address of the token that this function is attempting to spend for output tokens.
     * @param _outputTokenAmount The amount this we're attempting to get from Uniswap (Units: _outputToken decimals)
     * @param _inputMax The max amount of input tokens willing to spend (Units: _inputToken decimals)
     * @param _inputTokenConversion Use this to express amounts in _inputToken decimals
     * @param _inputTokenDecimals The amount of decimals of the _inputToken
     * @param _outputTokenDecimals The amount of decimals of the _outputToken
     * @return amountIn The amount of input tokens supplied to Uniswap (Units: _inputToken decimals)
     * @return amountOut The amount of output tokens received from Uniswap (Units: _outputToken decimals)
     *
     */
    function swapToShortToken(
        address _outputToken,
        address _inputToken,
        uint256 _outputTokenAmount,
        uint256 _inputMax,
        uint256 _inputTokenConversion,
        uint256 _inputTokenDecimals,
        uint256 _outputTokenDecimals
    ) internal returns (uint256 amountIn, uint256 amountOut) {
        TransferHelper.safeApprove(_inputToken, address(SWAP_ROUTER), _inputMax);

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: _inputToken,
            tokenOut: _outputToken,
            fee: POOL_FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: _outputTokenAmount,
            amountInMaximum: _inputMax,
            sqrtPriceLimitX96: 0
        });

        try SWAP_ROUTER.exactOutputSingle(params) returns (uint256 returnedAmountIn) {
            emit SwapSuccess(msg.sender, _inputToken, returnedAmountIn, _outputToken, _outputTokenAmount);
            (amountIn, amountOut) = (returnedAmountIn, _outputTokenAmount);
        } catch Error(string memory message) {
            emit ErrorString(message, "Uniswap's exactOutputSingle() failed. Trying exactInputSingle() instead.");
            amountIn = getAmountIn(_outputToken, _inputToken, _inputTokenConversion, _outputTokenAmount, _inputMax);
            (amountIn, amountOut) =
                swapExactInput(_inputToken, _outputToken, amountIn, _inputTokenDecimals, _outputTokenDecimals);
        } catch (bytes memory data) {
            emit LowLevelError(data, "Uniswap's exactOutputSingle() failed. Trying exactInputSingle() instead.");
            amountIn = getAmountIn(_outputToken, _inputToken, _inputTokenConversion, _outputTokenAmount, _inputMax);
            (amountIn, amountOut) =
                swapExactInput(_inputToken, _outputToken, amountIn, _inputTokenDecimals, _outputTokenDecimals);
        }
    }

    /**
     * @param _outputToken The address of the token that this function is attempting to obtain from Uniswap.
     * @param _positionReduction The amount that we're attempting to obtain from Uniswap (Units: _outputToken decimals).
     * @param _inputMax The maximum amount of _inputToken to fund a swap (Units: _inputToken decimals).
     * @return amountIn the amountIn to supply to Uniswap when swapping to output tokens (Units: _inputToken decimals).
     *
     */
    function getAmountIn(
        address _outputToken,
        address _inputToken,
        uint256 _inputTokenConversion,
        uint256 _positionReduction,
        uint256 _inputMax
    ) internal view returns (uint256 amountIn) {
        /// @dev Units: inputToken decimals
        uint256 priceOfOutputTokenInInputToken = _outputToken.pricedIn(_inputToken) / _inputTokenConversion;

        /// @dev Units: inputToken decimals = (inputToken decimals * outputToken decimals) / outputToken decimals
        uint256 positionReductionBase =
            (priceOfOutputTokenInInputToken * _positionReduction) / (10 ** IERC20Metadata(_outputToken).decimals());

        if (positionReductionBase <= _inputMax) {
            return positionReductionBase;
        } else {
            return _inputMax;
        }
    }
}
