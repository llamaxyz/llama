# Strategies

Strategies are the contracts that determine action state.
In this section we will take a look at the different parameters and ways we can configure strategies and use them in various ways.
There are two categories of strategies provided by Llama, `relative` and `absolute`. First we will look at the parameters that they have in common, then look at some of their differences.

## View Functions and Action State

Strategies are composed of entirely view functions (besides the initialize function which acts as the constructor).
To view the state of an action, strategies should never be queried directly since the state returned by the strategy functions in isolation can be out of date.
The `getActionState` method on `LlamaCore` is the only method that should be used for this purpose.

## Strategy Parameters

### `approvalPeriod`

The approval period is the length of time that policyholders can approve an action.
At action creation time, this number is added to the current `block.timestamp` to get the last timestamp that a policyholder can approve at.

Setting the approval period to 0 in tandem with the `minApprovals` or `minApprovalPct` parameters (in absolute and relative strategies respectively) can be used to enable "Optimistic" strategies that are automatically approved.

### `queuingPeriod`

The queuing period is the inverse of the approval period and can also be thought of as the disapproval period.
It defines the amount of time that policyholders have to disapprove an action.
The queuing period can be disabled if set to 0, which would mean actions cannot be disapproved after they pass the approval period.
Setting the queuing period to 0 enables immediate execution after the approval period.

### `expirationPeriod`

The expiration period is the length of time an action has to be executed before it expires. It can be adjusted to suit the nature of the action and how time sensitive it is.
Some actions must be executed immediately, while others might not have strict timing requirements.
Setting this value too low can make for a more difficult UX, and setting the value too high means stale actions that have been forgotten about may be suddenly executed.

### `isFixedLengthApprovalPeriod`

A boolean value that determines if an action can be queued as soon as the action reaches the approval threshold, or if it users must wait the duration of the approval period before queuing the action.

Setting this to false is useful for scenarios where it's ok to queue an action as soon as the approval quorum is met.

### `approvalRole` / `disapprovalRole`

Each strategy has a single approval and disapproval role that enables policyholders with these roles to cast approvals and/or disapprovals.
The supplies or quantities of these roles are used to calculate quorums for certain strategies.

### `forceApprovalRoles` / `forceDisapprovalRoles`

Each strategy can optionally have one or more "force roles", which can cast an approval or disapproval that instantly approves or disapproves the action, regardless of quorum.
An example use case for force roles is a grants committee that leverages an optimistic strategy to allow anyone to propose small transfers of value without an approval period, which gets queued for the grants committee to veto. In this scenario each policyholder with the grants committee role can instantly disapprove an action using their force role; this allows for much faster and iterative approach to governance.

### Approval / Disapproval Thresholds

Relative and absolute strategies differ in the way they determine if an action has been approved or disapproved.
Relative strategies use `minApprovalPct` and `minDisapprovalPct` to define the quantity needed as percentage, while absolute strategies use `minApprovals` and `minDisapprovals` to define the quantity needed as a concrete value.
To learn more about the differences between strategies and how they calculate the thresholds, see the [strategy comparison](https://github.com/llamaxyz/llama/blob/main/docs/strategies.md#comparison-table) docs.

## Strategy Comparison

Below is a table comparing the key features of the strategy logic contracts.

### Definitions

- **Threshold:** `Relative` if the (dis)approval threshold is a relative percentage of the supply and `Absolute` if it's an absolute value.
- **Supply:** This only matters for relative strategies. It is the number that the minimum percentage is multiplied by to arrive at the threshold. This can be the total quantity of the (dis)approval role at action creation or the total number of role holders at action creation.
- **Policyholder weight:** The weight of an eligible policyholder's cast. This is either hardcoded to 1 or the policyholder's role quantity.

## Comparison Table

| Name                                 | Threshold | Action creator can cast? | Policyholder weight | Supply              |
| ------------------------------------ | --------- | ------------------------ | ------------------- | ------------------- |
| LlamaRelativeQuantityQuorum          | Relative  | ✅                        | Role quantity       | Total role quantity |
| LlamaRelativeHolderQuorum            | Relative  | ✅                        | Role quantity       | Total role holders  |
| LlamaRelativeUniqueHolderQuorum      | Relative  | ✅                        | 1                   | Total role holders  |
| LlamaAbsoluteQuorum                  | Absolute  | ✅                        | Role quantity       | —                   |
| LlamaAbsolutePeerReview              | Absolute  | ❌                        | Role quantity       | —                   |
