// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {MockLlamaRelativeStrategyBase} from "test/mock/MockLlamaRelativeStrategyBase.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaRelativeStrategyBase} from "src/strategies/LlamaRelativeStrategyBase.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaRelativeStrategyBaseTest is LlamaTestSetup {
  event StrategyCreated(LlamaCore llama, LlamaPolicy policy);
  event ApprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);

  MockLlamaRelativeStrategyBase mockLlamaRelativeStrategyBaseLogic;

  function setUp() public virtual override {
    LlamaTestSetup.setUp();

    mockLlamaRelativeStrategyBaseLogic = new MockLlamaRelativeStrategyBase();

    vm.prank(address(mpExecutor));
    mpCore.setStrategyLogicAuthorization(mockLlamaRelativeStrategyBaseLogic, true);
  }

  function deployRelativeBaseAndSetRole(
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

    mpCore.createStrategies(mockLlamaRelativeStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

    newStrategy = lens.computeLlamaStrategyAddress(
      address(mockLlamaRelativeStrategyBaseLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
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
      address(mockLlamaRelativeStrategyBaseLogic), DeployUtils.encodeStrategy(testStrategyData), address(mpCore)
    );
    LlamaRelativeStrategyBase.Config[] memory testStrategies = new LlamaRelativeStrategyBase.Config[](1);
    testStrategies[0] = testStrategyData;
    vm.prank(address(mpExecutor));
    mpCore.createStrategies(mockLlamaRelativeStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(testStrategies));
  }

  function deployRelativeBaseWithForceApproval() internal returns (ILlamaStrategy testStrategy) {
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
      address(mockLlamaRelativeStrategyBaseLogic), DeployUtils.encodeStrategy(testStrategyData), address(mpCore)
    );

    // Create and authorize the strategy.
    LlamaRelativeStrategyBase.Config[] memory testStrategies = new LlamaRelativeStrategyBase.Config[](1);
    testStrategies[0] = testStrategyData;
    vm.prank(address(mpExecutor));
    mpCore.createStrategies(mockLlamaRelativeStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(testStrategies));

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.ForceApprover), address(approverAdam), 1, type(uint64).max);
  }
}

contract Constructor is LlamaRelativeStrategyBaseTest {
  function test_DisablesInitializationAtConstruction() public {
    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mockLlamaRelativeStrategyBaseLogic.initialize(bytes(""));
  }
}

contract Initialize is LlamaRelativeStrategyBaseTest {
  function testFuzz_SetsStrategyStorageQueuingDuration(uint64 _queuingDuration) public {
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      _queuingDuration,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategyBase(newStrategy).queuingPeriod(), _queuingDuration);
  }

  function testFuzz_SetsStrategyStorageExpirationDelay(uint64 _expirationDelay) public {
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      _expirationDelay,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategyBase(newStrategy).expirationPeriod(), _expirationDelay);
  }

  function test_SetsStrategyStorageIsFixedLengthApprovalPeriod(bool _isFixedLengthApprovalPeriod) public {
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      _isFixedLengthApprovalPeriod,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategyBase(newStrategy).isFixedLengthApprovalPeriod(), _isFixedLengthApprovalPeriod);
  }

  function testFuzz_SetsStrategyStorageApprovalPeriod(uint64 _approvalPeriod) public {
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      _approvalPeriod,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategyBase(newStrategy).approvalPeriod(), _approvalPeriod);
  }

  function test_SetsStrategyStoragePolicy() public {
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(address(newStrategy.policy()), address(mpPolicy));
  }

  function test_SetsStrategyStorageLlama() public {
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(address(newStrategy.llamaCore()), address(mpCore));
  }

  function testFuzz_SetsStrategyStorageMinApprovalPct(uint256 _percent) public {
    _percent = bound(_percent, 0, 10_000);
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      toUint16(_percent),
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategyBase(newStrategy).minApprovalPct(), _percent);
  }

  function testFuzz_SetsStrategyStorageMinDisapprovalPct(uint16 _percent) public {
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      _percent,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategyBase(newStrategy).minDisapprovalPct(), _percent);
  }

  function testFuzz_SetsForceApprovalRoles(uint8[] memory forceApprovalRoles) public {
    for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
      // 0 = All Holders Role, which will revert if set as force role
      if (forceApprovalRoles[i] == 0) forceApprovalRoles[i] = 1;
    }
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      forceApprovalRoles,
      new uint8[](0)
    );
    for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
      assertEq(toRelativeStrategyBase(newStrategy).forceApprovalRole(forceApprovalRoles[i]), true);
    }
  }

  function testFuzz_SetsForceDisapprovalRoles(uint8[] memory forceDisapprovalRoles) public {
    for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
      // 0 = All Holders Role, which will revert if set as force role
      if (forceDisapprovalRoles[i] == 0) forceDisapprovalRoles[i] = 1;
    }
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      forceDisapprovalRoles
    );
    for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
      assertEq(toRelativeStrategyBase(newStrategy).forceDisapprovalRole(forceDisapprovalRoles[i]), true);
    }
  }

  function testFuzz_HandlesDuplicateApprovalRoles(uint8 _role) public {
    _role = uint8(bound(_role, 1, type(uint8).max));
    uint8[] memory forceApprovalRoles = new uint8[](2);
    forceApprovalRoles[0] = _role;
    forceApprovalRoles[1] = _role;
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      forceApprovalRoles,
      new uint8[](0)
    );
    assertEq(toRelativeStrategyBase(newStrategy).forceApprovalRole(_role), true);
  }

  function testFuzz_HandlesDuplicateDisapprovalRoles(uint8 _role) public {
    _role = uint8(bound(_role, 1, type(uint8).max));
    uint8[] memory forceDisapprovalRoles = new uint8[](2);
    forceDisapprovalRoles[0] = _role;
    forceDisapprovalRoles[1] = _role;
    ILlamaStrategy newStrategy = deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      forceDisapprovalRoles
    );
    assertEq(toRelativeStrategyBase(newStrategy).forceDisapprovalRole(_role), true);
  }

  function testFuzz_EmitsStrategyCreatedEvent( /*TODO fuzz this test */ ) public {
    deployRelativeBaseAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
  }

  function test_RevertIf_SetAllHoldersRoleAsForceApprovalRole() public {
    uint8[] memory _forceApprovalRoles = new uint8[](1);
    _forceApprovalRoles[0] = uint8(Roles.AllHolders);
    LlamaRelativeStrategyBase.Config memory strategyConfig = LlamaRelativeStrategyBase.Config({
      approvalPeriod: 1 days,
      queuingPeriod: 1 days,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 5000,
      minDisapprovalPct: 5000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: new uint8[](0)
    });

    LlamaRelativeStrategyBase.Config[] memory strategyConfigs = new LlamaRelativeStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    vm.expectRevert(abi.encodeWithSelector(LlamaRelativeStrategyBase.InvalidRole.selector, uint8(Roles.AllHolders)));
    mpCore.createStrategies(mockLlamaRelativeStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
  }

  function test_RevertIf_SetAllHoldersRoleAsForceDisapprovalRole() public {
    uint8[] memory _forceDisapprovalRoles = new uint8[](1);
    _forceDisapprovalRoles[0] = uint8(Roles.AllHolders);
    LlamaRelativeStrategyBase.Config memory strategyConfig = LlamaRelativeStrategyBase.Config({
      approvalPeriod: 1 days,
      queuingPeriod: 1 days,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 5000,
      minDisapprovalPct: 5000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    LlamaRelativeStrategyBase.Config[] memory strategyConfigs = new LlamaRelativeStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    vm.expectRevert(abi.encodeWithSelector(LlamaRelativeStrategyBase.InvalidRole.selector, uint8(Roles.AllHolders)));
    mpCore.createStrategies(mockLlamaRelativeStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
  }

  function testFuzz_RevertIf_MinApprovalPctIsGreaterThan100(uint16 minApprovalPct) public {
    minApprovalPct = uint16(bound(minApprovalPct, 10_001, type(uint16).max));
    LlamaRelativeStrategyBase.Config memory strategyConfig = LlamaRelativeStrategyBase.Config({
      approvalPeriod: 1 days,
      queuingPeriod: 1 days,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: minApprovalPct,
      minDisapprovalPct: 5000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    LlamaRelativeStrategyBase.Config[] memory strategyConfigs = new LlamaRelativeStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    vm.expectRevert(abi.encodeWithSelector(LlamaRelativeStrategyBase.InvalidMinApprovalPct.selector, minApprovalPct));
    mpCore.createStrategies(mockLlamaRelativeStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
  }
}

contract IsActionApproved is LlamaRelativeStrategyBaseTest {
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

contract ValidateActionCancelation is LlamaRelativeStrategyBaseTest {
  function testFuzz_RevertIf_ActionNotFullyDisapprovedAndCallerIsNotCreator(
    uint256 _actionDisapprovals,
    uint256 _numberOfPolicies
  ) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) - 1);

    ILlamaStrategy testStrategy = deployRelativeBaseWithForceApproval();

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

    ILlamaStrategy testStrategy = deployRelativeBaseWithForceApproval();

    generateAndSetRoleHolders(_numberOfPolicies);

    ActionInfo memory actionInfo = createAction(testStrategy);

    vm.prank(address(approverAdam));
    mpCore.castApproval(uint8(Roles.ForceApprover), actionInfo, "");

    mpCore.queueAction(actionInfo);

    disapproveAction(_actionDisapprovals, actionInfo);
    assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));

    testStrategy.validateActionCancelation(actionInfo, actionInfo.creator); // This should not revert.
  }
}

contract RelativeQuorumHarness is MockLlamaRelativeStrategyBase {
  function exposed_getMinimumAmountNeeded(uint256 supply, uint256 minPct) external pure returns (uint256) {
    return _getMinimumAmountNeeded(supply, minPct);
  }
}

contract GetMinimumAmountNeeded is LlamaRelativeStrategyBaseTest {
  function testFuzz_calculatesMinimumAmountCorrectly(uint256 supply, uint256 minPct) public {
    RelativeQuorumHarness newStrategy = new RelativeQuorumHarness();
    minPct = bound(minPct, 0, 10_000);
    vm.assume(minPct == 0 || supply <= type(uint256).max / minPct); // avoid solmate revert statement

    uint256 product = FixedPointMathLib.mulDivUp(supply, minPct, 10_000);
    assertEq(newStrategy.exposed_getMinimumAmountNeeded(supply, minPct), product);
  }
}

contract IsApprovalEnabled is LlamaRelativeStrategyBaseTest {
  function test_PassesWhenCorrectRoleIsPassed() public {
    ActionInfo memory actionInfo = createAction(mpStrategy1);
    // address and actionInfo are not used
    mpStrategy1.checkIfApprovalEnabled(actionInfo, address(0), uint8(Roles.Approver));
  }

  function test_RevertIf_WrongRoleIsPassed() public {
    ActionInfo memory actionInfo = createAction(mpStrategy1);
    vm.expectRevert(abi.encodeWithSelector(LlamaRelativeStrategyBase.InvalidRole.selector, uint8(Roles.Approver)));
    // address and actionInfo are not used
    mpStrategy1.checkIfApprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
  }
}

contract IsDisapprovalEnabled is LlamaRelativeStrategyBaseTest {
  function test_PassesWhenCorrectRoleIsPassed() public {
    ActionInfo memory actionInfo = createAction(mpStrategy1);
    // address and actionInfo are not used
    mpStrategy1.checkIfDisapprovalEnabled(actionInfo, address(0), uint8(Roles.Disapprover));
  }

  function test_RevertIf_WrongRoleIsPassed() public {
    ActionInfo memory actionInfo = createAction(mpStrategy1);
    vm.expectRevert(abi.encodeWithSelector(LlamaRelativeStrategyBase.InvalidRole.selector, uint8(Roles.Disapprover)));
    // address and actionInfo are not used
    mpStrategy1.checkIfDisapprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
  }
}
