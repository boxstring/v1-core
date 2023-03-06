// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// Foundry
import {Test} from "forge-std/Test.sol";

// Local file imports
import {AddressLib} from "../../src/libraries/AddressLib.sol";
import {USDC_ADDRESS, DAI_ADDRESS, WETH_ADDRESS, wBTC_ADDRESS} from "../common/Constants.t.sol";

contract AddressLibTest is Test {
    using AddressLib for address[];

    address[] public actualArray;
    address[] public expectedArray;

    function test_removeAddress() public {
        // Arrange
        address keepAddress1 = USDC_ADDRESS;
        address keepAddress2 = DAI_ADDRESS;
        address removeAddress = WETH_ADDRESS;

        actualArray.push(keepAddress1);
        actualArray.push(removeAddress);
        actualArray.push(keepAddress2);

        expectedArray = [keepAddress1, keepAddress2];

        // Act
        actualArray.removeAddress(removeAddress);

        // Assert
        assertEq(actualArray, expectedArray);
    }

    function test_includes_addressIncluded() public {
        // Arrange
        bool addressIncluded = false;
        address testAddress1 = USDC_ADDRESS;
        address testAddress2 = DAI_ADDRESS;
        address targetAddress = WETH_ADDRESS;

        actualArray.push(testAddress1);
        actualArray.push(testAddress2);
        actualArray.push(targetAddress);

        // Act
        addressIncluded = actualArray.includes(targetAddress);

        // Assert
        assertEq(addressIncluded, true);
    }

    function test_includes_addressNotIncluded() public {
        // Arrange
        bool addressIncluded = false;
        address testAddress1 = USDC_ADDRESS;
        address testAddress2 = DAI_ADDRESS;
        address testAddress3 = WETH_ADDRESS;
        address targetAddress = wBTC_ADDRESS;

        actualArray.push(testAddress1);
        actualArray.push(testAddress2);
        actualArray.push(testAddress3);

        // Act
        addressIncluded = actualArray.includes(targetAddress);

        // Assert
        assertEq(addressIncluded, false);
    }
}
