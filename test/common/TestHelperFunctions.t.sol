// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Local file imports
import {PricingLib} from "../../src/libraries/PricingLib.sol";

library TestHelperFunctions {
    using PricingLib for address;

    // Convert tokenInAmount (Units: tokenIn) ---> outputTokenAmount (Units: tokenOut)
    function convertTokenAmount(
        address tokenIn,
        address tokenOut,
        uint256 tokenInAmount,
        uint256 tokenInDecimals,
        uint256 tokenOutDecimals
    ) public view returns (uint256 outputTokenAmount) {
        uint256 tokenOutConversion = 10 ** (18 - tokenOutDecimals);
        uint256 tokenInPowTenDecimals = 10 ** tokenInDecimals;
        unchecked {
            outputTokenAmount =
                ((tokenIn.pricedIn(tokenOut) * tokenInAmount) / tokenOutConversion) / tokenInPowTenDecimals;
            return outputTokenAmount;
        }
    }

    function getNumDecimals(uint256 num) public pure returns (uint256 numDecimals) {
        numDecimals = 0;
        while (num > 0) {
            num /= 10;
            numDecimals++;
        }
        return numDecimals;
    }
}
