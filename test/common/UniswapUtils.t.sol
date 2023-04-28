// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Foundry
import {Test} from "forge-std/Test.sol";

// Local imports
import {ISwapRouter} from "../../src/interfaces/uniswap/ISwapRouter.sol";
import {IERC20Metadata} from "../../src/interfaces/token/IERC20Metadata.sol";
import {TransferHelper} from "../../src/libraries/uniswap/TransferHelper.sol";
import {PricingLib} from "../../src/libraries/PricingLib.sol";
import "./Constants.t.sol";

contract UniswapUtils is Test {
    using PricingLib for address;

    /// @dev This is a test function for computing expected results
    function swapExactInputExpect(address _inputToken, address _outputToken, uint256 _tokenInAmount)
        public
        returns (uint256 amountIn, uint256 amountOut)
    {
        /// Take snapshot of blockchain state
        uint256 id = vm.snapshot();

        deal(_inputToken, address(this), _tokenInAmount);

        ISwapRouter SWAP_ROUTER = ISwapRouter(UNISWAP_SWAP_ROUTER);
        TransferHelper.safeApprove(_inputToken, address(SWAP_ROUTER), _tokenInAmount);

        uint256 amountOutMinimum = (
            ((_inputToken.pricedIn(_outputToken) * _tokenInAmount * AMOUNT_OUT_MINIMUM_PERCENTAGE) / 100)
                / (10 ** IERC20Metadata(_inputToken).decimals())
        ) // tokenIn conversion
            / 10 ** (18 - IERC20Metadata(_outputToken).decimals()); // tokenOut conversion

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _inputToken,
            tokenOut: _outputToken,
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _tokenInAmount,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        (amountIn, amountOut) = (_tokenInAmount, SWAP_ROUTER.exactInputSingle(params));

        // Revert to previous snapshot, as if swap never happend
        vm.revertTo(id);
    }

    /// @dev This is a test function for computing expected results
    function swapToShortTokenExpect(
        address _outputToken,
        address _inputToken,
        uint256 _outputTokenAmount,
        uint256 _inputMax,
        uint256 baseTokenConversion
    ) internal returns (uint256 amountIn, uint256 amountOut) {
        /// Take snapshot of blockchain state
        uint256 id = vm.snapshot();

        // Give this contract (positionBackingBaseAmount) base tokens
        deal(BASE_TOKEN, address(this), _inputMax);

        ISwapRouter SWAP_ROUTER = ISwapRouter(UNISWAP_SWAP_ROUTER);
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
            (amountIn, amountOut) = (returnedAmountIn, _outputTokenAmount);
        } catch {
            amountIn = getAmountIn(_outputTokenAmount, _outputToken, _inputMax, baseTokenConversion);
            (amountIn, amountOut) = swapExactInputExpect(_inputToken, _outputToken, amountIn);
        }

        // Revert to previous snapshot, as if swap never happend
        vm.revertTo(id);
    }

    /// @dev This is a test function for computing expected results
    function getAmountIn(
        uint256 _positionReduction,
        address _shortToken,
        uint256 _backingBaseAmount,
        uint256 baseTokenConversion
    ) internal view returns (uint256) {
        /// @dev Units: baseToken decimals
        uint256 priceOfShortTokenInBase = _shortToken.pricedIn(BASE_TOKEN) / baseTokenConversion;

        /// @dev Units: baseToken decimals = (baseToken decimals * shortToken decimals) / shortToken decimals
        uint256 positionReductionBase =
            (priceOfShortTokenInBase * _positionReduction) / (10 ** IERC20Metadata(_shortToken).decimals());

        if (positionReductionBase <= _backingBaseAmount) {
            return positionReductionBase;
        } else {
            return _backingBaseAmount;
        }
    }
}
