// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IRig
 * @notice Interface for the Rig contract.
 */
interface IRig {
    // Constants
    function INITIAL_EMISSION() external view returns (uint256);
    function MIN_EMISSION() external view returns (uint256);
    function HALVING_PERIOD() external view returns (uint256);
    function DAY_DURATION() external view returns (uint256);
    function CHARITY_BPS() external view returns (uint256);
    function TREASURY_BPS() external view returns (uint256);
    function TEAM_BPS() external view returns (uint256);
    function DIVISOR() external view returns (uint256);

    // Immutables
    function paymentToken() external view returns (IERC20);
    function unit() external view returns (address);
    function START_TIME() external view returns (uint256);

    // State
    function account_IsCharity(address charity) external view returns (bool);
    function treasuryAddress() external view returns (address);
    function teamAddress() external view returns (address);
    function day_TotalDonated(uint256 day) external view returns (uint256);
    function day_Account_Donation(uint256 day, address user) external view returns (uint256);
    function day_Account_HasClaimed(uint256 day, address user) external view returns (bool);

    // Functions
    function donate(address account, address charity, uint256 amount) external;
    function claim(address account, uint256 day) external;
    function addCharity(address _charity) external;
    function removeCharity(address _charity) external;
    function setTreasuryAddress(address _treasury) external;
    function setTeamAddress(address _team) external;

    // Views
    function currentDay() external view returns (uint256);
    function getDayEmission(uint256 day) external pure returns (uint256);
    function getPendingReward(uint256 day, address user) external view returns (uint256);
    function getUserDonation(uint256 day, address user) external view returns (uint256);
    function getDayTotal(uint256 day) external view returns (uint256);

    // Events
    event Donation(address indexed user, address indexed charity, uint256 amount, uint256 day);
    event Claim(address indexed user, uint256 amount, uint256 day);
    event CharityAdded(address indexed charity);
    event CharityRemoved(address indexed charity);
    event TreasuryAddressSet(address indexed treasuryAddress);
    event TeamAddressSet(address indexed teamAddress);
}
