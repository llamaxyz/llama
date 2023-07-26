# Strategies

Strateies are the contracts that determine action state.
In this section we will take a look at the different parameters and ways we can configure strategies and use them in various ways.
There are two main types of strategies, `relative` and `absolute`; first we will look at the parameters that they have in common and then look at some of their differences.

## Approval Period

The approval period is the length of time that policyholders can approve an action. At action creation time, this number is added to the current `block.timestamp` to get the last timestamp that a policyholder can approve at.

Setting the approval period can be set to 0 in tandem with the `minApprovals` or `minApprovalPct` parameters (in absolute and relative strategies respectively) can be used to enable "Optimistic" strategies.

## Queuing Period

The queuing period is the inverse of the approval period and can also be thought of as the disapproval period. It defines the amount of time that policyholders are allowed to disapprove an action. The queuing period can be disabled if set to 0, which would mean actions cannot be disapproved after they pass the approval period. Setting the value of queuing period to 0 is also useful for instant execution strategies.

## Expiration Period

The expiration period is the length of time an action can be executed before it expires. It can be adjusted to suit the nature of the action and how time sensitive it is. Some actions must be executed immediately, while others might not have strict timing requirements. We advise you don't set this value to low, in general because it may make for a more difficult UX.

 uint64 approvalPeriod; // The length of time of the approval period.
    uint64 queuingPeriod; // The length of time of the queuing period. The disapproval period is the queuing period when
      // enabled.
    uint64 expirationPeriod; // The length of time an action can be executed before it expires.
    uint16 minApprovalPct; // Minimum percentage of total approval quantity / total approval supply.
    uint16 minDisapprovalPct; // Minimum percentage of total disapproval quantity / total disapproval supply.
    bool isFixedLengthApprovalPeriod; // Determines if an action be queued before approvalEndTime.
    uint8 approvalRole; // Anyone with this role can cast approval of an action.
    uint8 disapprovalRole; // Anyone with this role can cast disapproval of an action.
    uint8[] forceApprovalRoles; // Anyone with this role can single-handedly approve an action.
    uint8[] forceDisapprovalRoles; // Anyone with th

      struct Config {
    uint64 approvalPeriod; // The length of time of the approval period.
    uint64 queuingPeriod; // The length of time of the queuing period. The disapproval period is the queuing period when
      // enabled.
    uint64 expirationPeriod; // The length of time an action can be executed before it expires.
    uint96 minApprovals; // Minimum number of total approval quantity.
    uint96 minDisapprovals; // Minimum number of total disapproval quantity.
    bool isFixedLengthApprovalPeriod; // Determines if an action be queued before approvalEndTime.
    uint8 approvalRole; // Anyone with this role can cast approval of an action.
    uint8 disapprovalRole; // Anyone with this role can cast disapproval of an action.
    uint8[] forceApprovalRoles; // Anyone with this role can single-handedly approve an action.
    uint8[] forceDisapprovalRoles; // Anyone with this role can single-handedly disapprove an action.
  }
