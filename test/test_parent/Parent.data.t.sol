// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "solmate/utils/SafeTransferLib.sol";
import "@aave-protocol/interfaces/IPool.sol";

import "../../src/parent/Parent.sol";
import "../../src/libraries/AddressLib.sol";
import "../common/ParentUtils.t.sol";
import "../common/Constants.t.sol";

contract DataTest is ParentUtils, TestUtils, Test {
    using AddressLib for address[];

    // Variables
    address[] baseTokens;
    address[] childContracts;

    // Contracts
    Parent shaaveParent;

    function setUp() public {
        shaaveParent = new Parent(10);
    }

    function test_retrieveChildrenByUser() public {
        // Setup: open short positions will all collateral tokens

        for (uint256 i = 0; i < BLUE_CHIP_COLLATERAL.length; i++) {
            address baseToken = BLUE_CHIP_COLLATERAL[i];
            if (baseToken != SHORT_TOKEN) {
                uint256 baseTokenAmount = (10 ** IERC20Metadata(baseToken).decimals()); // 1 unit in correct decimals
                deal(baseToken, address(this), baseTokenAmount);
                SafeTransferLib.safeApprove(ERC20(baseToken), address(shaaveParent), baseTokenAmount);

                // Act
                shaaveParent.addShortPosition(SHORT_TOKEN, baseToken, baseTokenAmount);

                // Record
                address child = shaaveParent.userContracts(address(this), baseToken);
                baseTokens.push(baseToken);
                childContracts.push(child);
            }
        }

        // Act
        address[2][] memory childDataArray = shaaveParent.retrieveChildrenByUser();

        // Assertions
        uint256 childCount;
        for (uint256 i = 0; i < childDataArray.length; i++) {
            if (childDataArray[i][0] != address(0)) {
                assertEq(childDataArray[i].length, 2, "Incorrect nested array length.");
                assertEq(
                    childContracts.includes(childDataArray[i][0]),
                    true,
                    "Incorrect childDataArray: lacking childContract"
                );
                assertEq(baseTokens.includes(childDataArray[i][1]), true, "Incorrect childDataArray: lacking baseToken");

                childCount++;
            }
        }

        assertEq(childCount, baseTokens.length, "Incorrect childDataArray: length");
    }

    function test_getNeededCollateralAmount(uint256 amountMultiplier) public {
        // Assumptions
        vm.assume(amountMultiplier > 0 && amountMultiplier <= 1000);

        // Setup
        uint256 shortTokenAmount = (10 ** IERC20Metadata(SHORT_TOKEN).decimals()) * amountMultiplier; // 1 unit in correct decimals * amountMultiplier

        // Expectations
        uint256 expectedCollateralAmount = expectedCollateralAmount(SHORT_TOKEN, BASE_TOKEN, shortTokenAmount);

        // Act
        uint256 collateralAmount = shaaveParent.getNeededCollateralAmount(SHORT_TOKEN, BASE_TOKEN, shortTokenAmount);

        // Assertions
        assertEq(collateralAmount, expectedCollateralAmount, "Incorrect collateralAmount.");
    }
}
