// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {MockProtocol} from "test/mock/MockProtocol.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaRelativeQuorum} from "src/strategies/LlamaRelativeQuorum.sol";
import {LlamaRelativeStrategyBase} from "src/strategies/LlamaRelativeStrategyBase.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

import {LlamaRelativeStrategyBaseTest} from "test/strategies/LlamaRelativeStrategyBase.t.sol";

contract LlamaRelativeQuorumTest is LlamaRelativeStrategyBaseTest {
  function deployRelativeQuorumAndSetRole(
    uint8 _role,
    bytes32 _permission,
    address _policyHolder,
    uint64 _queuingDuration,
    uint64 _expirationDelay,
    uint64 _approvalPeriod,
    bool _isFixedLengthApprovalPeriod,
    uint16 _minApprovalPct,
    uint16 _minDisapprovalPct,
    uint8[] memory _forceApprovalRoles,
    uint8[] memory _forceDisapprovalRoles
  ) internal returns (ILlamaStrategy newStrategy) {
    {
      // Initialize roles if required.
      initializeRolesUpTo(maxRole(_role, _forceApprovalRoles, _forceDisapprovalRoles));

      vm.prank(address(mpExecutor));
      mpPolicy.setRoleHolder(_role, _policyHolder, 1, type(uint64).max);
      vm.prank(address(mpExecutor));
      mpPolicy.setRolePermission(_role, _permission, true);
    }

    LlamaRelativeStrategyBase.Config memory strategyConfig = LlamaRelativeStrategyBase.Config({
      approvalPeriod: _approvalPeriod,
      queuingPeriod: _queuingDuration,
      expirationPeriod: _expirationDelay,
      isFixedLengthApprovalPeriod: _isFixedLengthApprovalPeriod,
      minApprovalPct: _minApprovalPct,
      minDisapprovalPct: _minDisapprovalPct,
      approvalRole: _role,
      disapprovalRole: _role,
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    LlamaRelativeStrategyBase.Config[] memory strategyConfigs = new LlamaRelativeStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    vm.expectEmit();
    emit StrategyCreated(mpCore, mpPolicy);

    mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

    newStrategy = lens.computeLlamaStrategyAddress(
      address(relativeQuorumLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
    );
  }

  function deployTestStrategy() internal returns (ILlamaStrategy testStrategy) {
    LlamaRelativeStrategyBase.Config memory testStrategyData = LlamaRelativeStrategyBase.Config({
      approvalPeriod: 1 days,
      queuingPeriod: 2 days,
      expirationPeriod: 8 days,
      isFixedLengthApprovalPeriod: true,
      minApprovalPct: 4000,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.TestRole1),
      disapprovalRole: uint8(Roles.TestRole1),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });
    testStrategy = lens.computeLlamaStrategyAddress(
      address(relativeQuorumLogic), DeployUtils.encodeStrategy(testStrategyData), address(mpCore)
    );
    LlamaRelativeStrategyBase.Config[] memory testStrategies = new LlamaRelativeStrategyBase.Config[](1);
    testStrategies[0] = testStrategyData;
    vm.prank(address(mpExecutor));
    mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(testStrategies));
  }

  function deployRelativeQuorumWithForceApproval() internal returns (ILlamaStrategy testStrategy) {
    // Define strategy parameters.
    uint8[] memory forceApproveRoles = new uint8[](1);
    forceApproveRoles[0] = uint8(Roles.ForceApprover);
    uint8[] memory forceDisapproveRoles = new uint8[](1);
    forceDisapproveRoles[0] = uint8(Roles.ForceDisapprover);

    LlamaRelativeStrategyBase.Config memory testStrategyData = LlamaRelativeStrategyBase.Config({
      approvalPeriod: 1 days,
      queuingPeriod: 2 days,
      expirationPeriod: 8 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 4000,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.TestRole1),
      disapprovalRole: uint8(Roles.TestRole1),
      forceApprovalRoles: forceApproveRoles,
      forceDisapprovalRoles: forceDisapproveRoles
    });

    // Get the address of the strategy we'll deploy.
    testStrategy = lens.computeLlamaStrategyAddress(
      address(relativeQuorumLogic), DeployUtils.encodeStrategy(testStrategyData), address(mpCore)
    );

    // Create and authorize the strategy.
    LlamaRelativeStrategyBase.Config[] memory testStrategies = new LlamaRelativeStrategyBase.Config[](1);
    testStrategies[0] = testStrategyData;
    vm.prank(address(mpExecutor));
    mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(testStrategies));

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.ForceApprover), address(approverAdam), 1, type(uint64).max);
  }
}

contract IsActionApproved is LlamaRelativeQuorumTest {
  function testFuzz_ReturnsTrueForPassedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals =
      bound(_actionApprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000), _numberOfPolicies);

    ILlamaStrategy testStrategy = deployTestStrategy();

    generateAndSetRoleHolders(_numberOfPolicies);

    ActionInfo memory actionInfo = createAction(testStrategy);

    approveAction(_actionApprovals, actionInfo);

    bool _isActionApproved = testStrategy.isActionApproved(actionInfo);

    assertEq(_isActionApproved, true);
  }

  function testFuzz_ReturnsFalseForFailedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals = bound(_actionApprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000) - 1);

    ILlamaStrategy testStrategy = deployTestStrategy();

    generateAndSetRoleHolders(_numberOfPolicies);

    ActionInfo memory actionInfo = createAction(testStrategy);

    approveAction(_actionApprovals, actionInfo);

    bool _isActionApproved = testStrategy.isActionApproved(actionInfo);

    assertEq(_isActionApproved, false);
  }

  function testFuzz_RevertForNonExistentActionId(ActionInfo calldata actionInfo) public {
    vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
    vm.prank(address(approverAdam));
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
  }
}

contract GetApprovalQuantityAt is LlamaRelativeQuorumTest {
  function testFuzz_ReturnsZeroQuantityPriorToAccountGainingPermission(
    uint256 _timeUntilPermission,
    uint8 _role,
    bytes32 _permission,
    address _policyHolder
  ) public {
    vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    vm.warp(_timeUntilPermission);

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    assertEq(
      newStrategy.getApprovalQuantityAt(_policyHolder, _role, _referenceTime),
      0 // there should be zero quantity before permission was granted
    );
  }

  function testFuzz_ReturnsQuantityAfterBlockThatAccountGainedPermission(
    uint256 _timeSincePermission, // no assume for this param, we want 0 tested
    bytes32 _permission,
    uint8 _role,
    address _policyHolder
  ) public {
    vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );
    vm.warp(_timeSincePermission);
    assertEq(
      newStrategy.getApprovalQuantityAt(
        _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
      ),
      1 // the account should still have the quantity
    );
  }

  function testFuzz_ReturnsZeroQuantityForNonPolicyHolders(uint64 _timestamp, uint8 _role, address _nonPolicyHolder)
    public
  {
    _timestamp = uint64(bound(_timestamp, block.timestamp + 1, type(uint64).max));
    vm.assume(_nonPolicyHolder != address(0));
    vm.assume(_nonPolicyHolder != address(0xdeadbeef)); // Given a policy below.
    vm.assume(mpPolicy.balanceOf(_nonPolicyHolder) == 0);
    vm.assume(_role != 0);

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      _role,
      bytes32(0),
      address(0xdeadbeef),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new
      uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getApprovalQuantityAt(_nonPolicyHolder, _role, _timestamp - 1),
      0 // the account should not have a quantity
    );
  }

  function testFuzz_ReturnsDefaultQuantityForPolicyHolderWithoutExplicitQuantity(
    uint256 _timestamp,
    uint8 _role,
    address _policyHolder
  ) public {
    _timestamp = bound(_timestamp, block.timestamp - 1, type(uint64).max);
    _role = uint8(bound(_role, 8, 255)); // ignoring all roles in the test setup to avoid conflicts with pre-assigned
      // roles
    vm.assume(_policyHolder != address(0));

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      _policyHolder,
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getApprovalQuantityAt(_policyHolder, _role, _timestamp - 1),
      0 // the account should not have a quantity
    );
  }

  function testFuzz_ReturnsZeroForNonApprovalRoles(uint8 _role, address _policyHolder, uint128 _quantity) public {
    _role = uint8(bound(_role, 1, 8)); // only using roles in the test setup to avoid having to create new roles
    vm.assume(_role != uint8(Roles.TestRole1));
    vm.assume(_policyHolder != address(0));
    vm.assume(mpPolicy.balanceOf(_policyHolder) == 0);
    _quantity = uint128(bound(_quantity, 1, type(uint128).max - mpPolicy.getRoleSupplyAsQuantitySum(_role)));

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(0xdeadbeef),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(_role, _policyHolder, _quantity, type(uint64).max);

    assertEq(newStrategy.getApprovalQuantityAt(address(0xdeadbeef), uint8(Roles.TestRole2), block.timestamp), 0);
  }
}

contract GetDisapprovalQuantityAt is LlamaRelativeQuorumTest {
  function testFuzz_ReturnsZeroQuantityPriorToAccountGainingPermission(
    uint256 _timeUntilPermission,
    bytes32 _permission,
    uint8 _role,
    address _policyHolder
  ) public {
    vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    vm.warp(_timeUntilPermission);

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    assertEq(
      newStrategy.getDisapprovalQuantityAt(_policyHolder, _role, _referenceTime),
      0 // there should be zero quantity before permission was granted
    );
  }

  function testFuzz_ReturnsQuantityAfterBlockThatAccountGainedPermission(
    uint256 _timeSincePermission, // no assume for this param, we want 0 tested
    bytes32 _permission,
    uint8 _role,
    address _policyHolder
  ) public {
    vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );
    vm.warp(_timeSincePermission);
    assertEq(
      newStrategy.getDisapprovalQuantityAt(
        _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
      ),
      1 // the account should still have the quantity
    );
  }

  function testFuzz_ReturnsZeroQuantityForNonPolicyHolders(uint256 _timestamp, uint8 _role, address _nonPolicyHolder)
    public
  {
    vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
    vm.assume(_nonPolicyHolder != address(0));
    vm.assume(_nonPolicyHolder != address(0xdeadbeef)); // Given a policy below.
    vm.assume(mpPolicy.balanceOf(_nonPolicyHolder) == 0);
    vm.assume(_role != 0);

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      _role,
      bytes32(0),
      address(0xdeadbeef),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new
      uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getDisapprovalQuantityAt(_nonPolicyHolder, _role, _timestamp - 1),
      0 // the account should not have a quantity
    );
  }

  function testFuzz_ReturnsDefaultQuantityForPolicyHolderWithoutExplicitQuantity(
    uint256 _timestamp,
    uint8 _role,
    address _policyHolder
  ) public {
    _timestamp = bound(_timestamp, block.timestamp - 1, type(uint64).max);
    _role = uint8(bound(_role, 8, 255)); // ignoring all roles in the test setup to avoid conflicts with pre-assigned
      // roles
    vm.assume(_policyHolder != address(0));

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      _policyHolder,
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getDisapprovalQuantityAt(_policyHolder, _role, _timestamp - 1),
      0 // the account should not have a quantity
    );
  }

  function testFuzz_ReturnsZeroForNonApprovalRoles(uint8 _role, address _policyHolder, uint128 _quantity) public {
    _role = uint8(bound(_role, 1, 8)); // ignoring all roles in the test setup to avoid conflicts with pre-assigned
      // roles
    vm.assume(_role != uint8(Roles.TestRole1));
    vm.assume(_policyHolder != address(0));
    vm.assume(mpPolicy.balanceOf(_policyHolder) == 0);
    _quantity = uint128(bound(_quantity, 1, type(uint128).max - mpPolicy.getRoleSupplyAsQuantitySum(_role)));

    ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(0xdeadbeef),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(_role, _policyHolder, _quantity, type(uint64).max);

    assertEq(newStrategy.getDisapprovalQuantityAt(address(0xdeadbeef), uint8(Roles.TestRole2), block.timestamp), 0);
  }
}

contract RelativeQuorumHarness is LlamaRelativeQuorum {
  function exposed_getMinimumAmountNeeded(uint256 supply, uint256 minPct) external pure returns (uint256) {
    return _getMinimumAmountNeeded(supply, minPct);
  }
}

contract ValidateActionCreation is LlamaRelativeQuorumTest {
  function test_CalculateSupplyWhenActionCreatorDoesNotHaveRole(uint256 _numberOfPolicies) external {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);

    ILlamaStrategy testStrategy = deployTestStrategy();

    generateAndSetRoleHolders(_numberOfPolicies);

    ActionInfo memory actionInfo = createAction(testStrategy);

    assertEq(LlamaRelativeQuorum(address(testStrategy)).actionApprovalSupply(actionInfo.id), _numberOfPolicies);
    assertEq(LlamaRelativeQuorum(address(testStrategy)).actionDisapprovalSupply(actionInfo.id), _numberOfPolicies);
  }

  function test_OnlyLlamaCoreCanValidate(uint256 _numberOfPolicies) external {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    ILlamaStrategy testStrategy = deployTestStrategy();
    generateAndSetRoleHolders(_numberOfPolicies);
    ActionInfo memory actionInfo = createAction(testStrategy);

    vm.expectRevert(LlamaRelativeStrategyBase.OnlyLlamaCore.selector);
    LlamaRelativeQuorum(address(testStrategy)).validateActionCreation(actionInfo);
  }

  function test_CalculateSupplyWhenActionCreatorHasRole(uint256 _numberOfPolicies, uint256 _creatorQuantity) external
{
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _creatorQuantity = bound(_creatorQuantity, 1, 1000);

    ILlamaStrategy testStrategy = deployTestStrategy();

    generateAndSetRoleHolders(_numberOfPolicies);

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), actionCreatorAaron, uint128(_creatorQuantity), type(uint64).max);

    uint256 supply = mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1));

    ActionInfo memory actionInfo = createAction(testStrategy);

    assertEq(LlamaRelativeQuorum(address(testStrategy)).actionApprovalSupply(actionInfo.id), supply);
    assertEq(LlamaRelativeQuorum(address(testStrategy)).actionDisapprovalSupply(actionInfo.id), supply);
  }
}

contract ValidateActionCancelation is LlamaRelativeQuorumTest {
  function testFuzz_RevertIf_ActionNotFullyDisapprovedAndCallerIsNotCreator(
    uint256 _actionDisapprovals,
    uint256 _numberOfPolicies
  ) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) - 1);

    ILlamaStrategy testStrategy = deployRelativeQuorumWithForceApproval();

    generateAndSetRoleHolders(_numberOfPolicies);

    ActionInfo memory actionInfo = createAction(testStrategy);

    vm.prank(address(approverAdam));
    mpCore.castApproval(uint8(Roles.ForceApprover), actionInfo, "");

    mpCore.queueAction(actionInfo);

    disapproveAction(_actionDisapprovals, actionInfo);
    assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));

    vm.expectRevert(LlamaRelativeStrategyBase.OnlyActionCreator.selector);
    testStrategy.validateActionCancelation(actionInfo, address(this));
  }

  function testFuzz_NoRevertIf_ActionNotFullyDisapprovedAndCallerIsNotCreator(
    uint256 _actionDisapprovals,
    uint256 _numberOfPolicies
  ) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) - 1);

    ILlamaStrategy testStrategy = deployRelativeQuorumWithForceApproval();

    generateAndSetRoleHolders(_numberOfPolicies);

    ActionInfo memory actionInfo = createAction(testStrategy);

    mpCore.queueAction(actionInfo);

    console2.logUint(uint(mpCore.getActionState(actionInfo)));
    disapproveAction(_actionDisapprovals, actionInfo);
    assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));

    testStrategy.validateActionCancelation(actionInfo, actionInfo.creator); // This should not revert.
  }
}
