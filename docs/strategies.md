# Strategies

Strategies are the contracts that determine action state.
In this section we will take a look at the different parameters and ways we can configure strategies and use them in various ways.
There are two main types of strategies, `relative` and `absolute`; first we will look at the parameters that they have in common and then look at some of their differences.

## View Functions and Action State

Strategies are composed of entirely view functions (minus the initialize function which acts as the constructor)
To view the state of an action, strategies should never be queried directly.
The `getActionState` method on `LlamaCore` is the only method that should be used for this purpose.

## Approval Period

The approval period is the length of time that policyholders can approve an action.
At action creation time, this number is added to the current `block.timestamp` to get the last timestamp that a policyholder can approve at.

Setting the approval period can be set to 0 in tandem with the `minApprovals` or `minApprovalPct` parameters (in absolute and relative strategies respectively) can be used to enable "Optimistic" strategies.

## Queuing Period

The queuing period is the inverse of the approval period and can also be thought of as the disapproval period
It defines the amount of time that policyholders are allowed to disapprove an action.
The queuing period can be disabled if set to 0, which would mean actions cannot be disapproved after they pass the approval period.
Setting the value of queuing period to 0 is also useful for instant execution strategies.

## Expiration Period

The expiration period is the length of time an action can be executed before it expires.It can be adjusted to suit the nature of the action and how time sensitive it is.
Some actions must be executed immediately, while others might not have strict timing requirements.
We advise you don't set this value to low, in general because it may make for a more difficult UX.

## Is Fixed Length Approval Period

A boolean value that determines if an action can be queued as soon as the action reaches the approval threshold, or if it users must wait the duration of the approval period before queuing the action.

## Approval / Disapproval Role

Each strategy has a single approval and disapproval role that enables policyholders with these roles to cast approvals and/or disapprovals.
The supplies or quantities of these roles are used to calculate quorums for certain strategies.

## Force Approval / Disapproval Roles

Each strategy can optionally have one or more "force roles", which when used cast an approval / disapproval that instantly approves or disapproves the action, regardless of quorum.
There are many use cases for force roles and it would be impossible to list them all here, but one we can imagine is an optimistic strategy, where a few team members can instantly disapprove an action using a force role if they did not approve of the action.

## Approval / Disapproval Thresholds

This is where `relative` and `absolute` strategies differ from one another.
Relative strategies use `minApprovalPct` and `minDisapprovalPct`, while absolute strategies use `minApprovals` and `minDisapprovals`
Both are just ways of specifying the threshold at which an action is approved is disapproved.
To learn more about the differences between strategies and how they calculate the thresholds, see the [strategy comarison](./strategy-comparison.md) docs.
