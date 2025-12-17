// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRig} from "./interfaces/IRig.sol";
import {IAuction} from "./interfaces/IAuction.sol";

/**
 * @title Multicall
 * @notice Helper contract for batched operations and aggregated view functions.
 * @dev Provides USDC donation batching and comprehensive state queries for the UI.
 */
contract Multicall {
    using SafeERC20 for IERC20;

    /*----------  IMMUTABLES  -------------------------------------------*/

    address public immutable rig;
    address public immutable auction;
    address public immutable paymentToken;
    address public immutable unit;
    address public immutable donut;

    /*----------  STRUCTS  ----------------------------------------------*/

    /**
     * @notice Aggregated state for the Rig and a specific user.
     */
    struct RigState {
        // Protocol state
        uint256 currentDay;
        uint256 todayEmission;
        uint256 todayTotalDonated;
        uint256 startTime;
        address treasuryAddress;
        address teamAddress;
        uint256 unitPrice; // DOUGH price in DONUT (from LP reserves)
        // User state
        uint256 userTodayDonation;
        uint256 paymentTokenBalance;
        uint256 unitBalance;
        uint256 paymentTokenAllowance;
    }

    /**
     * @notice Claimable day info for a user.
     */
    struct ClaimableDay {
        uint256 day;
        uint256 donation;
        uint256 pendingReward;
        bool hasClaimed;
    }

    /**
     * @notice Aggregated state for the Auction contract.
     */
    struct AuctionState {
        uint256 epochId;
        uint256 initPrice;
        uint256 startTime;
        address auctionPaymentToken;
        uint256 price;
        uint256 auctionPaymentTokenPrice; // LP token price in DONUT
        uint256 auctionPaymentTokenBalance;
    }

    /*----------  CONSTRUCTOR  ------------------------------------------*/

    /**
     * @notice Deploy the Multicall helper contract.
     * @param _rig Rig contract address
     * @param _auction Auction contract address
     * @param _donut DONUT token address
     */
    constructor(address _rig, address _auction, address _donut) {
        rig = _rig;
        auction = _auction;
        donut = _donut;
        paymentToken = address(IRig(_rig).paymentToken());
        unit = IRig(_rig).unit();
    }

    /*----------  EXTERNAL FUNCTIONS  -----------------------------------*/

    /**
     * @notice Donate using payment token (USDC).
     * @dev Transfers tokens from caller, approves Rig, and donates on behalf of account.
     * @param account The account to credit for this donation
     * @param charity The whitelisted charity address
     * @param amount The amount of payment tokens to donate
     */
    function donate(address account, address charity, uint256 amount) external {
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(paymentToken).safeApprove(rig, 0);
        IERC20(paymentToken).safeApprove(rig, amount);
        IRig(rig).donate(account, charity, amount);
    }

    /**
     * @notice Claim DOUGH for a single day.
     * @param account The account to claim for
     * @param day The day to claim
     */
    function claim(address account, uint256 day) external {
        IRig(rig).claim(account, day);
    }

    /**
     * @notice Claim DOUGH for multiple days in a single transaction.
     * @dev Skips days that are already claimed, have no donation, or haven't ended.
     * @param account The account to claim for
     * @param dayIds Array of days to claim
     */
    function claimMultiple(address account, uint256[] calldata dayIds) external {
        uint256 currentDay = IRig(rig).currentDay();
        for (uint256 i = 0; i < dayIds.length; i++) {
            if (!IRig(rig).day_Account_HasClaimed(dayIds[i], account) &&
                IRig(rig).day_Account_Donation(dayIds[i], account) > 0 &&
                dayIds[i] < currentDay) {
                IRig(rig).claim(account, dayIds[i]);
            }
        }
    }

    /**
     * @notice Buy accumulated assets from the Auction using LP tokens.
     * @dev Transfers LP tokens from caller, approves Auction, and executes buy.
     * @param assets Array of token addresses to claim from the Auction
     * @param epochId Expected epoch ID (frontrun protection)
     * @param deadline Transaction deadline timestamp
     * @param maxPaymentTokenAmount Maximum LP tokens willing to pay (slippage protection)
     */
    function buy(
        address[] calldata assets,
        uint256 epochId,
        uint256 deadline,
        uint256 maxPaymentTokenAmount
    ) external {
        address auctionPaymentToken = IAuction(auction).paymentToken();
        uint256 price = IAuction(auction).getPrice();

        IERC20(auctionPaymentToken).safeTransferFrom(msg.sender, address(this), price);
        IERC20(auctionPaymentToken).safeApprove(auction, 0);
        IERC20(auctionPaymentToken).safeApprove(auction, price);
        IAuction(auction).buy(assets, msg.sender, epochId, deadline, maxPaymentTokenAmount);
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    /**
     * @notice Get aggregated state for the Rig and a user.
     * @param account User address (or address(0) to skip user-specific queries)
     * @return state Aggregated rig and user state
     */
    function getRigState(address account) external view returns (RigState memory state) {
        uint256 day = IRig(rig).currentDay();

        // Protocol state
        state.currentDay = day;
        state.todayEmission = IRig(rig).getDayEmission(day);
        state.todayTotalDonated = IRig(rig).getDayTotal(day);
        state.startTime = IRig(rig).START_TIME();
        state.treasuryAddress = IRig(rig).treasuryAddress();
        state.teamAddress = IRig(rig).teamAddress();

        // Calculate DOUGH price in DONUT from LP reserves
        // LP token is DOUGH-DONUT, price = donutInLP / doughInLP
        address lpToken = IAuction(auction).paymentToken();
        uint256 donutInLP = IERC20(donut).balanceOf(lpToken);
        uint256 doughInLP = IERC20(unit).balanceOf(lpToken);
        state.unitPrice = doughInLP == 0 ? 0 : (donutInLP * 1e18) / doughInLP;

        // User state
        if (account != address(0)) {
            state.userTodayDonation = IRig(rig).getUserDonation(day, account);
            state.paymentTokenBalance = IERC20(paymentToken).balanceOf(account);
            state.unitBalance = IERC20(unit).balanceOf(account);
            state.paymentTokenAllowance = IERC20(paymentToken).allowance(account, rig);
        }

        return state;
    }

    /**
     * @notice Get claimable days for a user within a range.
     * @dev Returns info for days from startDay to endDay (exclusive). Useful for UI to show pending claims.
     * @param account User address
     * @param startDay First day to check (inclusive)
     * @param endDay Last day to check (exclusive)
     * @return claimableDays Array of claimable day info
     */
    function getClaimableDays(address account, uint256 startDay, uint256 endDay)
        external
        view
        returns (ClaimableDay[] memory claimableDays)
    {
        if (endDay <= startDay) {
            return new ClaimableDay[](0);
        }

        uint256 count = endDay - startDay;
        claimableDays = new ClaimableDay[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 day = startDay + i;
            claimableDays[i] = ClaimableDay({
                day: day,
                donation: IRig(rig).day_Account_Donation(day, account),
                pendingReward: IRig(rig).getPendingReward(day, account),
                hasClaimed: IRig(rig).day_Account_HasClaimed(day, account)
            });
        }

        return claimableDays;
    }

    /**
     * @notice Get total pending rewards across a range of days.
     * @param account User address
     * @param startDay First day to check (inclusive)
     * @param endDay Last day to check (exclusive)
     * @return totalPending Total unclaimed DOUGH across all checked days
     * @return unclaimedDays Array of day numbers that have unclaimed rewards
     */
    function getTotalPendingRewards(address account, uint256 startDay, uint256 endDay)
        external
        view
        returns (uint256 totalPending, uint256[] memory unclaimedDays)
    {
        if (endDay <= startDay) {
            return (0, new uint256[](0));
        }

        // First pass: count unclaimed days
        uint256 unclaimedCount = 0;
        for (uint256 day = startDay; day < endDay; day++) {
            uint256 pending = IRig(rig).getPendingReward(day, account);
            if (pending > 0) {
                totalPending += pending;
                unclaimedCount++;
            }
        }

        // Second pass: collect unclaimed day numbers
        unclaimedDays = new uint256[](unclaimedCount);
        uint256 index = 0;
        for (uint256 day = startDay; day < endDay; day++) {
            if (IRig(rig).getPendingReward(day, account) > 0) {
                unclaimedDays[index] = day;
                index++;
            }
        }

        return (totalPending, unclaimedDays);
    }

    /**
     * @notice Get emission schedule for upcoming days.
     * @param numDays Number of days to project
     * @return emissions Array of daily emissions starting from current day
     */
    function getEmissionSchedule(uint256 numDays)
        external
        view
        returns (uint256[] memory emissions)
    {
        uint256 currentDay = IRig(rig).currentDay();
        emissions = new uint256[](numDays);

        for (uint256 i = 0; i < numDays; i++) {
            emissions[i] = IRig(rig).getDayEmission(currentDay + i);
        }

        return emissions;
    }

    /**
     * @notice Check if a charity is whitelisted.
     * @param charity Address to check
     * @return isWhitelisted True if charity is whitelisted
     */
    function isCharity(address charity) external view returns (bool) {
        return IRig(rig).account_IsCharity(charity);
    }

    /**
     * @notice Get donation history for a user within a range.
     * @param account User address
     * @param startDay First day to check (inclusive)
     * @param endDay Last day to check (exclusive)
     * @return totalDonated Total amount donated across all checked days
     * @return donationsByDay Array of donation amounts per day
     */
    function getDonationHistory(address account, uint256 startDay, uint256 endDay)
        external
        view
        returns (uint256 totalDonated, uint256[] memory donationsByDay)
    {
        if (endDay <= startDay) {
            return (0, new uint256[](0));
        }

        uint256 numDays = endDay - startDay;
        donationsByDay = new uint256[](numDays);

        for (uint256 i = 0; i < numDays; i++) {
            uint256 day = startDay + i;
            donationsByDay[i] = IRig(rig).day_Account_Donation(day, account);
            totalDonated += donationsByDay[i];
        }

        return (totalDonated, donationsByDay);
    }

    /**
     * @notice Get aggregated state for the Auction and a user.
     * @param account User address (or address(0) to skip user-specific queries)
     * @return state Aggregated auction state
     */
    function getAuctionState(address account) external view returns (AuctionState memory state) {
        state.epochId = IAuction(auction).epochId();
        state.initPrice = IAuction(auction).initPrice();
        state.startTime = IAuction(auction).startTime();
        state.auctionPaymentToken = IAuction(auction).paymentToken();
        state.price = IAuction(auction).getPrice();

        // Calculate LP token price in DONUT
        // LP price = (DONUT in LP * 2) / LP total supply
        uint256 lpTotalSupply = IERC20(state.auctionPaymentToken).totalSupply();
        uint256 donutInLP = IERC20(donut).balanceOf(state.auctionPaymentToken);
        state.auctionPaymentTokenPrice = lpTotalSupply == 0 ? 0 : (donutInLP * 2 * 1e18) / lpTotalSupply;

        // User state
        if (account != address(0)) {
            state.auctionPaymentTokenBalance = IERC20(state.auctionPaymentToken).balanceOf(account);
        }

        return state;
    }
}
