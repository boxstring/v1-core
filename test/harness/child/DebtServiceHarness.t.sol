// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Local file imports
import {DebtService} from "../../../src/child/DebtService.sol";

contract DebtServiceHarness is DebtService {
    constructor(address _user, address _baseToken, uint256 _baseTokenDecimals, uint256 _shaaveLTV)
        DebtService(_user, _baseToken, _baseTokenDecimals, _shaaveLTV)
    {}

    function exposed_borrowAsset(
        address _shortToken,
        address _user,
        uint256 _baseTokenAmount,
        uint256 _shortTokenDecimals
    ) external returns (uint256 borrowAmount) {
        return DebtService.borrowAsset(_shortToken, _user, _baseTokenAmount, _shortTokenDecimals);
    }

    function exposed_repayAsset(address _shortToken, uint256 _amount) external {
        DebtService.repayAsset(_shortToken, _amount);
    }

    function exposed_withdraw(uint256 amount) external {
        DebtService.withdraw(amount);
    }
}
