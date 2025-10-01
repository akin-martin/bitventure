# BitVenture - Decentralized Startup Investment Protocol

## Overview

**BitVenture** is a milestone-based fundraising protocol built on Bitcoin Layer 2 (Stacks). It bridges traditional venture capital practices with blockchain-native transparency, enabling **trustless startup fundraising** while ensuring **investor governance** and **capital accountability**.

Startups raise funds by defining **milestones** tied to their funding goals. Investors contribute STX in exchange for **equity tokens**, which determine their **voting power** in milestone approval. Funds are released only when milestones achieve **majority approval**, reducing investment risks and aligning incentives between founders and investors.

The protocol incorporates **automated equity distribution**, **portfolio tracking**, **real-time campaign analytics**, and **emergency safeguards** to ensure a robust and secure investment ecosystem.

---

## Key Features

* **Milestone-Based Fundraising**
  Funds are distributed only upon majority investor approval of completed milestones.

* **Equity-Weighted Voting**
  Investors vote on milestone completion based on proportional equity tokens.

* **Trustless Governance**
  Transparent rules for campaign creation, investments, voting, and fund distribution.

* **Automated Portfolio Tracking**
  Each investor maintains an aggregated view of investments, returns, and active campaigns.

* **Platform Revenue Model**
  Protocol charges a configurable platform fee (default 2.5%) on every investment.

* **Emergency Controls**
  Admin controls for pausing the protocol, force-closing campaigns, or overriding milestones.

---

## System Overview

The protocol lifecycle is organized into **three major phases**:

1. **Campaign Creation**

   * Founders deploy campaigns with a funding goal, deadline, and milestone count.
   * Campaign metadata includes title, description, and duration.

2. **Investment & Equity Allocation**

   * Investors contribute STX to active campaigns before the deadline.
   * Platform fees are automatically deducted.
   * Investors receive **equity tokens** proportional to their contribution.

3. **Milestone Governance**

   * Founders create milestones tied to funding percentages.
   * Investors vote to approve/reject milestones before deadlines.
   * On approval, funds are released to the founder.
   * On rejection, funds remain locked, mitigating misuse.

---

## Contract Architecture

### State Variables

* **Platform Management**

  * `platform-fee-percentage`: Fee applied on all contributions.
  * `total-platform-fees`: Accumulated fees awaiting withdrawal.
  * `paused`: Emergency pause toggle.

* **Campaign Tracking**

  * `total-campaigns`: Global counter for campaign IDs.
  * `campaigns`: Core campaign metadata and lifecycle flags.
  * `campaign-stats`: Aggregated metrics (investors, averages, last update).

* **Investor Portfolios**

  * `investor-portfolios`: Aggregated portfolio stats per investor.
  * `campaign-investments`: Per-campaign investor contributions + equity.

* **Milestones & Governance**

  * `campaign-milestones`: Milestone definitions, votes, and fund release flags.
  * `milestone-votes`: Investor votes with timestamp and voting power.

---

## Data Flow (High-Level)

1. **Campaign Initialization**

   * Founder calls `create-campaign` → campaign entry stored in `campaigns`.

2. **Investor Participation**

   * Investor calls `invest-in-campaign`.
   * STX transferred to founder + platform fee.
   * Investor’s portfolio updated with equity tokens.

3. **Milestone Creation**

   * Founder calls `create-milestone`.
   * Milestone parameters (funding %, voting duration) stored.

4. **Voting Process**

   * Investors cast vote via `vote-on-milestone`.
   * Vote weights are based on equity tokens.
   * Tallies (`votes-for`, `votes-against`) updated in `campaign-milestones`.

5. **Milestone Completion**

   * Founder calls `complete-milestone`.
   * Approval rate ≥ 51% required.
   * Funds released to founder.

6. **Emergency Intervention**

   * Protocol owner can `emergency-close-campaign` or `force-milestone-completion`.

---

## Error Handling

| Error Code | Meaning                 |
| ---------- | ----------------------- |
| `u100`     | Owner-only function     |
| `u101`     | Not authorized          |
| `u102`     | Campaign not found      |
| `u103`     | Campaign ended          |
| `u104`     | Insufficient funds      |
| `u105`     | Invalid parameter       |
| `u106`     | Milestone not found     |
| `u107`     | Already voted           |
| `u108`     | Voting period ended     |
| `u109`     | Milestone not completed |

---

## Administrative Functions

* `set-platform-fee` – Update fee percentage (max 10%).
* `toggle-pause` – Pause/unpause protocol globally.
* `withdraw-platform-fees` – Withdraw accumulated platform fees.
* `emergency-close-campaign` – Force close a campaign.
* `force-milestone-completion` – Override milestone status.

---

## Future Extensions

* NFT-based equity representation for secondary trading.
* DAO-driven dispute resolution mechanisms.
* Multi-asset support (beyond STX).
* Layered governance (tiered investor councils).

---

## Conclusion

BitVenture establishes a **secure, transparent, and accountable fundraising infrastructure** for startups and investors on Bitcoin Layer 2. By combining milestone-based funding, equity governance, and emergency safeguards, it lays the foundation for a **decentralized venture capital ecosystem** where trust is enforced by code, not intermediaries.
