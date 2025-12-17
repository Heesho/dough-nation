// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUnit} from "./interfaces/IUnit.sol";

/**
 * @title Rig
 * @notice Core engine for the DoughNation protocol. Accepts ERC-20 donations,
 *         splits funds between charity/treasury/team, and mints DOUGH tokens to donors.
 * @dev Users donate Payment Tokens to a daily pool. After the day ends, users can claim
 *      their proportional share of that day's DOUGH emission based on their contribution.
 *
 *      Emission Schedule:
 *      - Initial: 345,600 DOUGH/day
 *      - Halving: Every 30 days
 *      - Floor: 864 DOUGH/day
 *
 *      Fund Split:
 *      - 50% to Charity (user-selected from whitelist)
 *      - 45% to Treasury
 *      - 5% to Team (receives remaining balance to handle dust)
 */
contract Rig is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant INITIAL_EMISSION = 345_600 * 1e18; // 345,600 DOUGH per day
    uint256 public constant MIN_EMISSION = 864 * 1e18; // 864 DOUGH per day (floor)
    uint256 public constant HALVING_PERIOD = 30 days;
    uint256 public constant DAY_DURATION = 1 days;

    uint256 public constant CHARITY_BPS = 5_000; // 50%
    uint256 public constant TREASURY_BPS = 4_500; // 45%
    uint256 public constant TEAM_BPS = 500; // 5%
    uint256 public constant DIVISOR = 10_000;

    /*----------  IMMUTABLES  -------------------------------------------*/

    IERC20 public immutable paymentToken;
    address public immutable unit;
    uint256 public immutable START_TIME;

    /*----------  STATE  ------------------------------------------------*/

    /// @notice Mapping of whitelisted charity addresses
    mapping(address => bool) public account_IsCharity;

    address public treasuryAddress;
    address public teamAddress;

    /// @notice Total payment tokens donated on a given day
    mapping(uint256 => uint256) public day_TotalDonated;

    /// @notice Payment tokens donated by a specific user on a given day
    mapping(uint256 => mapping(address => uint256)) public day_Account_Donation;

    /// @notice Whether a user has claimed their DOUGH for a given day
    mapping(uint256 => mapping(address => bool)) public day_Account_HasClaimed;

    /*----------  ERRORS  -----------------------------------------------*/

    error Rig__ZeroAmount();
    error Rig__DayNotEnded();
    error Rig__AlreadyClaimed();
    error Rig__NoDonation();
    error Rig__InvalidAddress();
    error Rig__NotCharity();

    /*----------  EVENTS  -----------------------------------------------*/

    event Donation(address indexed user, address indexed charity, uint256 amount, uint256 day);
    event Claim(address indexed user, uint256 amount, uint256 day);
    event CharityAdded(address indexed charity);
    event CharityRemoved(address indexed charity);
    event TreasuryAddressSet(address indexed treasuryAddress);
    event TeamAddressSet(address indexed teamAddress);

    /*----------  CONSTRUCTOR  ------------------------------------------*/

    /**
     * @notice Deploy a new Rig contract.
     * @param _paymentToken The ERC-20 token accepted for donations (e.g., USDC, WETH)
     * @param _unit The Unit token that will be minted to donors
     * @param _treasury Address to receive 45% of donations
     * @param _team Address to receive 5% of donations (remaining balance)
     */
    constructor(
        address _paymentToken,
        address _unit,
        address _treasury,
        address _team
    ) {
        if (_paymentToken == address(0)) revert Rig__InvalidAddress();
        if (_unit == address(0)) revert Rig__InvalidAddress();
        if (_treasury == address(0)) revert Rig__InvalidAddress();
        if (_team == address(0)) revert Rig__InvalidAddress();

        paymentToken = IERC20(_paymentToken);
        unit = _unit;
        treasuryAddress = _treasury;
        teamAddress = _team;
        START_TIME = block.timestamp;
    }

    /*----------  EXTERNAL FUNCTIONS  -----------------------------------*/

    /**
     * @notice Donate payment tokens to the daily pool on behalf of an account.
     * @dev Requires msg.sender to have approved this contract for `amount`.
     *      Transfers `amount` from msg.sender, splits it 50/45/5, and credits `account`.
     *      This allows multicall contracts to donate on behalf of users.
     * @param account The account to credit for this donation (receives DOUGH on claim)
     * @param charity The whitelisted charity address to receive 50% of donation
     * @param amount The amount of payment tokens to donate
     */
    function donate(address account, address charity, uint256 amount) external nonReentrant {
        if (account == address(0)) revert Rig__InvalidAddress();
        if (amount == 0) revert Rig__ZeroAmount();
        if (!account_IsCharity[charity]) revert Rig__NotCharity();

        uint256 day = currentDay();

        // Transfer tokens from msg.sender (payer)
        paymentToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate splits
        uint256 charityAmount = amount * CHARITY_BPS / DIVISOR;
        uint256 teamAmount = teamAddress != address(0) ? amount * TEAM_BPS / DIVISOR : 0;
        uint256 treasuryAmount = amount - charityAmount - teamAmount;

        // Distribute funds
        paymentToken.safeTransfer(charity, charityAmount);
        paymentToken.safeTransfer(treasuryAddress, treasuryAmount);
        if (teamAmount > 0) {
            paymentToken.safeTransfer(teamAddress, teamAmount);
        }

        // Update state - credit the account, not msg.sender
        day_TotalDonated[day] += amount;
        day_Account_Donation[day][account] += amount;

        emit Donation(account, charity, amount, day);
    }

    /**
     * @notice Claim DOUGH tokens for a completed day on behalf of an account.
     * @dev Can only be called after the specified day has ended.
     *      Mints DOUGH proportional to account's share of that day's donations.
     *      This allows multicall contracts to claim on behalf of users.
     * @param account The account to claim for (must have donated, receives DOUGH)
     * @param day The day number to claim for
     */
    function claim(address account, uint256 day) external nonReentrant {
        if (account == address(0)) revert Rig__InvalidAddress();
        if (day >= currentDay()) revert Rig__DayNotEnded();
        if (day_Account_HasClaimed[day][account]) revert Rig__AlreadyClaimed();

        uint256 userDonation = day_Account_Donation[day][account];
        if (userDonation == 0) revert Rig__NoDonation();

        uint256 dayTotal = day_TotalDonated[day];
        uint256 dayEmission = getDayEmission(day);

        // Calculate user's share: (userDonation / dayTotal) * dayEmission
        uint256 userReward = (userDonation * dayEmission) / dayTotal;

        // Mark as claimed before minting (CEI pattern)
        day_Account_HasClaimed[day][account] = true;

        // Mint DOUGH to the account
        IUnit(unit).mint(account, userReward);

        emit Claim(account, userReward, day);
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    /**
     * @notice Add an address to the charity whitelist.
     * @param _charity Address to whitelist
     */
    function addCharity(address _charity) external onlyOwner {
        if (_charity == address(0)) revert Rig__InvalidAddress();
        account_IsCharity[_charity] = true;
        emit CharityAdded(_charity);
    }

    /**
     * @notice Remove an address from the charity whitelist.
     * @param _charity Address to remove from whitelist
     */
    function removeCharity(address _charity) external onlyOwner {
        account_IsCharity[_charity] = false;
        emit CharityRemoved(_charity);
    }

    /**
     * @notice Update the treasury address.
     * @param _treasury New treasury address
     */
    function setTreasuryAddress(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert Rig__InvalidAddress();
        treasuryAddress = _treasury;
        emit TreasuryAddressSet(_treasury);
    }

    /**
     * @notice Update the team address.
     * @dev Can be set to address(0) to redirect team fees to treasury.
     * @param _team New team address (or address(0) to disable)
     */
    function setTeamAddress(address _team) external onlyOwner {
        teamAddress = _team;
        emit TeamAddressSet(_team);
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    /**
     * @notice Get the current day number since contract deployment.
     * @return The current day (0-indexed)
     */
    function currentDay() public view returns (uint256) {
        return (block.timestamp - START_TIME) / DAY_DURATION;
    }

    /**
     * @notice Get the DOUGH emission for a specific day.
     * @dev Emission halves every 30 days with a floor of MIN_EMISSION.
     * @param day The day number to query
     * @return The DOUGH emission for that day
     */
    function getDayEmission(uint256 day) public pure returns (uint256) {
        uint256 halvings = day / 30; // Number of 30-day periods
        uint256 emission = INITIAL_EMISSION >> halvings; // Right shift = divide by 2^halvings

        if (emission < MIN_EMISSION) {
            return MIN_EMISSION;
        }
        return emission;
    }

    /**
     * @notice Get pending DOUGH reward for a user on a specific day.
     * @dev Returns 0 if day hasn't ended, already claimed, or no donation.
     * @param day The day number to query
     * @param user The user address to query
     * @return The pending DOUGH reward
     */
    function getPendingReward(uint256 day, address user) external view returns (uint256) {
        if (day >= currentDay()) return 0;
        if (day_Account_HasClaimed[day][user]) return 0;

        uint256 userDonation = day_Account_Donation[day][user];
        if (userDonation == 0) return 0;

        uint256 dayTotal = day_TotalDonated[day];
        uint256 dayEmission = getDayEmission(day);

        return (userDonation * dayEmission) / dayTotal;
    }

    /**
     * @notice Get user's donation amount for a specific day.
     * @param day The day number to query
     * @param user The user address to query
     * @return The donation amount
     */
    function getUserDonation(uint256 day, address user) external view returns (uint256) {
        return day_Account_Donation[day][user];
    }

    /**
     * @notice Get total donations for a specific day.
     * @param day The day number to query
     * @return The total donation amount
     */
    function getDayTotal(uint256 day) external view returns (uint256) {
        return day_TotalDonated[day];
    }
}
