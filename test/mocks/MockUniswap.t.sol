// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// External packages
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapRouter} from "@uniswap-v3-periphery/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap-v3-periphery/libraries/TransferHelper.sol";

// Local file imports
import {PricingLib} from "../../src/libraries/PricingLib.sol";
import {IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {SHORT_TOKEN, UNISWAP_AMOUNT_IN_PROFIT} from "../common/Constants.t.sol";

contract MockUniswapGains {
    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata params)
        public
        payable
        returns (uint256 amountIn)
    {
        amountIn = UNISWAP_AMOUNT_IN_PROFIT;
        TransferHelper.safeTransferFrom(params.tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeTransfer(SHORT_TOKEN, msg.sender, IERC20(SHORT_TOKEN).balanceOf(address(this)));
    }
}

contract MockUniswapLosses {
    function exactOutputSingle() public pure {
        revert("Mocking a failure here.");
    }

    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params)
        public
        payable
        returns (uint256 amountOut)
    {
        amountOut = IERC20(SHORT_TOKEN).balanceOf(address(this));
        TransferHelper.safeTransferFrom(params.tokenIn, msg.sender, address(this), params.amountIn);
        TransferHelper.safeTransfer(SHORT_TOKEN, msg.sender, amountOut);
    }
}

contract MockUniswapGeneral {
    using PricingLib for address;

    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params)
        public
        payable
        returns (uint256 amountOut)
    {
        amountOut = IERC20(params.tokenOut).balanceOf(address(this));
        TransferHelper.safeTransferFrom(params.tokenIn, msg.sender, address(this), params.amountIn);
        TransferHelper.safeTransfer(params.tokenOut, msg.sender, amountOut);
    }

    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata params)
        public
        payable
        returns (uint256 amountIn)
    {
        uint256 tokenInDecimals = IERC20Metadata(params.tokenIn).decimals();
        uint256 tokenOutDecimals = IERC20Metadata(params.tokenOut).decimals();
        uint256 tokenOutPowTenDecimals = (10 ** tokenOutDecimals);
        uint256 tokenInConversion = 10 ** (18 - tokenInDecimals);
        uint256 tokenInAmount =
            ((params.tokenOut.pricedIn(params.tokenIn) * params.amountOut) / tokenInConversion) / tokenOutPowTenDecimals;

        // TokenInAmount is converted from params.amountOut to tokenIn units so that this mock only consumes
        // an "exact" swap, nothing more. Alternative considered: just `safeTransferFrom` the entire params.amountInMaximum
        amountIn = tokenInAmount;
        TransferHelper.safeTransferFrom(params.tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeTransfer(params.tokenOut, msg.sender, IERC20(params.tokenOut).balanceOf(address(this)));
    }
}

contract MockUniswapLowLevelError {
    event LowLevelError(bytes errorData, string executionInsight);

    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params)
        public
        payable
        returns (uint256 amountOut)
    {
        amountOut = IERC20(params.tokenOut).balanceOf(address(this));
        TransferHelper.safeTransferFrom(params.tokenIn, msg.sender, address(this), params.amountIn);
        TransferHelper.safeTransfer(params.tokenOut, msg.sender, amountOut);
    }

    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata params)
        public
        payable
        returns (uint256 amountIn)
    {
        bytes memory data;

        amountIn = params.amountInMaximum;
        data = hex"01020304";

        assembly {
            let returndata_size := mload(data)
            revert(add(32, data), returndata_size)
        }
    }
}
