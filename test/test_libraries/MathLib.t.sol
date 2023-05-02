// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Foundry
import {Test, stdError} from "forge-std/Test.sol";

// Local file imports
import {MathLib} from "../../src/libraries/MathLib.sol";
import {TestHelperFunctions} from "../common/TestHelperFunctions.t.sol";

contract MathTest is Test {
    using MathLib for uint256;
    using TestHelperFunctions for uint256;

    // Variable Declaration
    uint256 uint256MaxDecimals;

    function setUp() public {
        // Instantiate Variables
        uint256MaxDecimals = type(uint256).max.getNumDecimals();
    }

    function test_dividedBy_nominal(uint256 numerator, uint256 denominator, uint256 precision) public {
        // Setup
        vm.assume(
            denominator > 0 && precision <= 18
                && (numerator.getNumDecimals() + precision) > denominator.getNumDecimals()
                && (numerator.getNumDecimals() + precision) <= uint256MaxDecimals - 1
        );
        uint256 quotientActual;
        uint256 quotientExpected = (numerator * (10 ** precision)) / denominator;

        // Act
        quotientActual = numerator.dividedBy(denominator, precision);

        // Assert
        assertEq(quotientActual, quotientExpected);
    }

    function test_dividedBy_divideZeroError(uint256 numerator, uint256 precision) public {
        // Setup
        vm.assume(precision <= 18 && (numerator.getNumDecimals() + precision) <= uint256MaxDecimals - 1);

        // Act
        vm.expectRevert(stdError.divisionError);
        numerator.dividedBy(uint256(0), precision);
    }

    function test_dividedBy_NumeratorTooLargeArithmeticError(uint256 numerator, uint256 denominator, uint256 precision)
        public
    {
        // Setup
        vm.assume(
            denominator > 0 && precision <= 18
                && (numerator.getNumDecimals() + precision) > denominator.getNumDecimals()
                && (numerator.getNumDecimals() + precision) > uint256MaxDecimals
        );

        // Act
        vm.expectRevert(stdError.arithmeticError);
        numerator.dividedBy(denominator, precision);
    }

    function test_dividedBy_DenominatorTooLargeTruncatesToZero(
        uint256 numerator,
        uint256 denominator,
        uint256 precision
    ) public {
        // Setup
        vm.assume(
            denominator > 0 && precision <= 18
                && (numerator.getNumDecimals() + precision) < denominator.getNumDecimals()
                && (numerator.getNumDecimals() + precision) <= uint256MaxDecimals - 1
        );
        uint256 quotientActual;

        // Act
        quotientActual = numerator.dividedBy(denominator, precision);

        // Assert
        assertEq(quotientActual, uint256(0));
    }
}
