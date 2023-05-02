// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract AccountingService {
    // Storage Variables
    struct PositionData {
        // -- Arrays related to adding to a position --
        uint256[] shortTokenAmountsSwapped;
        uint256[] baseAmountsReceived;
        uint256[] collateralAmounts;
        // -- Arrays related to reducing a position --
        uint256[] baseAmountsSwapped;
        uint256[] shortTokenAmountsReceived;
        // -- Miscellaneous --
        uint256 backingBaseAmount;
        address shortTokenAddress;
        bool hasDebt;
    }

    address public immutable user;
    mapping(address => PositionData) public userPositions;
    address[] internal openedShortPositions;

    constructor(address _user) {
        user = _user;
    }

    /**
     * @dev  This function returns a list of user's positions and their associated accounting data.
     * @return aggregatedPositionData A list of user's positions and their associated accounting data.
     */
    function getAccountingData() external view userOnly returns (PositionData[] memory) {
        address[] memory _openedShortPositions = openedShortPositions; // Optimizes gas
        PositionData[] memory aggregatedPositionData = new PositionData[](_openedShortPositions.length);
        for (uint256 i = 0; i < _openedShortPositions.length; i++) {
            PositionData storage position = userPositions[_openedShortPositions[i]];
            aggregatedPositionData[i] = position;
        }
        return aggregatedPositionData;
    }

    modifier userOnly() {
        require(msg.sender == user, "Unauthorized.");
        _;
    }
}
