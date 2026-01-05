# DoughNation: Conceptual Overview

0) Identity
- DoughNation is a daily donation engine that turns charitable giving into newly issued DOUGH tokens for donors.
- It sits inside the Donut ecosystem by channeling outside assets toward approved charities while routing a fixed slice to the protocol’s treasury and a smaller slice to the team, aligning donations with DonutDAO’s broader store-of-value goals.
- GlazeCorp built and maintains the system; we operate the machinery and its defaults, while DonutDAO remains the protocol layer that benefits from the treasury share.

1) The core idea
- Picture a donation conveyor belt that empties once per day. Everyone places contribution boxes on the belt, chooses which approved charity receives half of each box, and the belt also diverts fixed portions to the treasury and team before resetting.
- When the belt stops at midnight (chain time), the day’s fixed pile of DOUGH becomes claimable and is split in proportion to what each credited donor placed on the belt.
- Key concepts:
  1. Daily donation pool: one shared bucket per day.
  2. Proportional DOUGH share: donors split a fixed daily issuance according to their share of that day’s bucket.
  3. Emission halving: the daily DOUGH pile shrinks by half every 30 days until it hits a hard floor.
  4. Approved destinations: donations only flow to pre-approved charities; treasury and team slices are automatic.
  5. Delegated actions: anyone can pay on someone else’s behalf, and anyone can trigger claims for a donor, but the DOUGH always goes to the credited account.
  6. Auxiliary auction: a separate Dutch sale periodically offloads any assets the system accumulates in exchange for LP tokens, with payments sent to a burn-style receiver.

2) Why this exists
- Problem: Direct donations rarely reward donors beyond goodwill, and protocol treasuries often rely on separate funding mechanisms.
- Prior approaches either ignore donor incentives or require complex yield strategies to fund rewards.
- Principle: keep it simple—tie giving to a predictable token drip, split donations transparently, and let donors keep custody of rewards without the protocol holding their money longer than needed.

3) The cast of characters
- Donors: want to support approved causes and receive DOUGH proportional to their credited giving; they risk donating to a day with little competition (they get more DOUGH) or lots of competition (they get less per unit donated).
- Charities: receive 50% of each donation directed to them; they rely on staying on the approved list.
- Treasury: receives 45% (or more when the team share is disabled) to reinforce DonutDAO’s reserves.
- Team: receives 5% by default; if set to an empty address, that slice rolls into the treasury.
- Auction buyers: spend LP tokens to scoop all assets sitting in the auction pool at a decaying price; they risk waiting too long and losing the purchase to someone else.
- GlazeCorp stewards: maintain the approved-charity list and the destination addresses for treasury and team.

4) The system loop
- Trigger: a donor (or a payer on their behalf) submits a donation and chooses an approved charity.
- Immediate change: funds are split instantly—half to the chosen charity, most of the rest to the treasury, and a small slice to the team (or treasury if disabled). The donor’s credited total for that day increases.
- Daily reset: time passes; when the day ends, that day’s DOUGH pile becomes claimable. Anyone can trigger the claim, but the credited donor receives the tokens.
- Repeat: a new day starts with the same rules; DOUGH issuance for the day follows the halving schedule until it reaches the permanent floor.

5) Incentives and value flow
- Payments: donors pay in the accepted payment token; 50% goes to the named charity, 45% to treasury, 5% to team (or 50% to treasury when the team slice is turned off).
- Earnings: donors receive DOUGH based on their share of that day’s total donations once the day closes. If they were the only donor, they get the entire day’s issuance.
- Auction flow: assets that accumulate in the auction pool are sold for LP tokens; the buyer’s LP tokens are sent to a designated receiver (commonly a burn address), and the buyer receives everything the pool held. The next auction round starts with a price derived from the last sale and constrained by minimums and maximums.
- Example splits: a 100-unit donation sends 50 units to charity, 45 to treasury, and 5 to team.

6) The rules of the system
- Allowed: donate any positive amount to an approved charity and credit any recipient account; trigger claims for yourself or someone else after the relevant day ends; burn your DOUGH if you want to shrink your own balance.
- Discouraged or impossible: donating zero, donating to unapproved addresses, claiming before a day ends, claiming twice for the same day and account, or changing the daily emission beyond the programmed halving and floor.
- Automated enforcement: time-based day boundaries, fixed percentage splits, proportional DOUGH calculations, and halving down to a hard minimum.
- Open choices: which approved charity to support, how much to give, whether to donate for yourself or someone else, whether to participate in the auction, and whether to burn received DOUGH.

7) A concrete walkthrough (with numbers)
- Morning: Alex donates 1,000 units on Day 0 to Charity A. Immediately, 500 go to Charity A, 450 to treasury, and 50 to team. Alex is credited with 1,000 units for Day 0.
- Afternoon: Bree donates 3,000 units to Charity B. Another 1,500 go to Charity B, 1,350 to treasury, and 150 to team. Bree is credited with 3,000 units for Day 0. The Day 0 total is now 4,000 units.
- Next day: Day 0 ends. Suppose Day 0’s DOUGH pile is 345,600 tokens. Alex has 25% of the pool and can claim 86,400 DOUGH; Bree has 75% and can claim 259,200 DOUGH. Anyone can trigger the claim for them, but the tokens land in their wallets. Day 1 begins with the same rules and a fresh pool.

8) What this solves (and what it does not)
- Solves: pairs charitable giving with clear, time-bound rewards; ensures charities, treasury, and team get paid immediately; gives donors predictable proportional rewards without lockups.
- Does not solve: choosing which charities are worthy (that depends on approvals); guaranteeing DOUGH’s future market value; preventing donation competition from reducing per-unit rewards; providing refunds once donated.
- This is NOT: a promise of future profits, an investment pool, or a guarantee that emissions will rise—emissions only decline on schedule until the floor.

9) Power, incentives, and trust
- Influence: the stewarding owner controls which charities are approved and where the treasury and team slices go; ownership can be renounced to freeze governance.
- Trust boundaries: donors trust the steward to manage the approved list responsibly and to keep treasury/team addresses appropriate; token math and time windows are enforced automatically.
- Incentive alignment: donors receive more DOUGH when they represent a larger share of a day’s giving; the treasury benefits whenever anyone donates; charities benefit directly and immediately.
- Human decisions remain in charity approvals and address updates; everything else follows the programmed rules.

10) What keeps this system honest
- Rewarded behaviors: donating to approved charities, claiming after the day ends, and participating in auctions when prices look favorable.
- Discouraged behaviors: trying to donate to unapproved addresses (rejected), claiming twice (blocked), or donating zero (rejected). Late-day donations simply earn their proportional share; there is no shortcut to more than your fraction.
- If people act selfishly: they still only receive DOUGH in proportion to their share of that day’s total. Splitting a donation into many transactions does not change the outcome.
- If participation slows or stops: charities still receive whatever is donated; the DOUGH pile for that day remains unminted until someone with a valid share claims, and no one can mint extra beyond the day’s emission.

11) FAQ
1. What do I get when I donate? — A proportional share of that day’s fixed DOUGH issuance, claimable after the day ends.
2. Where does my donation go? — Half to your chosen approved charity, most of the rest to the protocol treasury, and a small slice to the team (or treasury if the team slice is disabled).
3. Can I donate for someone else? — Yes. You can pay while crediting another account so they receive the DOUGH later.
4. Who can trigger the claim? — Anyone can trigger it, but the credited donor receives the DOUGH.
5. When does a “day” start and end? — The clock starts at deployment and advances in 24-hour blocks.
6. What if I’m the only donor that day? — You receive the entire day’s DOUGH pile.
7. What if no one donates that day? — There is nothing to claim because no one has a share of that day’s pool.
8. How fast does DOUGH issuance change? — It halves every 30 days until it reaches a permanent daily floor.
9. Can charities be added or removed? — Yes, by the steward; donations to non-approved addresses are blocked.
10. What if the team address is cleared? — The team slice rolls into the treasury, making the split 50/50 between charity and treasury.
11. What is the auction for? — It sells whatever assets have accumulated in its pool for LP tokens via a Dutch auction with a decaying price and restarts after each purchase.
12. Do I have to hold DOUGH? — No. You can transfer it, burn it, or keep it; its value depends on the market and future demand, which are not guaranteed.

12) Glossary
- DOUGH: The reward token issued to donors from each day’s pool; burnable by holders.
- Donation pool: The running total of all donations for a specific day.
- Daily emission: The fixed amount of DOUGH available to split for a given day.
- Halving period: Every 30 days, the daily DOUGH pile halves until it hits the floor.
- Emission floor: The minimum daily DOUGH pile that never decreases further.
- Approved charity: A destination address that can receive the 50% charity share.
- Treasury share: The portion of each donation that goes to the protocol treasury.
- Team share: The default 5% slice of each donation; can be redirected to the treasury by setting the team address to empty.
- Credited donor: The account recorded as eligible for a share of a day’s DOUGH, which may differ from the payer.
- Claim: The action of minting and receiving your DOUGH after a day ends.
- Day boundary: The 24-hour cutoff that separates each donation pool and enables claiming.
- Auction epoch: A sale window where the price starts high and linearly decays to zero until someone buys.
- Decaying price: A Dutch-auction price that falls over time within an epoch.
- Price multiplier: The factor that sets the next auction’s starting price based on the previous winning payment, bounded by minimums and maximums.
- LP token payment: The specific token used to pay for auction purchases; payments are sent to a designated receiver, commonly to reduce supply.
- Burn: Voluntarily destroying your DOUGH to shrink your own balance and total supply.
