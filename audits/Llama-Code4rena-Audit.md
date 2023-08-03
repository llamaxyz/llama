---
sponsor: "Llama"
slug: "2023-06-llama"
date: "2023-07-⭕⭕"  # the date this report is published to the C4 website
title: "Llama"
findings: "https://github.com/code-423n4/2023-06-llama-findings/issues"
contest: 246
---

# Overview

## About C4

Code4rena (C4) is an open organization consisting of security researchers, auditors, developers, and individuals with domain expertise in smart contracts.

A C4 audit is an event in which community participants, referred to as Wardens, review, audit, or analyze smart contract logic in exchange for a bounty provided by sponsoring projects.

During the audit outlined in this document, C4 conducted an analysis of the Llama smart contract system written in Solidity. The audit took place between June 6—June 14 2023.

## Wardens

 50 wardens contributed reports to the Llama Audit:

  1. 0xHati
  2. [0xSmartContract](https://twitter.com/0xSmartContract)
  3. 0xcm
  4. [0xnev](https://twitter.com/0xnevi)
  5. Atree
  6. BLOS
  7. BRONZEDISC
  8. [Co0nan](https://twitter.com/Conan0x3)
  9. DavidGiladi
  10. Go-Langer
  11. [JCN](https://twitter.com/0xJCN)
  12. [K42](https://twitter.com/CrystAlline_K42)
  13. Madalad
  14. MiniGlome
  15. [QiuhaoLi](https://twitter.com/QiuhaoLi)
  16. Rageur
  17. Raihan
  18. [Rolezn](https://twitter.com/Rolezn)
  19. SAAJ
  20. SAQ
  21. SM3\_SS
  22. [Sathish9098](https://www.linkedin.com/in/sathishkumar-p-26069915a)
  23. T1MOH
  24. [Toshii](https://twitter.com/0xToshii)
  25. [Udsen](https://github.com/udsene)
  26. VictoryGod
  27. [auditor0517](https://twitter.com/auditor0517)
  28. [dirk\_y](https://twitter.com/iamdirky)
  29. ernestognw
  30. flacko
  31. [hunter\_w3b](https://twitter.com/hunt3r_w3b)
  32. [joestakey](https://twitter.com/JoeStakey)
  33. ktg
  34. kutugu
  35. libratus
  36. lsaudit
  37. [mahdirostami](http://www.linkedin.com/in/mahdirostami)
  38. matrix\_0wl
  39. [minhquanym](https://www.linkedin.com/in/minhquanym/)
  40. [n1punp](https://twitter.com/n1punp)
  41. [naman1778](https://www.linkedin.com/in/naman-agrawal1778/)
  42. neko\_nyaa
  43. peanuts
  44. petrichor
  45. qpzm
  46. rvierdiiev
  47. sces60107
  48. sebghatullah
  49. shamsulhaq123
  50. xuwinnie

This audit was judged by [gzeon](https://twitter.com/gzeon).

Final report assembled by PaperParachute.

# Summary

The C4 analysis yielded an aggregated total of 5 unique vulnerabilities. Of these vulnerabilities, 2 received a risk rating in the category of HIGH severity and 3 received a risk rating in the category of MEDIUM severity.

Additionally, C4 analysis included 13 reports detailing issues with a risk rating of LOW severity or non-critical. There were also 17 reports recommending gas optimizations.

All of the issues presented here are linked back to their original finding.

# Scope

The code under review can be found within the [C4 Llama repository](https://github.com/code-423n4/2023-06-llama), and is composed of 23 smart contracts written in the Solidity programming language and includes 2096 lines of Solidity code.

# Severity Criteria

C4 assesses the severity of disclosed vulnerabilities based on three primary risk categories: high, medium, and low/non-critical.

High-level considerations for vulnerabilities span the following key areas when conducting assessments:

- Malicious Input Handling
- Escalation of privileges
- Arithmetic
- Gas use

For more information regarding the severity criteria referenced throughout the submission review process, please refer to the documentation provided on [the C4 website](https://code4rena.com), specifically our section on [Severity Categorization](https://docs.code4rena.com/awarding/judging-criteria/severity-categorization).

# High Risk Findings (2)
## [[H-01] In `LlamaRelativeQuorum`, the governance result might be incorrect as it counts the wrong approval/disapproval](https://github.com/code-423n4/2023-06-llama-findings/issues/203)
*Submitted by [auditor0517](https://github.com/code-423n4/2023-06-llama-findings/issues/203), also found by [Toshii](https://github.com/code-423n4/2023-06-llama-findings/issues/135), [kutugu](https://github.com/code-423n4/2023-06-llama-findings/issues/115), [0xnev](https://github.com/code-423n4/2023-06-llama-findings/issues/47), and [T1MOH](https://github.com/code-423n4/2023-06-llama-findings/issues/33)*

<https://github.com/code-423n4/2023-06-llama/blob/9d641b32e3f4092cc81dbac7b1c451c695e78983/src/strategies/LlamaRelativeQuorum.sol#L223> <br><https://github.com/code-423n4/2023-06-llama/blob/9d641b32e3f4092cc81dbac7b1c451c695e78983/src/strategies/LlamaRelativeQuorum.sol#L242>

### Proof of Concept

The `LlamaRelativeQuorum` uses approval/disapproval thresholds that are specified as percentages of total supply and the approval/disapproval supplies are set at `validateActionCreation()` during the action creation.

```solidity
  function validateActionCreation(ActionInfo calldata actionInfo) external {
    LlamaPolicy llamaPolicy = policy; // Reduce SLOADs.
    uint256 approvalPolicySupply = llamaPolicy.getRoleSupplyAsNumberOfHolders(approvalRole);
    if (approvalPolicySupply == 0) revert RoleHasZeroSupply(approvalRole);

    uint256 disapprovalPolicySupply = llamaPolicy.getRoleSupplyAsNumberOfHolders(disapprovalRole);
    if (disapprovalPolicySupply == 0) revert RoleHasZeroSupply(disapprovalRole);

    // Save off the supplies to use for checking quorum.
    actionApprovalSupply[actionInfo.id] = approvalPolicySupply;
    actionDisapprovalSupply[actionInfo.id] = disapprovalPolicySupply;
  }
```

As we can see, `actionApprovalSupply` and `actionDisapprovalSupply` are set using `getRoleSupplyAsNumberOfHolders` which means the total number of role holders.

But while counting for `totalApprovals/totalDisapprovals` in `getApprovalQuantityAt()/getDisapprovalQuantityAt()`, it adds the quantity instead of role holders(1 for each holder).

```solidity
function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint128) {
    if (role != approvalRole && !forceApprovalRole[role]) return 0;
    uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    return quantity > 0 && forceApprovalRole[role] ? type(uint128).max : quantity; //@audit should return supply, not quantity
}
```

So the governance result would be wrong with the below example.

1.  There are 3 role holders(Alice, Bob, Charlie) and Alice has 2 quantities, others have 1.
2.  During the action creation with the `LlamaRelativeQuorum` strategy, `actionApprovalSupply = 3` and there should be 2 approved holders at least when `minApprovalPct = 51%`.
3.  But if Alice approves the action, the result of `getApprovalQuantityAt()` will be 2 and the action will be approved with only one approval.

It's because `getApprovalQuantityAt()` return the quantity although `actionApprovalSupply` equals `NumberOfHolders`.

### Recommended Mitigation Steps

`getApprovalQuantityAt()` and `getDisapprovalQuantityAt()` should return 1 instead of `quantity` for the positive quantity.

I think we can modify these functions like below.

```solidity
  function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint128) {
    if (role != approvalRole && !forceApprovalRole[role]) return 0;
    uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    
    if (quantity > 1) quantity = 1;

    return quantity > 0 && forceApprovalRole[role] ? type(uint128).max : quantity;
  }

  function getDisapprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp)
    external
    view
    returns (uint128)
  {
    if (role != disapprovalRole && !forceDisapprovalRole[role]) return 0;
    uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);

    if (quantity > 1) quantity = 1;

    return quantity > 0 && forceDisapprovalRole[role] ? type(uint128).max : quantity;
  }
```

**[AustinGreen (Llama) disputed and commented](https://github.com/code-423n4/2023-06-llama-findings/issues/203#issuecomment-1601169669):**
 > This is actually how we intend this strategy to work but we're open to feedback! Here's an example:
> 
> - An instance has 10 role holders and a 50% min approval percentage. Each role holder's quantity is 1, so 5 role holders can approve this action.
> - 2 of the role holders have their quantity increased to 2.
> - This means that if each of these role holders cast approvals, then their approval power will count as 4. That means just one other role holder is needed to cast approval to approve the action.
> 
> In this system quantity can be used to provide granular approval weights to role holders.

**[gzeon (Judge) commented](https://github.com/code-423n4/2023-06-llama-findings/issues/203#issuecomment-1616683309):**
> @AustinGreen- I don't think this make sense. Sure, if each holder's quantity is 1, then `getRoleSupply` is same as `getRoleSupplyAsNumberOfHolders` and what you said is valid. However, if you have 10 holders each with quantity 10 at snapshot, then your `actionApprovalSupply` is set to 10 (number of holder) and any of their approval (10 quantity) would hit quorum.

**[AustinGreen (Llama) commented](https://github.com/code-423n4/2023-06-llama-findings/issues/203#issuecomment-1616796649):**
> @gzeon- Yes that’s exactly how the design is intended to work!

**[gzeon (Judge) commented](https://github.com/code-423n4/2023-06-llama-findings/issues/203#issuecomment-1617278035):**
> @AustinGreen- This sounds weird, is this design documented anywhere? From what I can see in the code comments it seems to be hard for anyone (including potential user/dao) to understand such logic. 
> 
> In the code, there is a comment
> >  Minimum percentage of `totalApprovalQuantity / totalApprovalSupplyAtCreationTime` required for the action to be queued
> 
> I think it is fair for one to assume `totalApprovalQuantity` and `totalApprovalSupplyAtCreationTime` would be using the same metric, instead of one using the raw count and the other using `AsNumberOfHolders`.

**[AustinGreen (Llama) commented](https://github.com/code-423n4/2023-06-llama-findings/issues/203):**
>Although this is the intended design for this strategy, we decided to create an additional strategy that Llama instances can adopt that follows the warden's recommendations. It uses total (dis)approval quantity for the quorum calculation as specified.

***
## [[H-02] Anyone can change approval/disapproval threshold for any action using LlamaRelativeQuorum strategy](https://github.com/code-423n4/2023-06-llama-findings/issues/62)
*Submitted by [ktg](https://github.com/code-423n4/2023-06-llama-findings/issues/62), also found by [auditor0517](https://github.com/code-423n4/2023-06-llama-findings/issues/201) and [dirk\_y](https://github.com/code-423n4/2023-06-llama-findings/issues/195)*

### Proof of Concept

When a new action is created with `LlamaRelativeQuorum` strategy, `LlamaCore` will call function `validateActionCreation` which is currently implemented as below:

    function validateActionCreation(ActionInfo calldata actionInfo) external {
        LlamaPolicy llamaPolicy = policy; // Reduce SLOADs.
        uint256 approvalPolicySupply = llamaPolicy.getRoleSupplyAsNumberOfHolders(approvalRole);
        if (approvalPolicySupply == 0) revert RoleHasZeroSupply(approvalRole);

        uint256 disapprovalPolicySupply = llamaPolicy.getRoleSupplyAsNumberOfHolders(disapprovalRole);
        if (disapprovalPolicySupply == 0) revert RoleHasZeroSupply(disapprovalRole);

        // Save off the supplies to use for checking quorum.
        actionApprovalSupply[actionInfo.id] = approvalPolicySupply;
        actionDisapprovalSupply[actionInfo.id] = disapprovalPolicySupply;
      }

The last 2 lines of code is to `Save off the supplies to use for checking quorum`. The 2 variables `actionApprovalSupply` and `actionDisapprovalSupply` are described as `Mapping of action ID to the supply of the approval/disapproval role at the time the action was created.`

This means the strategy will save the total supply of approval/disapproval role at creation time and then use them to calculate the approval/disapproval threshold, which equals to (approval/disapproval percentage) &ast; (total supply of approval/disapproval).

However, since the function `validateActionCreation`'s scope is `external` and does not require any privilege to be called, any user can call this function and update the total supply of approval/disapproval role to the current timestamp and break the intention to keep total supply of approval/disapproval role `at the time the action was created`. This issue is highly critical because many Llama protocol's functions depend on these 2 variables to function as intended.

For example, if the total supply of approval role is 10 at the creation of action and the `minApprovalPct` = 100% - which means requires all policy holders to approve the action to pass it.

If it then be casted 9 votes (1 vote short), the action's state is still Active (not approved yet).

However, if 1 user is revoked their approval/role, anyone can call function `validateActionCreation` and update the required threshold to 9 votes and thus the action's state becomes Approved.

Below is a POC for the above example, for ease of testing, place this test case under file `LlamaStrategy.t.sol`, contract `IsActionApproved`:

    function testAnyoneCanChangeActionApprovalSupply() public {
        // Deploy a relative quorum strategy
        uint256 numberOfHolders = 10;

        // Assign 10 users role of TestRole1
        for (uint256 i=0; i< numberOfHolders; i++){
          address _policyHolder = address(uint160(i + 100));
          if (mpPolicy.balanceOf(_policyHolder) == 0) {
            vm.prank(address(mpExecutor));
            mpPolicy.setRoleHolder(uint8(Roles.TestRole1), _policyHolder, 1, type(uint64).max);
          }
        }


        // Create  a LlamaRelativeQuorum strategy
        // in this minApprovalPct = 10_000 (meaning we require all 10 policyholders to approve)
        LlamaRelativeQuorum.Config memory testStrategyData = LlamaRelativeQuorum.Config({
          approvalPeriod: 2 days,
          queuingPeriod: 2 days,
          expirationPeriod: 8 days,
          isFixedLengthApprovalPeriod: true,
          minApprovalPct: 10000, // require all policyholder to approve
          minDisapprovalPct: 2000,
          approvalRole: uint8(Roles.TestRole1),
          disapprovalRole: uint8(Roles.TestRole1),
          forceApprovalRoles: new uint8[](0),
          forceDisapprovalRoles: new uint8[](0)
        });

        ILlamaStrategy testStrategy = lens.computeLlamaStrategyAddress(
          address(relativeQuorumLogic), DeployUtils.encodeStrategy(testStrategyData), address(mpCore)
        );

        LlamaRelativeQuorum.Config[] memory testStrategies
        = new LlamaRelativeQuorum.Config[](1);
        testStrategies[0] = testStrategyData;
        vm.prank(address(mpExecutor));
        mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(testStrategies));

        // create action
        ActionInfo memory actionInfo = createAction(testStrategy);
        assertEq(LlamaRelativeQuorum(address(testStrategy)).actionApprovalSupply(actionInfo.id), numberOfHolders);

        // Suppose that 9 policyholder approve
        // the action lacks 1 more approval vote so isActionApproved = false
        approveAction(9, actionInfo);
        assertEq(LlamaRelativeQuorum(address(testStrategy)).isActionApproved(actionInfo), false);

        // Revoke 1 user
        vm.prank(address(mpExecutor));
        mpPolicy.revokePolicy(address(100));

        // Now anyone can update the actionApprovalSupply and therefore
        // change the approval threshold
        address anyOne = address(12345);
        vm.prank(anyOne);
        LlamaRelativeQuorum(address(testStrategy)).validateActionCreation(actionInfo);

        // The actionApproval for the above action is reduced to 9
        // and the action state changes to approved
        assertEq(LlamaRelativeQuorum(address(testStrategy)).actionApprovalSupply(actionInfo.id), numberOfHolders - 1);
        assertEq(LlamaRelativeQuorum(address(testStrategy)).isActionApproved(actionInfo), true);
      }


### Recommended Mitigation Steps

Since the intention is to keep values `actionApprovalSupply` and `actionDisapprovalSupply` snapshot at creation time for every action and `LlamaCore` only call `validateActionCreation` at creation time, I think the easiest way is to allow only `llamaCore` to call this function.


**[AustinGreen (Llama) confirmed and commented](https://github.com/code-423n4/2023-06-llama-findings/issues/62#issuecomment-1601259723):**
 > This finding was addressed in this PR: https://github.com/llamaxyz/llama/pull/384 (note our repo is private until we launch)


***
 
# Medium Risk Findings (3)
## [[M-01] It is not possible to execute actions that require ETH (or other protocol token)](https://github.com/code-423n4/2023-06-llama-findings/issues/247)
*Submitted by [libratus](https://github.com/code-423n4/2023-06-llama-findings/issues/247), also found by [Udsen](https://github.com/code-423n4/2023-06-llama-findings/issues/296), [flacko](https://github.com/code-423n4/2023-06-llama-findings/issues/283), [joestakey](https://github.com/code-423n4/2023-06-llama-findings/issues/255), [n1punp](https://github.com/code-423n4/2023-06-llama-findings/issues/215), [Go-Langer](https://github.com/code-423n4/2023-06-llama-findings/issues/189), [QiuhaoLi](https://github.com/code-423n4/2023-06-llama-findings/issues/176), [sces60107](https://github.com/code-423n4/2023-06-llama-findings/issues/172), [Toshii](https://github.com/code-423n4/2023-06-llama-findings/issues/136), [rvierdiiev](https://github.com/code-423n4/2023-06-llama-findings/issues/118), [minhquanym](https://github.com/code-423n4/2023-06-llama-findings/issues/105), [Madalad](https://github.com/code-423n4/2023-06-llama-findings/issues/78), [BRONZEDISC](https://github.com/code-423n4/2023-06-llama-findings/issues/73), [0xcm](https://github.com/code-423n4/2023-06-llama-findings/issues/63), [ernestognw](https://github.com/code-423n4/2023-06-llama-findings/issues/57), [Co0nan](https://github.com/code-423n4/2023-06-llama-findings/issues/48), [T1MOH](https://github.com/code-423n4/2023-06-llama-findings/issues/30), and [MiniGlome](https://github.com/code-423n4/2023-06-llama-findings/issues/19)*

<https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L334> <br><https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaExecutor.sol#L29>

Actions can have value attached to them. That means when action is being executed, a certain amount of ETH (or other protocol token) need to be sent by the caller with the contract call. This is why `LlamaCore.executeAction` is payable.

```solidity
  function executeAction(ActionInfo calldata actionInfo) external payable {
```

However, when LlamaCore executes the action it doesn't pass value to the downstream call to LlamaExecutor

```solidity
    // Execute action.
    (bool success, bytes memory result) =
      executor.execute(actionInfo.target, actionInfo.value, action.isScript, actionInfo.data);
```

LlamaExecutor's `execute` is not payable even though it does try to pass value to the downstream call

```solidity
  function execute(address target, uint256 value, bool isScript, bytes calldata data)
    external
    returns (bool success, bytes memory result)
  {
    if (msg.sender != LLAMA_CORE) revert OnlyLlamaCore();
    (success, result) = isScript ? target.delegatecall(data) : target.call{value: value}(data);
  }
```

This will of course revert because LlamaExecutor is not expected to have any ETH balance.

### Proof of Concept

To reproduce the issue based on the existing tests we can do the following changes:

```diff
diff --git a/test/LlamaCore.t.sol b/test/LlamaCore.t.sol
index 8135c93..6964846 100644
--- a/test/LlamaCore.t.sol
+++ b/test/LlamaCore.t.sol
@@ -77,9 +77,9 @@ contract LlamaCoreTest is LlamaTestSetup, LlamaCoreSigUtils {
   function _createAction() public returns (ActionInfo memory actionInfo) {
     bytes memory data = abi.encodeCall(MockProtocol.pause, (true));
     vm.prank(actionCreatorAaron);
-    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, "");
+    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 1, data, "");
     actionInfo =
-      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data);
+      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 1, data);
     vm.warp(block.timestamp + 1);
   }
 
@@ -107,7 +107,7 @@ contract LlamaCoreTest is LlamaTestSetup, LlamaCoreSigUtils {
   function _executeAction(ActionInfo memory actionInfo) public {
     vm.expectEmit();
     emit ActionExecuted(actionInfo.id, address(this), actionInfo.strategy, actionInfo.creator, bytes(""));
-    mpCore.executeAction(actionInfo);
+    mpCore.executeAction{value: actionInfo.value}(actionInfo);
 
     Action memory action = mpCore.getAction(actionInfo.id);
     assertEq(action.executed, true);

diff --git a/test/mock/MockProtocol.sol b/test/mock/MockProtocol.sol
index 1636808..f6b0e0f 100644
--- a/test/mock/MockProtocol.sol
+++ b/test/mock/MockProtocol.sol
@@ -21,7 +21,7 @@ contract MockProtocol {
     return msg.value;
   }
 
-  function pause(bool isPaused) external onlyOwner {
+  function pause(bool isPaused) external payable onlyOwner {
     paused = isPaused;
   }
```

Now we can run any test that executes this action, for example:<br>
`forge test -m test_RevertIf_ActionExecuted`

The test fails with "EvmError: OutOfFund".

### Recommended Mitigation Steps

It seems like an important part of protocol functionality that is not working, therefore suggested **High** severity.

The fix is straightforward, making LlamaExecutor.execute payable and passing value in LlamaCore:

```diff
diff --git a/src/LlamaCore.sol b/src/LlamaCore.sol
index 89d60de..05f1755 100644
--- a/src/LlamaCore.sol
+++ b/src/LlamaCore.sol
@@ -331,7 +331,7 @@ contract LlamaCore is Initializable {
 
     // Execute action.
     (bool success, bytes memory result) =
-      executor.execute(actionInfo.target, actionInfo.value, action.isScript, actionInfo.data);
+      executor.execute{value: msg.value}(actionInfo.target, actionInfo.value, action.isScript, actionInfo.data);
 
     if (!success) revert FailedActionExecution(result);
 
diff --git a/src/LlamaExecutor.sol b/src/LlamaExecutor.sol
index f92ebc0..fe7127e 100644
--- a/src/LlamaExecutor.sol
+++ b/src/LlamaExecutor.sol
@@ -28,6 +28,7 @@ contract LlamaExecutor {
   /// @return result The data returned by the function being called.
   function execute(address target, uint256 value, bool isScript, bytes calldata data)
     external
+    payable
     returns (bool success, bytes memory result)
   {
     if (msg.sender != LLAMA_CORE) revert OnlyLlamaCore();
```

**[AustinGreen (Llama) confirmed and commented](https://github.com/code-423n4/2023-06-llama-findings/issues/247#issuecomment-1601098574):**
 > This was resolved in this PR: https://github.com/llamaxyz/llama/pull/367 (note repo is currently private but will be made public before launch)

**[gzeon (Judge) reduced severity to Medium and commented](https://github.com/code-423n4/2023-06-llama-findings/issues/247#issuecomment-1616583612):**
 > Valid issue, actions that require the executor to forward a call value would not work. However, fund is secure and not stuck since this does not impact the functionality of `LlamaAccount.transferNativeToken` which take the amount from calldata.



***

## [[M-02] User with disapproval role can gas grief the action executor](https://github.com/code-423n4/2023-06-llama-findings/issues/223)
*Submitted by [dirk\_y](https://github.com/code-423n4/2023-06-llama-findings/issues/223), also found by [rvierdiiev](https://github.com/code-423n4/2023-06-llama-findings/issues/80)*

Because disapprovals can be cast after the minimum queue time has expired (i.e. the action is now executable), a user with the disapproval role can frontrun any execute calls to push the action into the disapproved state and cause the execute call to fail, hence gas griefing the execute caller. This is particularly easy to achieve if a user has a force disapproval role.

### Proof of Concept

During calls to `castDisapproval` there is a call to `_preCastAssertions` which checks that the action is in a queued state. The purpose of this check is to ensure that disapprovals can only be cast after the action was first approved and then queued for execution.

However, the issue is that the action remains in the queue state even after the `minExecutionTime` has been passed. The result is that a malicious user can disapprove an action once it is ready to execute.

Below is a diff to the existing test suite that shows how an action that is ready to be executed could be disapproved just before execution. This isn't demonstrated with a force disapproval role, but that case would be the most harmful in terms of gas griefing.

    diff --git a/test/LlamaCore.t.sol b/test/LlamaCore.t.sol
    index 8135c93..34fd630 100644
    --- a/test/LlamaCore.t.sol
    +++ b/test/LlamaCore.t.sol
    @@ -1015,8 +1015,12 @@ contract ExecuteAction is LlamaCoreTest {
         mpCore.queueAction(actionInfo);
         vm.warp(block.timestamp + 6 days);
     
    -    vm.expectEmit();
    -    emit ActionExecuted(0, address(this), mpStrategy1, actionCreatorAaron, bytes(""));
    +    vm.prank(disapproverDave);
    +    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");
    +    vm.prank(disapproverDrake);
    +    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");
    +
    +    vm.expectRevert();
         mpCore.executeAction(actionInfo);
       }

### Recommended Mitigation Steps

I suggest that disapprovals should only be allowed to be cast whilst the timestamp is still less than the `minExecutionTime` of the action. Effectively there is a specified disapproval window. The following lines could be added to `_preCastAssertions`:

    if (!isApproval) {
        require(block.timestamp < action.minExecutionTime, "Missed disapproval window");
    }

**[AustinGreen (Llama) confirmed and commented](https://github.com/code-423n4/2023-06-llama-findings/issues/223#issuecomment-1601698591):**
 > We confirm this and are working on a fix. It is a duplicate of https://github.com/code-423n4/2023-06-llama-findings/issues/80
> 
> Not sure if it should be medium or not but don't feel strongly. Llama is a trusted system so this would require malicious user intent or user error.


**[Co0nan (Warden) commented](https://github.com/code-423n4/2023-06-llama-findings/issues/223#issuecomment-1622579973):**
 > This is more of an improved design than a security issue. `disapproval` role is a highly privileged role as per the design of the system. 
> 
> The `minExecutionTime` is meant to prevent someone from executing the action early but is not designed to prevent the `disApproval` role. Either he disapproved early or after `minExecutionTime` passed this doesn't break the logic of the function at all, it will be excepted to cancel the action in this case. I believe this is a valid QA.

**[AustinGreen (Llama) confirmed and commented](https://github.com/code-423n4/2023-06-llama-findings/issues/223):**
 >We removed the ability to disapprove after minExecutionTime to address this finding.

***

## [[M-03] LlamaPolicy could be DOS by creating large amount of actions](https://github.com/code-423n4/2023-06-llama-findings/issues/64)
*Submitted by [ktg](https://github.com/code-423n4/2023-06-llama-findings/issues/64), also found by [auditor0517](https://github.com/code-423n4/2023-06-llama-findings/issues/209), [BLOS](https://github.com/code-423n4/2023-06-llama-findings/issues/144), [Atree](https://github.com/code-423n4/2023-06-llama-findings/issues/142), [Toshii](https://github.com/code-423n4/2023-06-llama-findings/issues/137), [xuwinnie](https://github.com/code-423n4/2023-06-llama-findings/issues/12), and [0xnev](https://github.com/code-423n4/2023-06-llama-findings/issues/10)*

<https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L404-#L409> <br><https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L516-#L562>

### Proof of Concept

Currently, when Executor want to set role for a user, he call function `LlamaPolicy._setRoleHolder`, this in turn will first call function `_assertNoActionCreationsAtCurrentTimestamp`:

    /// @dev Because role supplies are not checkpointed for simplicity, the following issue can occur
      /// if each of the below is executed within the same timestamp:
      //    1. An action is created that saves off the current role supply.
      //    2. A policyholder is given a new role.
      //    3. Now the total supply in that block is different than what it was at action creation.
      // As a result, we disallow changes to roles if an action was created in the same block.
      function _assertNoActionCreationsAtCurrentTimestamp() internal view {
        if (llamaExecutor == address(0)) return; // Skip check during initialization.
        address llamaCore = LlamaExecutor(llamaExecutor).LLAMA_CORE();
        uint256 lastActionCreation = LlamaCore(llamaCore).getLastActionTimestamp();
        if (lastActionCreation == block.timestamp) revert ActionCreationAtSameTimestamp();
      }

As stated in the comment, the protocol disallows changes to roles if an action was created in the same block. However, function `LlamaCore._createAction` does not limit the number of actions a user could create. Consequently, a user with createAction role can DOS protocol's policy by creating large amount of actions. A user can create 24 &ast; 3600 &ast; 30 \~ 2.5 mils actions to DOS a system in a month, this is definitely a not too big number, especially when the protocol is deployed in low fee blockchains. (I notice that the folder `script` is organized as `script/input/{blockchainId}/*.json` so I assume that the protocol will be used across different blockchains).

This will prevents the revoking of expired roles, revoke policy,... because they all use `_setRoleHolder` function.

Below is a POC, for ease of testing, place this test case under file LlamaStrategy.t.sol, contract IsActionApproved:

    function testDOSByCreatingManyAction() public {
        ILlamaStrategy testStrategy = deployTestStrategy();
        uint256 numberOfHolders = 10;
        generateAndSetRoleHolders(numberOfHolders);

        // create action
        bytes32 newPermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy));
        vm.prank(address(mpExecutor));
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), newPermissionId, true);
        bytes memory data = abi.encodeCall(MockProtocol.pause, (true));
        vm.prank(actionCreatorAaron);
        uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), testStrategy, address(mockProtocol), 0, data, "");
        console.logUint(actionId);
        // revert if we try to set role
        vm.prank(address(mpExecutor));
        vm.expectRevert(LlamaPolicy.ActionCreationAtSameTimestamp.selector);
        mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(12345), 1, type(uint64).max);


        // Pass time
        vm.warp(block.timestamp + 1);

        // Create action again
        vm.prank(actionCreatorAaron);
        actionId = mpCore.createAction(uint8(Roles.ActionCreator), testStrategy, address(mockProtocol), 0, data, "");
        console.logUint(actionId);
        // policy can't set role again
        vm.prank(address(mpExecutor));
        vm.expectRevert(LlamaPolicy.ActionCreationAtSameTimestamp.selector);
        mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(12345), 1, type(uint64).max);


      }

### Recommended Mitigation Steps

I recommend limiting the number of active actions a user can create.

**[AustinGreen (Llama) confirmed and commented](https://github.com/code-423n4/2023-06-llama-findings/issues/64#issuecomment-1608402410):**
 > We are tracking the issue here and deciding on a fix: https://github.com/llamaxyz/llama/issues/393
> 
> This is a duplicate of https://github.com/code-423n4/2023-06-llama-findings/issues/209

**[gzeon (Judge) commented](https://github.com/code-423n4/2023-06-llama-findings/issues/64#issuecomment-1616605440):**
 > Keeping this as M given this is a valid DOS vector and the cost to DOS is linear. There are EVM chains with low enough gas fee which can make this a feasible attack.

**[AustinGreen (Llama) commented](https://github.com/code-423n4/2023-06-llama-findings/issues/64):**
>We addressed this issue by adding an additional checkpoint that strategies can use to get a (dis)approval role's total number of holders and total quantity in the past. This allowed us to remove the `_assertNoActionCreationsAtCurrentTimestamp` check.


***

# Low Risk and Non-Critical Issues

For this audit, 9 reports were submitted by wardens detailing low risk and non-critical issues. The [report highlighted below](https://github.com/code-423n4/2023-06-llama-findings/issues/44) by **Rolezn** received the top score from the judge.

*The following wardens also submitted reports: [libratus](https://github.com/code-423n4/2023-06-llama-findings/issues/278), 
[0xSmartContract](https://github.com/code-423n4/2023-06-llama-findings/issues/267), 
[QiuhaoLi](https://github.com/code-423n4/2023-06-llama-findings/issues/199), 
[DavidGiladi](https://github.com/code-423n4/2023-06-llama-findings/issues/158), 
[kutugu](https://github.com/code-423n4/2023-06-llama-findings/issues/123), 
[Sathish9098](https://github.com/code-423n4/2023-06-llama-findings/issues/119), 
[minhquanym](https://github.com/code-423n4/2023-06-llama-findings/issues/107), and
[matrix\_0wl](https://github.com/code-423n4/2023-06-llama-findings/issues/98)
.*

## Summary

### Low Risk Issues
| |Issue|Contexts|
|-|:-|:-:|
| [L-01] | External calls in an un-bounded `for-`loop may result in a DOS | 19 |
| [L-02] | Missing Contract-existence Checks Before Low-level Calls | 4 |
| [L-03] | Protect `LlamaPolicy.sol` NFT from copying in POW forks | 4 |
| [L-04] | Unbounded loop | 7 | 
| [L-05] | Inconsistent documentation to actual function logic | 3 |

Total: 37 contexts over 5 issues

### Non-critical Issues
| |Issue|Contexts|
|-|:-|:-:|
| [N-01] | Critical Changes Should Use Two-step Procedure | 9 |
| [N-02] | Large or complicated code bases should implement fuzzing tests | 1 |
| [N-03] | Initial value check is missing in Set Functions | 9 |
| [N-04] | Use @inheritdoc rather than using a non-standard annotation | 55 |
| [N-05] | Function name should contain `InitializeRoles` instead of `NewRoles` | 1 |
| [N-06] | Add to `blacklist` function | 1 |

Total: 76 contexts over 6 issues

## [L-01] External calls in an un-bounded `for-`loop may result in a DOS

Consider limiting the number of iterations in `for-`loops that make external calls.

### Proof Of Concept

<details>

```solidity
151: for (uint256 i = 0; i < roleDescriptions.length; i = LlamaUtils.uncheckedIncrement(i)) {
155: for (uint256 i = 0; i < roleHolders.length; i = LlamaUtils.uncheckedIncrement(i)) {
161: for (uint256 i = 0; i < rolePermissions.length; i = LlamaUtils.uncheckedIncrement(i)) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L151

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L155

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L161


```solidity
227: for (uint256 i = 1; i <= numRoles; i = LlamaUtils.uncheckedIncrement(i)) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L227

```solidity
291: for (uint256 i = start; i < end; i = LlamaUtils.uncheckedIncrement(i)) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L291

```solidity
156: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
174: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
189: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
207: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
222: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
237: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
270: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
285: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L156

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L174

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L189

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L207

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L222

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L237

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L270

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L285


```solidity
71: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
178: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
186: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
199: for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaGovernanceScript.sol#L71

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaGovernanceScript.sol#L178

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaGovernanceScript.sol#L186

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaGovernanceScript.sol#L199


```solidity
177: for (uint256 i = 0; i < strategyConfig.forceApprovalRoles.length; i = LlamaUtils.uncheckedIncrement(i)) {
185: for (uint256 i = 0; i < strategyConfig.forceDisapprovalRoles.length; i = LlamaUtils.uncheckedIncrement(i)) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/strategies/LlamaAbsoluteStrategyBase.sol#L177

https://github.com/code-423n4/2023-06-llama/tree/main/src/strategies/LlamaAbsoluteStrategyBase.sol#L185

</details>


## [L-02] Missing Contract-existence Checks Before Low-level Calls

Low-level calls return success if there is no code present at the specified address. 

### Proof Of Concept

<details>

```solidity
34: (success, result) = isScript ? target.delegatecall(data) : target.call{value: value}(data);
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaExecutor.sol#L34

```solidity
323: (success, result) = target.delegatecall(callData);
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L323

```solidity
326: (success, result) = target.call{value: msg.value}(callData);
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L326

```solidity
75: (bool success, bytes memory response) = targets[i].call(data[i]);
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaGovernanceScript.sol#L75

</details>

### Recommended Mitigation Steps

In addition to the zero-address checks, add a check to verify that `<address>.code.length > 0`


## [L-03] Protect `LlamaPolicy.sol`  NFT from copying in POW forks
Ethereum has performed the long-awaited "merge" that will dramatically reduce the environmental impact of the network

There may be forked versions of Ethereum, which could cause confusion and lead to scams as duplicated NFT assets enter the market.

If the Ethereum Merge, which took place in September 2022, results in the Blockchain splitting into two Blockchains due to the 'THE DAO' attack in 2016, this could result in duplication of immutable tokens (NFTs).

In any case, duplicate NFTs will exist due to the ETH proof-of-work chain and other potential forks, and there’s likely to be some level of confusion around which assets are 'official' or 'authentic.'

Even so, there could be a frenzy for these copies, as NFT owners attempt to flip the proof-of-work versions of their valuable tokens.

As ETHPOW and any other forks spin off of the Ethereum mainnet, they will yield duplicate versions of Ethereum’s NFTs. An NFT is simply a blockchain token, and it can work as a deed of ownership to digital items like artwork and collectibles. A forked Ethereum chain will thus have duplicated deeds that point to the same tokenURI.

About Merge Replay Attack: https://twitter.com/elerium115/status/1558471934924431363?s=20&t=RRheaYJwo-GmSnePwofgag

### Proof Of Concept

<details>

```solidity
206: function tokenURI(LlamaExecutor llamaExecutor, string memory name, uint256 tokenId)
    external
    view
    returns (string memory)
  {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaFactory.sol#L206

```solidity
346: function tokenURI(uint256 tokenId) public view override returns (string memory) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L346

```solidity
17: function tokenURI(string memory name, uint256 tokenId, string memory color, string memory logo)
    external
    pure
    returns (string memory)
  {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicyMetadata.sol#L17

```solidity
30: function tokenURI(uint256 id) public view virtual returns (string memory);

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/ERC721NonTransferableMinimalProxy.sol#L30

</details>

### Recommended Mitigation Steps

Add the following check:
```solidity
if(block.chainid != 1) { 
    revert(); 
}
```


## [L-04] Unbounded loop

New items are pushed into the following arrays but there is no option to `pop` them out. Currently, the array can grow indefinitely. E.g. there's no maximum limit and there's no functionality to remove array values.

If the array grows too large, calling relevant functions might run out of gas and revert. Calling these functions could result in a DOS condition.

### Proof Of Concept

<details>

```solidity
448: roleBalanceCkpts[tokenId][role].push(willHaveRole ? quantity : 0, expiration);

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L448

```solidity
515: roleBalanceCkpts[tokenId][ALL_HOLDERS_ROLE].push(1);

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L515

```solidity
529: roleBalanceCkpts[tokenId][ALL_HOLDERS_ROLE].push(0);

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L529

```solidity
143: self.push(Checkpoint({timestamp: timestamp, expiration: expiration, quantity: quantity}));
147: self.push(Checkpoint({timestamp: timestamp, expiration: expiration, quantity: quantity}));
143: self.push(Checkpoint({timestamp: timestamp, expiration: expiration, quantity: quantity}));
147: self.push(Checkpoint({timestamp: timestamp, expiration: expiration, quantity: quantity}));

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L143

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L147

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L143

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L147

</details>

### Recommended Mitigation Steps
Add a functionality to delete array values or add a maximum size limit for arrays.


## [L-05] Inconsistent documentation to actual function logic

It is mentioned in documentation of the function `validateActionCreation` that the param `actionInfo` is used. 

```solidity
  /// @notice Reverts if action creation is not allowed.
  /// @param actionInfo Data required to create an action.
  function validateActionCreation(ActionInfo calldata actionInfo) external;
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/interfaces/ILlamaStrategy.sol#L33-L35

However, in `LlamaAbsoluteQuorum.sol` the param is commented out and is not used in the function.

```solidity
  function validateActionCreation(ActionInfo calldata /* actionInfo */ ) external view override {
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsoluteQuorum.sol#L27

The same applies to `isApprovalEnabled` and `isDisapprovalEnabled`.


## [N-01] Critical Changes Should Use Two-step Procedure

The critical procedures should be two step process.

See similar findings in previous Code4rena audits for reference:<br>
https://code4rena.com/reports/2022-06-illuminate/#2-critical-changes-should-use-two-step-procedure

### Proof Of Concept

<details>

```solidity
444: function setGuard(address target, bytes4 selector, ILlamaActionGuard guard) external onlyLlama {
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L444

```solidity
197: function setPolicyMetadata(LlamaPolicyMetadata _llamaPolicyMetadata) external onlyRootLlama {
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaFactory.sol#L197

```solidity
199: function setRoleHolder(uint8 role, address policyholder, uint128 quantity, uint64 expiration) external onlyLlama {
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L199

```solidity
207: function setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) external onlyLlama {
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L207

```solidity
82: function setColor(LlamaExecutor llamaExecutor, string memory _color) public onlyAuthorized(llamaExecutor) {
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicyMetadataParamRegistry.sol#L82

```solidity
90: function setLogo(LlamaExecutor llamaExecutor, string memory _logo) public onlyAuthorized(llamaExecutor) {
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicyMetadataParamRegistry.sol#L90

```solidity
81: function setApprovalForAll(address operator, bool approved) public virtual {
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/ERC721NonTransferableMinimalProxy.sol#L81

```solidity
183: function setRoleHolders(RoleHolderData[] calldata _setRoleHolders) public onlyDelegateCall {
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaGovernanceScript.sol#L183

```solidity
196: function setRolePermissions(RolePermissionData[] calldata _setRolePermissions) public onlyDelegateCall {
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaGovernanceScript.sol#L196

</details>

### Recommended Mitigation Steps

Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.


## [N-02] Large or complicated code bases should implement fuzzing tests

Large code bases, or code with lots of inline-assembly, complicated math, or complicated interactions between multiple contracts, should implement <a href="https://medium.com/coinmonks/smart-contract-fuzzing-d9b88e0b0a05">fuzzing tests</a>. Fuzzers such as Echidna require the test writer to come up with invariants which should not be violated under any circumstances, and the fuzzer tests various inputs and function calls to ensure that the invariants always hold. Even code with 100% code coverage can still have bugs due to the order of the operations a user performs, and fuzzers, with properly and extensively-written invariants, can close this testing gap significantly.

### Proof Of Concept

Various in-scope contract files.


## <[N-03] Initial value check is missing in Set Functions

A check regarding whether the current value and the new value are the same should be added.

### Proof Of Concept

<details>

```solidity
444: function setGuard(address target, bytes4 selector, ILlamaActionGuard guard) external onlyLlama {
    if (target == address(this) || target == address(policy)) revert RestrictedAddress();
    actionGuard[target][selector] = guard;
    emit ActionGuardSet(target, selector, guard);
  }
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L444

```solidity
197: function setPolicyMetadata(LlamaPolicyMetadata _llamaPolicyMetadata) external onlyRootLlama {
    _setPolicyMetadata(_llamaPolicyMetadata);
  }
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaFactory.sol#L197

```solidity
199: function setRoleHolder(uint8 role, address policyholder, uint128 quantity, uint64 expiration) external onlyLlama {
    _setRoleHolder(role, policyholder, quantity, expiration);
  }
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L199

```solidity
207: function setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) external onlyLlama {
    _setRolePermission(role, permissionId, hasPermission);
  }
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L207

```solidity
386: function setApprovalForAll(address,  bool  ) public pure override nonTransferableToken {}
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L386

```solidity
82: function setColor(LlamaExecutor llamaExecutor, string memory _color) public onlyAuthorized(llamaExecutor) {
    color[llamaExecutor] = _color;
    emit ColorSet(llamaExecutor, _color);
  }
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicyMetadataParamRegistry.sol#L82

```solidity
90: function setLogo(LlamaExecutor llamaExecutor, string memory _logo) public onlyAuthorized(llamaExecutor) {
    logo[llamaExecutor] = _logo;
    emit LogoSet(llamaExecutor, _logo);
  }
}
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicyMetadataParamRegistry.sol#L90

```solidity
183: function setRoleHolders(RoleHolderData[] calldata _setRoleHolders) public onlyDelegateCall {
    (, LlamaPolicy policy) = _context();
    uint256 length = _setRoleHolders.length;
    for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
      policy.setRoleHolder(
        _setRoleHolders[i].role,
        _setRoleHolders[i].policyholder,
        _setRoleHolders[i].quantity,
        _setRoleHolders[i].expiration
      );
    }
  }
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaGovernanceScript.sol#L183

```solidity
196: function setRolePermissions(RolePermissionData[] calldata _setRolePermissions) public onlyDelegateCall {
    (, LlamaPolicy policy) = _context();
    uint256 length = _setRolePermissions.length;
    for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
      policy.setRolePermission(
        _setRolePermissions[i].role, _setRolePermissions[i].permissionId, _setRolePermissions[i].hasPermission
      );
    }
  }
```

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaGovernanceScript.sol#L196

</details>


## [N-04] Use @inheritdoc rather than using a non-standard annotation

### Proof Of Concept

<details>

```solidity
514: /// @dev Creates an action. The creator needs to hold a policy with the permission ID of the provided
  /// `(target, selector, strategy)`.
  function _createAction(
    address policyholder,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    string memory description
  ) internal returns (uint256 actionId) {
564: /// @dev How policyholders that have the right role contribute towards the approval of an action with a reason.
  function _castApproval(address policyholder, uint8 role, ActionInfo calldata actionInfo, string memory reason)
    internal
  {
575: /// @dev How policyholders that have the right role contribute towards the disapproval of an action with a reason.
  function _castDisapproval(address policyholder, uint8 role, ActionInfo calldata actionInfo, string memory reason)
    internal
  {
586: /// @dev The only `expectedState` values allowed to be passed into this method are Active or Queued.
  function _preCastAssertions(
    ActionInfo calldata actionInfo,
    address policyholder,
    uint8 role,
    ActionState expectedState
  ) internal returns (Action storage action, uint128 quantity) {
615: /// @dev Returns the new total count of approvals or disapprovals.
  function _newCastCount(uint128 currentCount, uint128 quantity) internal pure returns (uint128) {
621: /// @dev Deploys new strategies. Takes in the strategy logic contract to be used and an array of configurations to
  /// initialize the new strategies with. Returns the address of the first strategy, which is only used during the
  /// `LlamaCore` initialization so that we can ensure someone (specifically, policyholders with role ID 1) has the
  /// permission to assign role permissions.
  function _deployStrategies(ILlamaStrategy llamaStrategyLogic, bytes[] calldata strategyConfigs)
    internal
    returns (ILlamaStrategy firstStrategy)
  {
646: /// @dev Deploys new accounts. Takes in the account logic contract to be used and an array of configurations to
  /// initialize the new accounts with.
  function _deployAccounts(ILlamaAccount llamaAccountLogic, bytes[] calldata accountConfigs) internal {
664: /// @dev Returns the hash of the `createAction` parameters using the `actionInfo` struct.
  function _infoHash(ActionInfo calldata actionInfo) internal pure returns (bytes32) {
677: /// @dev Returns the hash of the `createAction` parameters.
  function _infoHash(
    uint256 id,
    address creator,
    uint8 creatorRole,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data
  ) internal pure returns (bytes32) {
690: /// @dev Validates that the hash of the `actionInfo` struct matches the provided hash.
  function _validateActionInfoHash(bytes32 actualHash, ActionInfo calldata actionInfo) internal pure {
696: /// @dev Returns the current nonce for a given policyholder and selector, and increments it. Used to prevent
  /// replay attacks.
  function _useNonce(address policyholder, bytes4 selector) internal returns (uint256 nonce) {
705: /// @dev Returns the EIP-712 domain separator.
  function _getDomainHash() internal view returns (bytes32) {
712: /// @dev Returns the hash of the ABI-encoded EIP-712 message for the `CreateAction` domain, which can be used to
  /// recover the signer.
  function _getCreateActionTypedDataHash(
    address policyholder,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    string memory description
  ) internal returns (bytes32) {
744: /// @dev Returns the hash of the ABI-encoded EIP-712 message for the `CastApproval` domain, which can be used to
  /// recover the signer.
  function _getCastApprovalTypedDataHash(
    address policyholder,
    uint8 role,
    ActionInfo calldata actionInfo,
    string calldata reason
  ) internal returns (bytes32) {
766: /// @dev Returns the hash of the ABI-encoded EIP-712 message for the `CastDisapproval` domain, which can be used to
  /// recover the signer.
  function _getCastDisapprovalTypedDataHash(
    address policyholder,
    uint8 role,
    ActionInfo calldata actionInfo,
    string calldata reason
  ) internal returns (bytes32) {
788: /// @dev Returns the hash of `actionInfo`.
  function _getActionInfoHash(ActionInfo calldata actionInfo) internal pure returns (bytes32) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L514

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L564

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L575

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L586

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L615

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L621

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L646

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L664

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L677

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L690

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L696

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L705

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L712

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L744

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L766

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaCore.sol#L788



```solidity
226: /// @dev Deploys a new Llama instance.
  function _deploy(
    string memory name,
    ILlamaStrategy strategyLogic,
    ILlamaAccount accountLogic,
    bytes[] memory initialStrategies,
    bytes[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) internal returns (LlamaExecutor llamaExecutor, LlamaCore llamaCore) {
266: /// @dev Authorizes a strategy implementation (logic) contract.
  function _authorizeStrategyLogic(ILlamaStrategy strategyLogic) internal {
272: /// @dev Authorizes an account implementation (logic) contract.
  function _authorizeAccountLogic(ILlamaAccount accountLogic) internal {
278: /// @dev Sets the Llama policy metadata contract.
  function _setPolicyMetadata(LlamaPolicyMetadata _llamaPolicyMetadata) internal {
284: /// @dev Sets the `color` and `logo` of a Llama instance.
  function _setDeploymentMetadata(LlamaExecutor llamaExecutor, string memory color, string memory logo) internal {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaFactory.sol#L226

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaFactory.sol#L266

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaFactory.sol#L272

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaFactory.sol#L278

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaFactory.sol#L284


```solidity
73: /// @dev Ensures that none of the ERC721 `transfer` and `approval` functions can be called, so that the policies are
  /// soulbound.
  modifier nonTransferableToken() {
358: /// @dev overriding `transferFrom` to disable transfers
  function transferFrom(address, /* from */ address, /* to */ uint256 /* policyId */ )
    public
    pure
    override
    nonTransferableToken
  {
366: /// @dev overriding `safeTransferFrom` to disable transfers
  function safeTransferFrom(address, /* from */ address, /* to */ uint256 /* id */ )
    public
    pure
    override
    nonTransferableToken
  {
374: /// @dev overriding `safeTransferFrom` to disable transfers
  function safeTransferFrom(address, /* from */ address, /* to */ uint256, /* policyId */ bytes calldata /* data */ )
    public
    pure
    override
    nonTransferableToken
  {
382: /// @dev overriding `approve` to disable approvals
  function approve(address, /* spender */ uint256 /* id */ ) public pure override nonTransferableToken {
385: /// @dev overriding `approve` to disable approvals
  function setApprovalForAll(address, /* operator */ bool /* approved */ ) public pure override nonTransferableToken {
392: /// @dev Initializes the next unassigned role with the given `description`.
  function _initializeRole(RoleDescription description) internal {
398: /// @dev Because role supplies are not checkpointed for simplicity, the following issue can occur
  /// if each of the below is executed within the same timestamp:
  //    1. An action is created that saves off the current role supply.
  //    2. A policyholder is given a new role.
  //    3. Now the total supply in that block is different than what it was at action creation.
  // As a result, we disallow changes to roles if an action was created in the same block.
  function _assertNoActionCreationsAtCurrentTimestamp() internal view {
411: /// @dev Checks if the conditions are met for a `role` to be updated.
  function _assertValidRoleHolderUpdate(uint8 role, uint128 quantity, uint64 expiration) internal view {
430: /// @dev Sets the `role` for the given `policyholder` to the given `quantity` and `expiration`.
  function _setRoleHolder(uint8 role, address policyholder, uint128 quantity, uint64 expiration) internal {
489: /// @dev Sets a role's permission along with whether that permission is valid or not.
  function _setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) internal {
496: /// @dev Revokes a policyholder's expired `role`.
  function _revokeExpiredRole(uint8 role, address policyholder) internal {
503: /// @dev Mints a policyholder's policy.
  function _mint(address policyholder) internal {
518: /// @dev Burns a policyholder's policy.
  function _burn(uint256 tokenId) internal override {
532: /// @dev Returns the token ID for a `policyholder`.
  function _tokenId(address policyholder) internal pure returns (uint256) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L73

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L358

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L366

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L374

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L382

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L385

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L392

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L398

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L411

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L430

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L489

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L496

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L503

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L518

https://github.com/code-423n4/2023-06-llama/tree/main/src/LlamaPolicy.sol#L532


```solidity
337: /// @dev Reads slot 0 from storage, used to check that storage hasn't changed after delegatecall.
  function _readSlot0() internal view returns (bytes32 slot0) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/accounts/LlamaAccount.sol#L337

```solidity
7: /**
 * @dev This library defines the `History` struct, for checkpointing values as they change at different points in
 * time, and later looking up past values by block timestamp.
 *
 * To create a history of checkpoints define a variable type `Checkpoints.History` in your contract, and store a new
 * checkpoint for the current transaction timestamp using the {push} function.
 *
 * @dev This was created by modifying then running the OpenZeppelin `Checkpoints.js` script, which generated a version
 * of this library that uses a 64 bit `timestamp` and 128 bit `quantity` field in the `Checkpoint` struct. The struct
 * was then modified to add a 64 bit `expiration` field. For simplicity, safe cast and math methods were inlined from
 * the OpenZeppelin versions at the same commit. We disable forge-fmt for this file to simplify diffing against the
 * original OpenZeppelin version: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/d00acef4059807535af0bd0dd0ddf619747a044b/contracts/utils/Checkpoints.sol
 */
library Checkpoints {
31: /**
     * @dev Returns the quantity at a given block timestamp. If a checkpoint is not available at that time, the closest
     * one before it is returned, or zero otherwise. Similar to {upperLookup} but optimized for the case when the
     * searched checkpoint is probably "recent", defined as being among the last sqrt(N) checkpoints where N is the
     * timestamp of checkpoints.
     */
    function getAtProbablyRecentTimestamp(History storage self, uint256 timestamp) internal view returns (uint128) {
60: /**
     * @dev Pushes a `quantity` and `expiration` onto a History so that it is stored as the checkpoint for the current
     * `timestamp`.
     *
     * Returns previous quantity and new quantity.
     */
    function push(History storage self, uint256 quantity, uint256 expiration) internal returns (uint128, uint128) {
70: /**
     * @dev Pushes a `quantity` with no expiration onto a History so that it is stored as the checkpoint for the current
     * `timestamp`.
     *
     * Returns previous quantity and new quantity.
     */
    function push(History storage self, uint256 quantity) internal returns (uint128, uint128) {
80: /**
     * @dev Returns the quantity in the most recent checkpoint, or zero if there are no checkpoints.
     */
    function latest(History storage self) internal view returns (uint128) {
88: /**
     * @dev Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the timestamp and
     * quantity in the most recent checkpoint.
     */
    function latestCheckpoint(History storage self)
        internal
        view
        returns (
            bool exists,
            uint64 timestamp,
            uint64 expiration,
            uint128 quantity
        )
    {
111: /**
     * @dev Returns the number of checkpoints.
     */
    function length(History storage self) internal view returns (uint256) {
118: /**
     * @dev Pushes a (`timestamp`, `expiration`, `quantity`) pair into an ordered list of checkpoints, either by inserting a new
     * checkpoint, or by updating the last one.
     */
    function _insert(
        Checkpoint[] storage self,
        uint64 timestamp,
        uint64 expiration,
        uint128 quantity
    ) private returns (uint128, uint128) {
152: /**
     * @dev Return the index of the oldest checkpoint whose timestamp is greater than the search timestamp, or `high`
     * if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and exclusive
     * `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _upperBinaryLookup(
        Checkpoint[] storage self,
        uint64 timestamp,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
176: /**
     * @dev Return the index of the oldest checkpoint whose timestamp is greater or equal than the search timestamp, or
     * `high` if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and
     * exclusive `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _lowerBinaryLookup(
        Checkpoint[] storage self,
        uint64 timestamp,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
211: /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) private pure returns (uint256) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L7

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L31

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L60

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L70

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L80

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L88

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L111

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L118

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L152

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L176

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Checkpoints.sol#L211


```solidity
4: /// @dev Shared helper methods for Llama's contracts.
library LlamaUtils {
  /// @dev Thrown when a value cannot be safely casted to a smaller type.
  error UnsafeCast(uint256 n);

  /// @dev Reverts if `n` does not fit in a `uint64`.
  function toUint64(uint256 n) internal pure returns (uint64) {
15: /// @dev Reverts if `n` does not fit in a `uint128`.
  function toUint128(uint256 n) internal pure returns (uint128) {
21: /// @dev Increments a `uint256` without checking for overflow.
  function uncheckedIncrement(uint256 i) internal pure returns (uint256) {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/LlamaUtils.sol#L4

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/LlamaUtils.sol#L15

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/LlamaUtils.sol#L21


```solidity
6: /// @dev Data required to create an action.
struct ActionInfo {
  uint256 id; // ID of the action.
  address creator; // Address that created the action.
  uint8 creatorRole; // The role that created the action.
  ILlamaStrategy strategy; // Strategy used to govern the action.
  address target; // Contract being called by an action.
  uint256 value; // Value in wei to be sent when the action is executed.
  bytes data; // Data to be called on the target when the action is executed.
}

/// @dev Data that represents an action.
struct Action {
  // Instead of storing all data required to execute an action in storage, we only save the hash to
  // make action creation cheaper. The hash is computed by taking the keccak256 hash of the concatenation of each
  // field in the `ActionInfo` struct.
  bytes32 infoHash;
  bool executed; // Has action executed.
  bool canceled; // Is action canceled.
  bool isScript; // Is the action's target a script.
  uint64 creationTime; // The timestamp when action was created (used for policy snapshots).
  uint64 minExecutionTime; // Only set when an action is queued. The timestamp when action execution can begin.
  uint128 totalApprovals; // The total quantity of policyholder approvals.
  uint128 totalDisapprovals; // The total quantity of policyholder disapprovals.
}

/// @dev Data that represents a permission.
struct PermissionData {
  address target; // Contract being called by an action.
  bytes4 selector; // Selector of the function being called by an action.
  ILlamaStrategy strategy; // Strategy used to govern the action.
}

/// @dev Data required to assign/revoke a role to/from a policyholder.
struct RoleHolderData {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/lib/Structs.sol#L6

```solidity
4: /// @dev This script is a template for creating new scripts, and should not be used directly.
abstract contract LlamaBaseScript {
  /// @dev Thrown if you try to CALL a function that has the `onlyDelegatecall` modifier.
  error OnlyDelegateCall();

  /// @dev Add this to your script's methods to ensure the script can only be used via delegatecall, and not a regular
  /// call.
  modifier onlyDelegateCall() {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/llama-scripts/LlamaBaseScript.sol#L4

```solidity
303: /// @dev Reverts if the given `role` is greater than `numRoles`.
  function _assertValidRole(uint8 role, uint8 numRoles) internal pure {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/strategies/LlamaAbsoluteStrategyBase.sol#L303

```solidity
323: /// @dev Reverts if the given `role` is greater than `numRoles`.
  function _assertValidRole(uint8 role, uint8 numRoles) internal pure {

```

https://github.com/code-423n4/2023-06-llama/tree/main/src/strategies/LlamaRelativeQuorum.sol#L323

</details>


## [N-05] Function name should contain `InitializeRoles` instead of `NewRoles`

The function `createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissions` should be `createNewStrategiesAndInitializeRolesAndSetRoleHoldersAndSetRolePermissions` as it calls `initializeRoles(description);`.

Similar to the function `createNewStrategiesAndInitializeRolesAndSetRoleHolders`

### Proof Of Concept

```solidity
  function createNewStrategiesAndInitializeRolesAndSetRoleHolders(
    CreateStrategies calldata _createStrategies,
    RoleDescription[] calldata description,
    RoleHolderData[] calldata _setRoleHolders
  ) external onlyDelegateCall {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
  }
```
https://github.com/code-423n4/2023-06-llama/blob/main/src/llama-scripts/LlamaGovernanceScript.sol#L120-L129

```solidity
  function createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissions(
    CreateStrategies calldata _createStrategies,
    RoleDescription[] calldata description,
    RoleHolderData[] calldata _setRoleHolders,
    RolePermissionData[] calldata _setRolePermissions
  ) external onlyDelegateCall {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
    setRolePermissions(_setRolePermissions);
  }
```
https://github.com/code-423n4/2023-06-llama/blob/main/src/llama-scripts/LlamaGovernanceScript.sol#L140-L151


## [N-06] Add to `blacklist` function
It is noted that in this project: `LlamaPolicy.sol is an NFT`.

NFT thefts have increased recently, so with the addition of hacked NFTs to the platform, NFTs can be converted into liquidity. To prevent this, I recommend adding the blacklist function.

Marketplaces such as Opensea have a blacklist feature that will not list NFTs that have been reported theft, NFT projects such as Manifold have blacklist functions in their smart contracts.

Here is the project example; Manifold

Manifold Contract https://etherscan.io/address/0xe4e4003afe3765aca8149a82fc064c0b125b9e5a#code

```solidity
     modifier nonBlacklistRequired(address extension) {
         require(!_blacklistedExtensions.contains(extension), "Extension blacklisted");
         _;
     }
```


### Recommended Mitigation Steps
Add to Blacklist function and modifier.

**[AustinGreen (Llama) commented](https://github.com/code-423n4/2023-06-llama-findings/issues/44#issuecomment-1629329290):**
> L-01: These external calls are to the internal Llama system so this finding is incorrect.<br>
> L-03: We plan to deploy Llama on multiple EVM chains so this check would not make sense.


***

# Gas Optimizations

For this audit, 17 reports were submitted by wardens detailing gas optimizations. The [report highlighted below](https://github.com/code-423n4/2023-06-llama-findings/issues/174) by **JCN** received the top score from the judge.

*The following wardens also submitted reports: [naman1778](https://github.com/code-423n4/2023-06-llama-findings/issues/285), 
[0xSmartContract](https://github.com/code-423n4/2023-06-llama-findings/issues/284), 
[sebghatullah](https://github.com/code-423n4/2023-06-llama-findings/issues/257), 
[SM3\_SS](https://github.com/code-423n4/2023-06-llama-findings/issues/233), 
[shamsulhaq123](https://github.com/code-423n4/2023-06-llama-findings/issues/230), 
[hunter\_w3b](https://github.com/code-423n4/2023-06-llama-findings/issues/228), 
[SAQ](https://github.com/code-423n4/2023-06-llama-findings/issues/227), 
[petrichor](https://github.com/code-423n4/2023-06-llama-findings/issues/225), 
[Rageur](https://github.com/code-423n4/2023-06-llama-findings/issues/220), 
[Raihan](https://github.com/code-423n4/2023-06-llama-findings/issues/216), 
[SAAJ](https://github.com/code-423n4/2023-06-llama-findings/issues/157), 
[lsaudit](https://github.com/code-423n4/2023-06-llama-findings/issues/156), 
[DavidGiladi](https://github.com/code-423n4/2023-06-llama-findings/issues/155), 
[Sathish9098](https://github.com/code-423n4/2023-06-llama-findings/issues/120), 
[Rolezn](https://github.com/code-423n4/2023-06-llama-findings/issues/117), and
[VictoryGod](https://github.com/code-423n4/2023-06-llama-findings/issues/84)
.*

## Summary
A majority of the optimizations were benchmarked via the protocol's tests, i.e. using the following config: `solc version 0.8.17`, `optimizer on`, and `1300 runs`. Optimizations that were not benchmarked are explained via EVM gas costs and opcodes.

**Note**
- Only optimizations for state-mutating functions (i.e. non `view`/`pure`) and `view`/`pure` functions called within state-mutating functions have been highlighted below.
- Some code snippets may be truncated to save space. Code snippets may also be accompanied by @audit tags in comments to aid in explaining the issue.

## Table of Contents
| Number |Issue|Instances| Gas Saved |
|-|:-|:-:|:-:|
| [G-01] | State variables can be cached instead of re-reading them from storage | 5 | 500 | 
| [G-02] | Cache state variables outside of loop to avoid reading/writing storage on every iteration | 3 | 5869 | 
| [G-03] | Multiple address mappings can be combined into a single mapping of an address to a struct, where appropriate | 1 | 21838 |
| [G-04] | Cache calldata/memory pointers for complex types to avoid offset calculations | 2 | 1192 |
| [G-05] | Forgo internal function to save 1 `STATICCALL`  | 4 | 400 |
| [G-06] | Multiple accesses of a mapping/array should use a local variable cache | 1 | 116 |
| [G-07] | Refactor `If`/`require` statements to save SLOADs in case of early revert | 4 | - |

*Total Estimated Gas Saved: 29915*

## [G-01] State variables can be cached instead of re-reading them from storage
Caching of a state variable replaces each `Gwarmaccess (100 gas)` with a much cheaper stack read.

Total Instances: `5`

Estimated Gas Saved: `5 * 100 = 500`

**Note: These are instances missed by the Automated Report**.

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L542-L559

### Use already cached `actionId` to save 1 SLOAD
```solidity
File: src/LlamaCore.sol
542:    actionId = actionsCount; // @audit: 1st sload
...
559:    actionsCount = LlamaUtils.uncheckedIncrement(actionsCount); // Safety: Can never overflow a uint256 by incrementing. // @audit: 2nd sload
```
```diff
diff --git a/src/LlamaCore.sol b/src/LlamaCore.sol
index 89d60de..049f66d 100644
--- a/src/LlamaCore.sol
+++ b/src/LlamaCore.sol
@@ -556,7 +556,7 @@ contract LlamaCore is Initializable {
       newAction.isScript = authorizedScripts[target];
     }

-    actionsCount = LlamaUtils.uncheckedIncrement(actionsCount); // Safety: Can never overflow a uint256 by incrementing.
+    actionsCount = LlamaUtils.uncheckedIncrement(actionId); // Safety: Can never overflow a uint256 by incrementing.

     emit ActionCreated(actionId, policyholder, role, strategy, target, value, data, description);
   }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsolutePeerReview.sol#L56-L58

### Cache `minDisapprovals` to save 1 SLOAD
```solidity
File: src/strategies/LlamaAbsolutePeerReview.sol
56:      if (
57:        minDisapprovals != type(uint128).max // @audit: 1st sload
58:          && minDisapprovals > disapprovalPolicySupply - actionCreatorDisapprovalRoleQty // @audit: 2nd sload
```
```diff
diff --git a/src/strategies/LlamaAbsolutePeerReview.sol b/src/strategies/LlamaAbsolutePeerReview.sol
index 85feb92..c8426aa 100644
--- a/src/strategies/LlamaAbsolutePeerReview.sol
+++ b/src/strategies/LlamaAbsolutePeerReview.sol
@@ -53,9 +53,10 @@ contract LlamaAbsolutePeerReview is LlamaAbsoluteStrategyBase {
       if (minApprovals > approvalPolicySupply - actionCreatorApprovalRoleQty) revert InsufficientApprovalQuantity();

       uint256 actionCreatorDisapprovalRoleQty = llamaPolicy.getQuantity(actionInfo.creator, disapprovalRole);
+      uint128 _minDisapprovals = minDisapprovals;
       if (
-        minDisapprovals != type(uint128).max
-          && minDisapprovals > disapprovalPolicySupply - actionCreatorDisapprovalRoleQty
+        _minDisapprovals != type(uint128).max
+          && _minDisapprovals > disapprovalPolicySupply - actionCreatorDisapprovalRoleQty
       ) revert InsufficientDisapprovalQuantity();
     }
   }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaRelativeQuorum.sol#L220-L223

### Cache `forceApprovalRole[role]` to save 1 SLOAD
```solidity
File: src/strategies/LlamaRelativeQuorum.sol
220:  function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint128) {
221:    if (role != approvalRole && !forceApprovalRole[role]) return 0; // @audit: 1st sload
222:    uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
223:    return quantity > 0 && forceApprovalRole[role] ? type(uint128).max : quantity; // @audit: 2nd sload
```
```diff
diff --git a/src/strategies/LlamaRelativeQuorum.sol b/src/strategies/LlamaRelativeQuorum.sol
index d796ae9..8d74c92 100644
--- a/src/strategies/LlamaRelativeQuorum.sol
+++ b/src/strategies/LlamaRelativeQuorum.sol
@@ -218,9 +218,10 @@ contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {

   /// @inheritdoc ILlamaStrategy
   function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint128) {
-    if (role != approvalRole && !forceApprovalRole[role]) return 0;
+    bool _forceApprovalRole = forceApprovalRole[role];
+    if (role != approvalRole && !_forceApprovalRole) return 0;
     uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
-    return quantity > 0 && forceApprovalRole[role] ? type(uint128).max : quantity;
+    return quantity > 0 && _forceApprovalRole ? type(uint128).max : quantity;
   }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaRelativeQuorum.sol#L240-L242

### Cache `forceDisapprovalRole[role]` to save 1 SLOAD
```solidity
File: src/strategies/LlamaRelativeQuorum.sol
240:    if (role != disapprovalRole && !forceDisapprovalRole[role]) return 0; // @audit: 1st sload
241:    uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
242:    return quantity > 0 && forceDisapprovalRole[role] ? type(uint128).max : quantity; // @audit: 2nd sload
```
```diff
diff --git a/src/strategies/LlamaRelativeQuorum.sol b/src/strategies/LlamaRelativeQuorum.sol
index d796ae9..e1c3927 100644
--- a/src/strategies/LlamaRelativeQuorum.sol
+++ b/src/strategies/LlamaRelativeQuorum.sol
@@ -237,9 +237,10 @@ contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {
     view
     returns (uint128)
   {
-    if (role != disapprovalRole && !forceDisapprovalRole[role]) return 0;
+    bool _forceDisapprovalRole = forceDisapprovalRole[role];
+    if (role != disapprovalRole && !_forceDisapprovalRole) return 0;
     uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
-    return quantity > 0 && forceDisapprovalRole[role] ? type(uint128).max : quantity;
+    return quantity > 0 && _forceDisapprovalRole ? type(uint128).max : quantity;
   }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaFactory.sol#L260-L263

### Cache `llamaCount` to save 1 SLOAD
```solidity
File: src/LlamaFactory.sol
260:    emit LlamaInstanceCreated(
261:      llamaCount, name, address(llamaCore), address(llamaExecutor), address(policy), block.chainid // @audit: 1st sload
262:    );
263:    llamaCount = LlamaUtils.uncheckedIncrement(llamaCount); // @audit: 2nd sload
```
```diff
diff --git a/src/LlamaFactory.sol b/src/LlamaFactory.sol
index 0cc4cfd..269e4cb 100644
--- a/src/LlamaFactory.sol
+++ b/src/LlamaFactory.sol
@@ -256,11 +256,12 @@ contract LlamaFactory {
     llamaExecutor = llamaCore.executor();

     policy.finalizeInitialization(address(llamaExecutor), bootstrapPermissionId);
-
+
+    uint256 _llamaCount = llamaCount;
     emit LlamaInstanceCreated(
-      llamaCount, name, address(llamaCore), address(llamaExecutor), address(policy), block.chainid
+      _llamaCount, name, address(llamaCore), address(llamaExecutor), address(policy), block.chainid
     );
-    llamaCount = LlamaUtils.uncheckedIncrement(llamaCount);
+    llamaCount = LlamaUtils.uncheckedIncrement(_llamaCount);
   }
```

## [G-02] Cache state variables outside of loop to avoid reading/writing storage on every iteration
Reading from storage should always try to be avoided within loops. In the following instances, we are able to cache state variables outside of the loop to save a `Gwarmaccess (100 gas)` per loop iteration. In addition, for some instances we are also able to increment the cached variable in the loop and update the storage variable outside the loop to save 1 `SSTORE` per loop iteration.

Total Instances: `3`

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L227

*Gas Savings for `LlamaPolicy.revokePolicy`, obtained via protocol's tests: Avg 724 gas*

|        |    Med   |    Max   |   Avg   | # calls  |
| ------ | -------- | -------- | ------- | -------- |
| Before |  69040   |  110067  |  59837 |    11     |
| Before |  68180   |  108992  |  59113 |    11     |

### Cache `numRoles` outside of loop to save 1 SLOAD per iteration
```solidity
File: src/LlamaPolicy.sol
227    for (uint256 i = 1; i <= numRoles; i = LlamaUtils.uncheckedIncrement(i)) { // @audit: numRoles read on every iteration
```
```diff
diff --git a/src/LlamaPolicy.sol b/src/LlamaPolicy.sol
index 3fca63e..7e47189 100644
--- a/src/LlamaPolicy.sol
+++ b/src/LlamaPolicy.sol
@@ -224,7 +224,8 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
     // We start from i = 1 here because a value of zero is reserved for the "all holders" role, and
     // that will get removed automatically when the token is burned. Similarly, use we `<=` to make sure
     // the last role is also revoked.
-    for (uint256 i = 1; i <= numRoles; i = LlamaUtils.uncheckedIncrement(i)) {
+    uint8 _numRoles = numRoles;
+    for (uint256 i = 1; i <= _numRoles; i = LlamaUtils.uncheckedIncrement(i)) {
       if (hasRole(policyholder, uint8(i))) _setRoleHolder(uint8(i), policyholder, 0, 0);
     }
     _burn(_tokenId(policyholder));
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L151-L168

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L393-L396

*Gas Savings for `LlamaFactory.deploy`, obtained via protocol's tests: Avg 4468 gas*

|        |    Med   |    Max   |   Avg   | # calls  |
| ------ | -------- | -------- | ------- | -------- |
| Before |  5101157 |  5406425 | 5015882 |    412   |
| After  |  5096893 |  5281811 | 5011414 |    412   |

*To benchmark this instance we will bring the logic from `_initializeRole` into the construtor in order to refactor the logic. Note that another way of achieving this is by refactoring the logic of the `_initializeRole` directly and every other function that calls `_initializeRole`.*

### Cache `numRoles` outside loop, increment cached variable in loop, and update storage outside loop to save 2 SLOADs + 1 SSTORE per iteration
```solidity
File: src/LlamaPolicy.sol
151:    for (uint256 i = 0; i < roleDescriptions.length; i = LlamaUtils.uncheckedIncrement(i)) {
152:      _initializeRole(roleDescriptions[i]); // @audit: sload & sstore for `numRoles` on every iteration
153:    }
...
168:    if (numRoles == 0 || getRoleSupplyAsNumberOfHolders(ALL_HOLDERS_ROLE) == 0) revert InvalidRoleHolderInput(); // @audit: sload for `numRoles`

393:  function _initializeRole(RoleDescription description) internal {
394:    numRoles += 1; // @audit: sload + sstore for `numRoles`
395:    emit RoleInitialized(numRoles, description); // @audit: 2nd sload 
  }
```
```diff
diff --git a/src/LlamaPolicy.sol b/src/LlamaPolicy.sol
index 3fca63e..af2129b 100644
--- a/src/LlamaPolicy.sol
+++ b/src/LlamaPolicy.sol
@@ -148,9 +148,12 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
   ) external initializer {
     __initializeERC721MinimalProxy(_name, string.concat("LL-", LibString.replace(LibString.upper(_name), " ", "-")));
     factory = LlamaFactory(msg.sender);
+    uint8 _numRoles = numRoles;
     for (uint256 i = 0; i < roleDescriptions.length; i = LlamaUtils.uncheckedIncrement(i)) {
-      _initializeRole(roleDescriptions[i]);
+        _numRoles += 1;
+        emit RoleInitialized(_numRoles, roleDescriptions[i]);
     }
+    numRoles = _numRoles;

     for (uint256 i = 0; i < roleHolders.length; i = LlamaUtils.uncheckedIncrement(i)) {
       _setRoleHolder(
@@ -165,7 +168,7 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
     // Must have assigned roles during initialization, otherwise the system cannot be used. However,
     // we do not check that roles were assigned "properly" as there is no single correct way, so
     // this is more of a sanity check, not a guarantee that the system will work after initialization.
-    if (numRoles == 0 || getRoleSupplyAsNumberOfHolders(ALL_HOLDERS_ROLE) == 0) revert InvalidRoleHolderInput();
+    if (_numRoles == 0 || getRoleSupplyAsNumberOfHolders(ALL_HOLDERS_ROLE) == 0) revert InvalidRoleHolderInput();
   }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L161-L163

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L490-L491

*Gas Savings for `LlamaFactory.deploy`, obtained via protocol's tests: Avg 677 gas*

|        |    Med   |    Max   |   Avg   | # calls  |
| ------ | -------- | -------- | ------- | -------- |
| Before |  5101157 |  5406425 | 5015882 |    412   |
| After  |  5101175 |  5120119 | 5015205 |    412   |

*To benchmark this instance we will refactor the logic of the `_setRolePermission` internal function directly and also refactor every other function that calls `_setRolePermission`. Another way of achieving this would be to move the logic of `_setRolePermission` into the construtor and refactoring it there.*

### Cache `numRoles` outside loop to save 1 SLOAD per iteration
```solidity
File: src/LlamaPolicy.sol
161:    for (uint256 i = 0; i < rolePermissions.length; i = LlamaUtils.uncheckedIncrement(i)) {
162:      _setRolePermission(rolePermissions[i].role, rolePermissions[i].permissionId, rolePermissions[i].hasPermission); // @audit: sload for `numRoles` on every iteration
163:    }

490:  function _setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) internal {
491:    if (role > numRoles) revert RoleNotInitialized(role); // @audit: sload for `numRoles`
```
```diff
diff --git a/src/LlamaPolicy.sol b/src/LlamaPolicy.sol
index 3fca63e..8a3273a 100644
--- a/src/LlamaPolicy.sol
+++ b/src/LlamaPolicy.sol
@@ -157,15 +157,16 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
         roleHolders[i].role, roleHolders[i].policyholder, roleHolders[i].quantity, roleHolders[i].expiration
       );
     }
-
+
+    uint8 _numRoles = numRoles;
     for (uint256 i = 0; i < rolePermissions.length; i = LlamaUtils.uncheckedIncrement(i)) {
-      _setRolePermission(rolePermissions[i].role, rolePermissions[i].permissionId, rolePermissions[i].hasPermission);
+      _setRolePermission(_numRoles, rolePermissions[i].role, rolePermissions[i].permissionId, rolePermissions[i].hasPermission);
     }

     // Must have assigned roles during initialization, otherwise the system cannot be used. However,
     // we do not check that roles were assigned "properly" as there is no single correct way, so
     // this is more of a sanity check, not a guarantee that the system will work after initialization.
-    if (numRoles == 0 || getRoleSupplyAsNumberOfHolders(ALL_HOLDERS_ROLE) == 0) revert InvalidRoleHolderInput();
+    if (_numRoles == 0 || getRoleSupplyAsNumberOfHolders(ALL_HOLDERS_ROLE) == 0) revert InvalidRoleHolderInput();
   }

   // ===========================================
@@ -181,7 +182,7 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
     if (llamaExecutor != address(0)) revert AlreadyInitialized();

     llamaExecutor = _llamaExecutor;
-    _setRolePermission(BOOTSTRAP_ROLE, bootstrapPermissionId, true);
+    _setRolePermission(numRoles, BOOTSTRAP_ROLE, bootstrapPermissionId, true);
   }

   // -------- Role and Permission Management --------
@@ -205,7 +206,7 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
   /// @param permissionId Permission ID to assign to the role.
   /// @param hasPermission Whether to assign the permission or remove the permission.
   function setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) external onlyLlama {
-    _setRolePermission(role, permissionId, hasPermission);
+    _setRolePermission(numRoles, role, permissionId, hasPermission);
   }

   /// @notice Revokes a policyholder's expired role.
@@ -487,8 +488,8 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
   }

   /// @dev Sets a role's permission along with whether that permission is valid or not.
-  function _setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) internal {
-    if (role > numRoles) revert RoleNotInitialized(role);
+  function _setRolePermission(uint8 _numRoles, uint8 role, bytes32 permissionId, bool hasPermission) internal {
+    if (role > _numRoles) revert RoleNotInitialized(role);
     canCreateAction[role][permissionId] = hasPermission;
     emit RolePermissionAssigned(role, permissionId, hasPermission);
   }
```

## [G-03] Multiple address mappings can be combined into a single mapping of an address to a struct, where appropriate
We can combine multiple mappings below into structs. This will result in cheaper storage reads since multiple mappings are accessed in functions and those values are now occupying the same storage slot, meaning the slot will become warm after the first SLOAD. In addition, when writing to and reading from the struct values we will avoid a `Gsset (20000 gas)` and `Gcoldsload (2100 gas)` since multiple struct values are now occupying the same slot.

**Note: This instance was missed by the automated report.**

https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaRelativeQuorum.sol#L130-L133

*Gas Savings for `LlamaCore.executeAction`, obtained via protocol's tests: Avg 21838 gas*

|        |    Med   |    Max   |   Avg   | # calls  |
| ------ | -------- | -------- | ------- | -------- |
| Before |  5186172 | 23819570 | 4807541 |    430   |
| After  |  5164334 | 32081589 | 4803180 |    430   |

```solidity
File: src/strategies/LlamaRelativeQuorum.sol
130:  mapping(uint8 => bool) public forceApprovalRole;
131:
132:  /// @notice Mapping of roles that can force an action to be disapproved.
133:  mapping(uint8 => bool) public forceDisapprovalRole;
```
```diff
diff --git a/src/strategies/LlamaRelativeQuorum.sol b/src/strategies/LlamaRelativeQuorum.sol
index d796ae9..2cbeb0c 100644
--- a/src/strategies/LlamaRelativeQuorum.sol
+++ b/src/strategies/LlamaRelativeQuorum.sol
@@ -125,12 +125,13 @@ contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {

   /// @notice The role that can disapprove an action.
   uint8 public disapprovalRole;
+
+  struct ForceRoles {
+    bool forceApprovalRole;
+    bool forceDisapprovalRole;
+  }

-  /// @notice Mapping of roles that can force an action to be approved.
-  mapping(uint8 => bool) public forceApprovalRole;
-
-  /// @notice Mapping of roles that can force an action to be disapproved.
-  mapping(uint8 => bool) public forceDisapprovalRole;
+  mapping(uint8 => ForceRoles) forceRoles;

   /// @notice Mapping of action ID to the supply of the approval role at the time the action was created.
   mapping(uint256 => uint256) public actionApprovalSupply;
@@ -146,6 +147,15 @@ contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {
     _disableInitializers();
   }

+  // @audit: Getters used for benchmarking purposes
+  function forceApprovalRole(uint8 role) external view returns (bool) {
+    return forceRoles[role].forceApprovalRole;
+  }
+
+  function forceDisapprovalRole(uint8 role) external view returns (bool) {
+    return forceRoles[role].forceDisapprovalRole;
+  }
+
   // ==========================================
   // ======== Interface Implementation ========
   // ==========================================
@@ -178,7 +188,7 @@ contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {
       uint8 role = strategyConfig.forceApprovalRoles[i];
       if (role == 0) revert InvalidRole(0);
       _assertValidRole(role, numRoles);
-      forceApprovalRole[role] = true;
+      forceRoles[role].forceApprovalRole = true;
       emit ForceApprovalRoleAdded(role);
     }

@@ -186,7 +196,7 @@ contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {
       uint8 role = strategyConfig.forceDisapprovalRoles[i];
       if (role == 0) revert InvalidRole(0);
       _assertValidRole(role, numRoles);
-      forceDisapprovalRole[role] = true;
+      forceRoles[role].forceDisapprovalRole = true;
       emit ForceDisapprovalRoleAdded(role);
     }

@@ -213,14 +223,14 @@ contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {

   /// @inheritdoc ILlamaStrategy
   function isApprovalEnabled(ActionInfo calldata, address, uint8 role) external view {
-    if (role != approvalRole && !forceApprovalRole[role]) revert InvalidRole(approvalRole);
+    if (role != approvalRole && !forceRoles[role].forceApprovalRole) revert InvalidRole(approvalRole);
   }

   /// @inheritdoc ILlamaStrategy
   function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint128) {
-    if (role != approvalRole && !forceApprovalRole[role]) return 0;
+    if (role != approvalRole && !forceRoles[role].forceApprovalRole) return 0;
     uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
-    return quantity > 0 && forceApprovalRole[role] ? type(uint128).max : quantity;
+    return quantity > 0 && forceRoles[role].forceApprovalRole ? type(uint128).max : quantity;
   }

   // -------- When Casting Disapproval --------
@@ -228,7 +238,7 @@ contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {
   /// @inheritdoc ILlamaStrategy
   function isDisapprovalEnabled(ActionInfo calldata, address, uint8 role) external view {
     if (minDisapprovalPct > ONE_HUNDRED_IN_BPS) revert DisapprovalDisabled();
-    if (role != disapprovalRole && !forceDisapprovalRole[role]) revert InvalidRole(disapprovalRole);
+    if (role != disapprovalRole && !forceRoles[role].forceDisapprovalRole) revert InvalidRole(disapprovalRole);
   }

   /// @inheritdoc ILlamaStrategy
@@ -237,9 +247,9 @@ contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {
     view
     returns (uint128)
   {
-    if (role != disapprovalRole && !forceDisapprovalRole[role]) return 0;
+    if (role != disapprovalRole && !forceRoles[role].forceDisapprovalRole) return 0;
     uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
-    return quantity > 0 && forceDisapprovalRole[role] ? type(uint128).max : quantity;
+    return quantity > 0 && forceRoles[role].forceDisapprovalRole ? type(uint128).max : quantity;
   }

   // -------- When Queueing --------
```

## [G-04] Cache calldata/memory pointers for complex types to avoid offset calculations
The function parameters in the following instances are complex types (i.e. arrays which contain structs) and thus will result in more complex offset calculations to retrieve specific data from calldata/memory. We can avoid peforming some of these offset calculations by instantiating calldata/memory pointers.

Total Instances: `2`

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L155-L159

*Gas Savings for `LlamaPolicy.deploy`, obtained via protocol's tests: Avg 484 gas*

|        |    Med   |    Max   |   Avg   | # calls  |
| ------ | -------- | -------- | ------- | -------- |
| Before |  5101157 |  5406425 | 5015882 |    412   |
| After  |  5101034 |  5256589 | 5015398 |    412   |

```solidity
File: src/LlamaPolicy.sol
155:    for (uint256 i = 0; i < roleHolders.length; i = LlamaUtils.uncheckedIncrement(i)) {
156:      _setRoleHolder(
157:        roleHolders[i].role, roleHolders[i].policyholder, roleHolders[i].quantity, roleHolders[i].expiration
158:      );
159:    }
```
```diff
diff --git a/src/LlamaPolicy.sol b/src/LlamaPolicy.sol
index 3fca63e..b46c68e 100644
--- a/src/LlamaPolicy.sol
+++ b/src/LlamaPolicy.sol
@@ -153,8 +153,9 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
     }

     for (uint256 i = 0; i < roleHolders.length; i = LlamaUtils.uncheckedIncrement(i)) {
+      RoleHolderData calldata roleHolder = roleHolders[i];
       _setRoleHolder(
-        roleHolders[i].role, roleHolders[i].policyholder, roleHolders[i].quantity, roleHolders[i].expiration
+        roleHolder.role, roleHolder.policyholder, roleHolder.quantity, roleHolder.expiration
       );
     }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L161-L163

*Gas Savings for `LlamaPolicy.deploy`, obtained via protocol's tests: Avg 708 gas*

|        |    Med   |    Max   |   Avg   | # calls  |
| ------ | -------- | -------- | ------- | -------- |
| Before |  5101157 |  5406425 | 5015882 |    412   |
| After  |  5101157 |  5116924 | 5015174 |    412   |

```solidity
File: src/LlamaPolicy.sol
161:    for (uint256 i = 0; i < rolePermissions.length; i = LlamaUtils.uncheckedIncrement(i)) {
162:      _setRolePermission(rolePermissions[i].role, rolePermissions[i].permissionId, rolePermissions[i].hasPermission);
163:    }
```
```diff
diff --git a/src/LlamaPolicy.sol b/src/LlamaPolicy.sol
index 3fca63e..c6df227 100644
--- a/src/LlamaPolicy.sol
+++ b/src/LlamaPolicy.sol
@@ -159,7 +159,8 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
     }

     for (uint256 i = 0; i < rolePermissions.length; i = LlamaUtils.uncheckedIncrement(i)) {
-      _setRolePermission(rolePermissions[i].role, rolePermissions[i].permissionId, rolePermissions[i].hasPermission);
+      RolePermissionData calldata rolePermission = rolePermissions[i];
+      _setRolePermission(rolePermission.role, rolePermission.permissionId, rolePermission.hasPermission);
     }
```

## [G-05] Forgo internal function to save 1 `STATICCALL` 
The `_context` internal function performs two external calls and returns both of the return values from those calls. Certain functions invoke `_context` but only use the return value from the first external call, thus performing an unnecessary extra external call. We can forgo using the internal function and instead only perform our desired external call to save 1 `STATICCALL (100 gas)`.

Total Instances: `4`

Estimated Gas Saved: `4 * 100 = 400`

https://github.com/code-423n4/2023-06-llama/blob/main/src/llama-scripts/LlamaGovernanceScript.sol#L111-L115

### Only perform `address(this).LLAMA_CORE()` to save 1 `STATICCALL`
```solidity
File: src/llama-scripts/LlamaGovernanceScript.sol
111:  function createNewStrategiesAndSetRoleHolders(
112:    CreateStrategies calldata _createStrategies,
113:    RoleHolderData[] calldata _setRoleHolders
114:  ) external onlyDelegateCall {
115:    (LlamaCore core,) = _context(); // @audit: return value from `core.policy()` is not being used
```
```diff
diff --git a/src/llama-scripts/LlamaGovernanceScript.sol b/src/llama-scripts/LlamaGovernanceScript.sol
index 820872e..f886bf7 100644
--- a/src/llama-scripts/LlamaGovernanceScript.sol
+++ b/src/llama-scripts/LlamaGovernanceScript.sol
@@ -112,7 +112,7 @@ contract LlamaGovernanceScript is LlamaBaseScript {
     CreateStrategies calldata _createStrategies,
     RoleHolderData[] calldata _setRoleHolders
   ) external onlyDelegateCall {
-    (LlamaCore core,) = _context();
+    LlamaCore core = LlamaCore(LlamaExecutor(address(this)).LLAMA_CORE());
     core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
     setRoleHolders(_setRoleHolders);
   }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/llama-scripts/LlamaGovernanceScript.sol#L120-L125

### Only perform `address(this).LLAMA_CORE()` to save 1 `STATICCALL` 
```solidity
File: src/llama-scripts/LlamaGovernanceScript.sol
120:  function createNewStrategiesAndInitializeRolesAndSetRoleHolders(
121:    CreateStrategies calldata _createStrategies,
122:    RoleDescription[] calldata description,
123:    RoleHolderData[] calldata _setRoleHolders
124:  ) external onlyDelegateCall {
125:    (LlamaCore core,) = _context(); // @audit: return value from `core.policy()` is not being used
```
```diff
diff --git a/src/llama-scripts/LlamaGovernanceScript.sol b/src/llama-scripts/LlamaGovernanceScript.sol
index 820872e..f886bf7 100644
--- a/src/llama-scripts/LlamaGovernanceScript.sol
+++ b/src/llama-scripts/LlamaGovernanceScript.sol
@@ -122,7 +122,7 @@ contract LlamaGovernanceScript is LlamaBaseScript {
     RoleDescription[] calldata description,
     RoleHolderData[] calldata _setRoleHolders
   ) external onlyDelegateCall {
-    (LlamaCore core,) = _context();
+    LlamaCore core = LlamaCore(LlamaExecutor(address(this)).LLAMA_CORE());
     core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
     initializeRoles(description);
     setRoleHolders(_setRoleHolders);
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/llama-scripts/LlamaGovernanceScript.sol#L131-L135

### Only perform `address(this).LLAMA_CORE()` to save 1 `STATICCALL`
```solidity
File: src/llama-scripts/LlamaGovernanceScript.sol
131:  function createNewStrategiesAndSetRolePermissions(
132:    CreateStrategies calldata _createStrategies,
133:    RolePermissionData[] calldata _setRolePermissions
134:  ) external onlyDelegateCall {
135:    (LlamaCore core,) = _context(); // @audit: return value from `core.policy()` is not being used
```
```diff
diff --git a/src/llama-scripts/LlamaGovernanceScript.sol b/src/llama-scripts/LlamaGovernanceScript.sol
index 820872e..f886bf7 100644
--- a/src/llama-scripts/LlamaGovernanceScript.sol
+++ b/src/llama-scripts/LlamaGovernanceScript.sol
@@ -132,7 +132,7 @@ contract LlamaGovernanceScript is LlamaBaseScript {
     CreateStrategies calldata _createStrategies,
     RolePermissionData[] calldata _setRolePermissions
   ) external onlyDelegateCall {
-    (LlamaCore core,) = _context();
+    LlamaCore core = LlamaCore(LlamaExecutor(address(this)).LLAMA_CORE());
     core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
     setRolePermissions(_setRolePermissions);
   }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/llama-scripts/LlamaGovernanceScript.sol#L140-L146

### Only perform `address(this).LLAMA_CORE()` to save 1 `STATICCALL` 
```solidity
File: src/llama-scripts/LlamaGovernanceScript.sol
140:  function createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissions(
141:    CreateStrategies calldata _createStrategies,
142:    RoleDescription[] calldata description,
143:    RoleHolderData[] calldata _setRoleHolders,
144:    RolePermissionData[] calldata _setRolePermissions
145:  ) external onlyDelegateCall {
146:    (LlamaCore core,) = _context(); // @audit: return value from `core.policy()` is not being used
```
```diff
diff --git a/src/llama-scripts/LlamaGovernanceScript.sol b/src/llama-scripts/LlamaGovernanceScript.sol
index 820872e..f886bf7 100644
--- a/src/llama-scripts/LlamaGovernanceScript.sol
+++ b/src/llama-scripts/LlamaGovernanceScript.sol
@@ -143,7 +143,7 @@ contract LlamaGovernanceScript is LlamaBaseScript {
     RoleHolderData[] calldata _setRoleHolders,
     RolePermissionData[] calldata _setRolePermissions
   ) external onlyDelegateCall {
-    (LlamaCore core,) = _context();
+    LlamaCore core = LlamaCore(LlamaExecutor(address(this)).LLAMA_CORE());
     core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
     initializeRoles(description);
     setRoleHolders(_setRoleHolders);
```

## [G-06] Multiple accesses of a mapping/array should use a local variable cache
Caching a mapping's value in a storage pointer when the value is accessed multiple times saves ~40 gas per access due to not having to perform the same offset calculation every time. Help the Optimizer by saving a storage variable's reference instead of repeatedly fetching it.

To achieve this, declare a storage pointer for the variable and use it instead of repeatedly fetching the reference in a map or an array. As an example, instead of repeatedly calling `stakes[tokenId_]`, save its reference via a storage pointer: `StakeInfo storage stakeInfo = stakes[tokenId_]` and use the pointer instead.

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L443-L448

*Gas Savings for `LlamaPolicy.revokePolicy`, obtained via protocol's tests: Avg 116 gas*

|        |    Med   |    Max   |   Avg   | # calls  |
| ------ | -------- | -------- | ------- | -------- |
| Before |   69040  |  110067  |  59837  |    11    |
| After  |   68916  |  109912  |  59721  |    11    |

```solidity
File: src/LlamaPolicy.sol
443:    uint128 initialQuantity = roleBalanceCkpts[tokenId][role].latest();
444:    bool hadRole = initialQuantity > 0;
445:    bool willHaveRole = quantity > 0;
446:
447:    // Now we update the policyholder's role balance checkpoint.
448:    roleBalanceCkpts[tokenId][role].push(willHaveRole ? quantity : 0, expiration);
```
```diff
diff --git a/src/LlamaPolicy.sol b/src/LlamaPolicy.sol
index 3fca63e..7674061 100644
--- a/src/LlamaPolicy.sol
+++ b/src/LlamaPolicy.sol
@@ -440,12 +440,13 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
     // checking if the quantity is nonzero, and we don't need to check the expiration when setting
     // the `hadRole` and `willHaveRole` variables.
     uint256 tokenId = _tokenId(policyholder);
-    uint128 initialQuantity = roleBalanceCkpts[tokenId][role].latest();
+    Checkpoints.History storage _roleBalanceCkpts = roleBalanceCkpts[tokenId][role];
+    uint128 initialQuantity = _roleBalanceCkpts.latest();
     bool hadRole = initialQuantity > 0;
     bool willHaveRole = quantity > 0;

     // Now we update the policyholder's role balance checkpoint.
-    roleBalanceCkpts[tokenId][role].push(willHaveRole ? quantity : 0, expiration);
+    _roleBalanceCkpts.push(willHaveRole ? quantity : 0, expiration);

     // If they don't hold a policy, we mint one for them. This means that even if you use 0 quantity
     // and 0 expiration, a policy is still minted even though they hold no roles. This is because
```

## [G-07] Refactor `If`/`require` statements to save SLOADs in case of early revert
Checks that involve calldata should come before checks that involve state variables, function calls, and calculations. By doing these checks first, the function is able to revert before using excessive gas in a call that may ultimately revert in an unhappy case.

Total Instances: `4`

https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsoluteQuorum.sol#L27-L35

The check in [line 35](https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsoluteQuorum.sol#L35) performs an SLOAD, while the check in [lines 32-33](https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsoluteQuorum.sol#L32-L33) perform an external call and two SLOADs. We can move the check in [line 35](https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsoluteQuorum.sol#L35) above [lines 32-33](https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsoluteQuorum.sol#L32-L33) to potentially save an SLOAD & External call in the unhappy path.

*Note: This view function is called in the state mutating `_createAction` function in `LlamaCore.sol`*
```solidity
File: src/strategies/LlamaAbsoluteQuorum.sol
27:  function validateActionCreation(ActionInfo calldata /* actionInfo */ ) external view override {
28:    LlamaPolicy llamaPolicy = policy; // Reduce SLOADs.
29:    uint256 approvalPolicySupply = llamaPolicy.getRoleSupplyAsQuantitySum(approvalRole);
30:    if (approvalPolicySupply == 0) revert RoleHasZeroSupply(approvalRole);
31:
32:    uint256 disapprovalPolicySupply = llamaPolicy.getRoleSupplyAsQuantitySum(disapprovalRole); // @audit: 1 SLOAD + External call
33:    if (disapprovalPolicySupply == 0) revert RoleHasZeroSupply(disapprovalRole); // @audit: 1 SLOAD
34:
35:    if (minApprovals > approvalPolicySupply) revert InsufficientApprovalQuantity(); // @audit: 1 SLOAD
```
```diff
diff --git a/src/strategies/LlamaAbsoluteQuorum.sol b/src/strategies/LlamaAbsoluteQuorum.sol
index 66130c0..aee2ce3 100644
--- a/src/strategies/LlamaAbsoluteQuorum.sol
+++ b/src/strategies/LlamaAbsoluteQuorum.sol
@@ -29,10 +29,11 @@ contract LlamaAbsoluteQuorum is LlamaAbsoluteStrategyBase {
     uint256 approvalPolicySupply = llamaPolicy.getRoleSupplyAsQuantitySum(approvalRole);
     if (approvalPolicySupply == 0) revert RoleHasZeroSupply(approvalRole);

+    if (minApprovals > approvalPolicySupply) revert InsufficientApprovalQuantity();
+
     uint256 disapprovalPolicySupply = llamaPolicy.getRoleSupplyAsQuantitySum(disapprovalRole);
     if (disapprovalPolicySupply == 0) revert RoleHasZeroSupply(disapprovalRole);

-    if (minApprovals > approvalPolicySupply) revert InsufficientApprovalQuantity();
     if (minDisapprovals != type(uint128).max && minDisapprovals > disapprovalPolicySupply) {
       revert InsufficientDisapprovalQuantity();
     }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsolutePeerReview.sol#L74-L82

The check in [line 79](https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsolutePeerReview.sol#L79) accesses storage, while the check in [line 80](https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsolutePeerReview.sol#L80) only accesses calldata. Move the check in [line 80](https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsolutePeerReview.sol#L80) above [line 79](https://github.com/code-423n4/2023-06-llama/blob/main/src/strategies/LlamaAbsolutePeerReview.sol#L79) to potentially save an SLOAD in the unhappy path.

*Note: This view function is called in the state mutating `_preCastAssertions` function in `LlamaCore.sol`*
```solidity
File: src/strategies/LlamaAbsolutePeerReview.sol
74:  function isDisapprovalEnabled(ActionInfo calldata actionInfo, address policyholder, uint8 role)
75:    external
76:    view
77:    override
78:  {
79:    if (minDisapprovals == type(uint128).max) revert DisapprovalDisabled(); // @audit: accesses storage
80:    if (actionInfo.creator == policyholder) revert ActionCreatorCannotCast(); // @audit: accesses calldata
81:    if (role != disapprovalRole && !forceDisapprovalRole[role]) revert InvalidRole(disapprovalRole);
82:  }
```
```diff
diff --git a/src/strategies/LlamaAbsolutePeerReview.sol b/src/strategies/LlamaAbsolutePeerReview.sol
index 85feb92..2df24ec 100644
--- a/src/strategies/LlamaAbsolutePeerReview.sol
+++ b/src/strategies/LlamaAbsolutePeerReview.sol
@@ -76,8 +76,9 @@ contract LlamaAbsolutePeerReview is LlamaAbsoluteStrategyBase {
     view
     override
   {
-    if (minDisapprovals == type(uint128).max) revert DisapprovalDisabled();
     if (actionInfo.creator == policyholder) revert ActionCreatorCannotCast();
+    if (minDisapprovals == type(uint128).max) revert DisapprovalDisabled();
     if (role != disapprovalRole && !forceDisapprovalRole[role]) revert InvalidRole(disapprovalRole);
   }
 }
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L412-L418

The check in [line 414](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L414) accesses storage, while the check in [line 418](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L418) only accesses a stack variable. Move the check in [line 418](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L418) above [line 414](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaPolicy.sol#L414) to potentially save 1 SLOAD on the unhappy path.

*Note: This view function is called within state mutating functions in `LlamaPolicy.sol`.*
```solidity
File: src/LlamaPolicy.sol
412:  function _assertValidRoleHolderUpdate(uint8 role, uint128 quantity, uint64 expiration) internal view {
413:    // Ensure role is initialized.
414:    if (role > numRoles) revert RoleNotInitialized(role); // @audit: accesses storage
415:
416:    // Cannot set the ALL_HOLDERS_ROLE because this is handled in the _mint / _burn methods and can
417:    // create duplicate entries if set here.
418:    if (role == ALL_HOLDERS_ROLE) revert AllHoldersRole(); // @audit: accesses stack variable
```
```diff
diff --git a/src/LlamaPolicy.sol b/src/LlamaPolicy.sol
index 3fca63e..443e74c 100644
--- a/src/LlamaPolicy.sol
+++ b/src/LlamaPolicy.sol
@@ -410,13 +410,13 @@ contract LlamaPolicy is ERC721NonTransferableMinimalProxy {

   /// @dev Checks if the conditions are met for a `role` to be updated.
   function _assertValidRoleHolderUpdate(uint8 role, uint128 quantity, uint64 expiration) internal view {
-    // Ensure role is initialized.
-    if (role > numRoles) revert RoleNotInitialized(role);
-
     // Cannot set the ALL_HOLDERS_ROLE because this is handled in the _mint / _burn methods and can
     // create duplicate entries if set here.
     if (role == ALL_HOLDERS_ROLE) revert AllHoldersRole();

+    // Ensure role is initialized.
+    if (role > numRoles) revert RoleNotInitialized(role);
+
     // An expiration of zero is only allowed if the role is being removed. Roles are removed when
     // the quantity is zero. In other words, the relationships that are required between the role
     // quantity and expiration fields are:
```

https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L317-L324

The check in [line 324](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L324) accesses calldata, the check in [line 323](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L323) accesses storage, and the check in [lines 320-322](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L320-L322) accesses storage at least once and potentially multiple times. To save at least one SLOAD in unhappy path, place the checks in the following order:

1. Check in [line 324](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L324)
2. Check in [line 323](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L323)
3. Check in [lines 320-322](https://github.com/code-423n4/2023-06-llama/blob/main/src/LlamaCore.sol#L320-L322)

```solidity
File: src/LlamaCore.sol
317:  function executeAction(ActionInfo calldata actionInfo) external payable {
318:    // Initial checks that action is ready to execute.
319:    Action storage action = actions[actionInfo.id];
320:    ActionState currentState = getActionState(actionInfo); // @audit: accesses storage (at least 1 SLOAD, potentially more)
321:
322:    if (currentState != ActionState.Queued) revert InvalidActionState(currentState); // @audit: depends on line 320
323:    if (block.timestamp < action.minExecutionTime) revert MinExecutionTimeNotReached(); // @audit: accesses storage (1 SLOAD)
324:    if (msg.value != actionInfo.value) revert IncorrectMsgValue(); // @audit: accesses calldata
```
```diff
diff --git a/src/LlamaCore.sol b/src/LlamaCore.sol
index 89d60de..594e9f4 100644
--- a/src/LlamaCore.sol
+++ b/src/LlamaCore.sol
@@ -316,12 +316,13 @@ contract LlamaCore is Initializable {
   /// @param actionInfo Data required to create an action.
   function executeAction(ActionInfo calldata actionInfo) external payable {
     // Initial checks that action is ready to execute.
+    if (msg.value != actionInfo.value) revert IncorrectMsgValue();
+
     Action storage action = actions[actionInfo.id];
-    ActionState currentState = getActionState(actionInfo);
+    if (block.timestamp < action.minExecutionTime) revert MinExecutionTimeNotReached();

+    ActionState currentState = getActionState(actionInfo);
     if (currentState != ActionState.Queued) revert InvalidActionState(currentState);
-    if (block.timestamp < action.minExecutionTime) revert MinExecutionTimeNotReached();
-    if (msg.value != actionInfo.value) revert IncorrectMsgValue();

     action.executed = true;
```


***


# Audit Analysis

For this audit, 13 analysis reports were submitted by wardens. An analysis report examines the codebase as a whole, providing observations and advice on such topics as architecture, mechanism, or approach. The [report highlighted below](https://github.com/code-423n4/2023-06-llama-findings/issues/101) by **0xnev** received the top score from the judge.

*The following wardens also submitted reports: [peanuts](https://github.com/code-423n4/2023-06-llama-findings/issues/291), 
[dirk\_y](https://github.com/code-423n4/2023-06-llama-findings/issues/279), 
[0xSmartContract](https://github.com/code-423n4/2023-06-llama-findings/issues/268), 
[joestakey](https://github.com/code-423n4/2023-06-llama-findings/issues/251), 
[libratus](https://github.com/code-423n4/2023-06-llama-findings/issues/250), 
[QiuhaoLi](https://github.com/code-423n4/2023-06-llama-findings/issues/211), 
[K42](https://github.com/code-423n4/2023-06-llama-findings/issues/192), 
[ktg](https://github.com/code-423n4/2023-06-llama-findings/issues/186), 
[mahdirostami](https://github.com/code-423n4/2023-06-llama-findings/issues/170), 
[kutugu](https://github.com/code-423n4/2023-06-llama-findings/issues/169), 
[xuwinnie](https://github.com/code-423n4/2023-06-llama-findings/issues/167), 
[neko\_nyaa](https://github.com/code-423n4/2023-06-llama-findings/issues/159), and
[VictoryGod](https://github.com/code-423n4/2023-06-llama-findings/issues/88)
.*

## 1. Analysis of Codebase 
The Llama governance system provides a unique way for protocol to leverage policies (represented by a non-transferable NFT) to permission action creation till execution. It primarily focuses on 2 mechanisms, Action creation and policy management. To summarize the protocol, here is a step-by-step flow:

1. Protocol owners give policy and set roles (via `_setRoleHolder()`)
2. Protocol owner set permissions (via `_setRolePermissions()`)
3. Permissioned policy holders can create actions (via `createAction/createActionBySig`)
4. Strategy and custom guards validate action creation, if passes action can be queued (via Strategy and Guard function `validateActionCreation()`)
5. Policy holders with approval/disapproval cast votes during approval period (via `castApproval()/castDisapproval()`)
6. Strategies validate approval/disapproval against minimum thresholds `via isActionApproved()/isActionDisapproved()`
7. If approved and meets minimum execution time and action is not expired, action can now be executed, if not action is canceled

## 2. Architecture Improvements
The following architecture improvements and feedback could be considered:

### 2.1 Incorporate ERC20 tokens for action execution that requires value
Could consider incorporating payment of action execution with common ERC-20 tokens (USDC, USDT, BNB ...). The tokens incorporated can be whitelisted to prevent ERC-20 tokens with other caveats from interacting with protocol until support is implemented (e.g. rebasing, fee-on-transfer)

### 2.2 Create a new type of strategy for flexibility
Could consider creating a new type of Llama strategy in which approval/disapproval thresholds are specified as percentages of total supply and action creators are not allowed to cast approvals or disapprovals on their own actions for more flexibility

### 2.3 Checkpoints contracts are deprecated by OpenZeppelin
Checkpoint contracts seems to be deprecated by OpenZeppelin, not sure how this affects Llama contracts but since it affects core parts of the contract logic such as retrieving `quantity` and `expiration` data of roles, it might be worth noting.

### 2.4 Consider changing `quantity` check logic
Consider changing logic for action creation and checks for role before action creation. Protocol owners cannot set role with 0 quantity coupled with an expiration due to checks in `_assertValidRoleHolderUpdate()`. 

Only the `approvalRole` is required to have quantity. All other roles that do not have approval power but have `quantity` assigned to them will only incur unecessary computation.

Based on current implementation of `_setRoleHolder`, protocol owners can never give a policyholder a role with an expiry with no quantity that represents approval/disapproval casting power. In the event where protocol owner wants to give policyholder a role that has 0 `quantity` of votes, they can never do so. 

Furthermore, `hasPermissionId()` also checks for quantity  before allowing creation of actions. This means policyholders can only create actions if some `quantity` of approval/disapproval votes is assigned to them. Sementically, I don't think the quantity used for voting has relation to action creation.

Although that particular policy holder cannot vote unless `approvalRole /disapprovalRole` is assigned to them, it can cause confusion where policy holders might think they can vote since some `quantity` is assigned to them.

The following adjustments can be made:

- You could consider adding a third case in `_assertValidRoleHolderUpdate()` such as the following:
```solidity
case3 = quantity == 0 && expiration > block.timestamp;
```
- Remove `quantity > 0` check in `LlamaPolicy.hasPermissionId()` to allow action creators to create roles even when no quantity is assigned to them, since permissions to create actions are required to be set for policy holders via `setRolePermissions()` anyway. 
- `hasRole()` can simply check for expiration to determine if policy holder has role
- A separate `hasCastRole()` can be created to specifically check for approval/disapproval Role

This way, `quantity` will only ever need to be assigned to policyholders assigned with the approval/disapproval role.

### 2.5 No actual way to access role descriptions via mapping

In the `policy-management.md` doc it states that:
> When roles are created, a description is provided. This description serves as the plaintext mapping from description to role ID, and provides semantic meaning to an otherwise meaningless unsigned integer. 

However, there is no actual way to access roleId via role descriptions in contract. Policy holders cannot access role descriptions and roleIds convieniently except via protocol UI.

Hence, protocol could consider adding a new mapping to map roleIds to description and add logic to return role description and Id in `LlamaPolicy.updateRoleDescriptions()`. 

### 2.6 Consider increasing number of unique roles

Since Id 0 is reserved for the bootstrap `ALL_HOLDERS_ROLE`, the protocol owner could infact only have 254 unique roles.
So it may be good to consider using `uint16` to allow 65534 unique roles. 

## 3. Centralization risks

### 3.1 Policy holders with forceApproval/forceDisapproval role can force approvals and disapproval
Policy holders will approval/disapproval role and quantity of `type(uint128).max `can force approval/disapproval of actions via `forceApprovalRole/forceDisapproval` mapping.

### 3.2 Protocol owners can revoke roles of policyholders anytime
Protocol owners can revoke policyholders anytime via `LlamaPolicy.revokePolicy()` and prevent action creation/queuing/execution and approval/disapproval. It should be noted that as long as action is created, that action can be executed regardless policyholder is revoked or not, unless action is explicitly cancelled or disapproved.

### 3.3 Any guards can be set for actions before execution
The type of guards can be customized by protocol owners, so at any point of time specific guards can be set for specific action based on data input (selector) and possibly unfairly prevent execution of action via `LlamaCore.setGuard()`.

## 4. Time Spent
A total of 4 days were spent to cover this audit, broken down into the following:
- 1st Day: Understand protocol docs, action creation flow and policy management
- 2nd Day: Focus on linking docs logic to `LLamaCore.sol` and `LlamaPolicy.sol`, coupled with typing reports for vulnerabilities found
- 3rd Day: Focus on different types of strategies contract coupled with typing reports for vulnerabilities found
- 4th Day: Sum up audit by completing QA report and Analysis

### Time spent:
96 hours

***


# Disclosures

C4 is an open organization governed by participants in the community.

C4 audits incentivize the discovery of exploits, vulnerabilities, and bugs in smart contracts. Security researchers are rewarded at an increasing rate for finding higher-risk issues. Audit submissions are judged by a knowledgeable security researcher and solidity developer and disclosed to sponsoring developers. C4 does not conduct formal verification regarding the provided code but instead provides final verification.

C4 does not provide any guarantee or warranty regarding the security of this project. All smart contract software should be used at the sole risk and responsibility of users.