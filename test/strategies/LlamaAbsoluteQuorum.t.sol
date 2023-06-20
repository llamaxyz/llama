// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {MockProtocol} from "test/mock/MockProtocol.sol";
import {Roles} from "test/utils/LlamaTestSetup.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/LlamaAbsoluteStrategyBase.sol";
import {LlamaAbsoluteStrategyBaseTest} from "test/strategies/LlamaAbsoluteStrategyBase.t.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaAbsoluteQuorumTest is LlamaAbsoluteStrategyBaseTest {
  function deployAbsoluteQuorumAndSetRole(
    uint8 _role,
    bytes32 _permission,
    address _policyHolder,
    uint64 _queuingDuration,
    uint64 _expirationDelay,
    uint64 _approvalPeriod,
    bool _isFixedLengthApprovalPeriod,
    uint128 _minApprovals,
    uint128 _minDisapprovals,
    uint8[] memory _forceApprovalRoles,
    uint8[] memory _forceDisapprovalRoles
  ) internal returns (ILlamaStrategy newStrategy) {
    {
      vm.prank(address(rootExecutor));
      factory.authorizeStrategyLogic(absoluteQuorumLogic);
      // Initialize roles if required.
      initializeRolesUpTo(maxRole(_role, _forceApprovalRoles, _forceDisapprovalRoles));

      vm.startPrank(address(mpExecutor));
      mpPolicy.setRoleHolder(_role, _policyHolder, 1, type(uint64).max);
      mpPolicy.setRolePermission(_role, _permission, true);
      vm.stopPrank();
    }

    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: _approvalPeriod,
      queuingPeriod: _queuingDuration,
      expirationPeriod: _expirationDelay,
      isFixedLengthApprovalPeriod: _isFixedLengthApprovalPeriod,
      minApprovals: _minApprovals,
      minDisapprovals: _minDisapprovals,
      approvalRole: _role,
      disapprovalRole: _role,
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    mpCore.createStrategies(absoluteQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

    newStrategy = lens.computeLlamaStrategyAddress(
      address(absoluteQuorumLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
    );
  }
}

contract ValidateActionCreation is LlamaAbsoluteQuorumTest {
  function createAbsoluteQuorumWithDisproportionateQuantity(
    bool isApproval,
    uint128 threshold,
    uint256 _roleQuantity,
    uint256 _otherRoleHolders
  ) internal returns (ILlamaStrategy testStrategy) {
    _roleQuantity = bound(_roleQuantity, 100, 1000);
    _otherRoleHolders = bound(_otherRoleHolders, 1, 10);

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(this), uint128(_roleQuantity), type(uint64).max);

    generateAndSetRoleHolders(_otherRoleHolders);

    vm.prank(address(rootExecutor));
    factory.authorizeStrategyLogic(absoluteQuorumLogic);

    testStrategy = deployAbsoluteQuorum(
      uint8(Roles.TestRole1),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      false,
      isApproval ? threshold : 0,
      isApproval ? 0 : threshold,
      new uint8[](0),
      new uint8[](0)
    );

    bytes32 newPermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy));

    vm.prank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), newPermissionId, true);
  }

  function testFuzz_RevertIf_NotEnoughApprovalQuantity(uint256 _otherRoleHolders) external {
    _otherRoleHolders = bound(_otherRoleHolders, 1, 10);
    generateAndSetRoleHolders(_otherRoleHolders);
    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(this), 1, type(uint64).max); // for action creation
      // permission
    uint128 roleQuantity = mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1));
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
      uint8(Roles.TestRole1),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      false,
      roleQuantity,
      1,
      new uint8[](0),
      new uint8[](0)
    );
    vm.startPrank(address(mpExecutor));
    mpPolicy.setRolePermission(
      uint8(Roles.TestRole1), keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy)), true
    );
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(uint160(100)), 0, 0); // removing role holder from an address
      // created in `generateAndSetRoleHolders`
    vm.stopPrank();
    vm.expectRevert(LlamaAbsoluteStrategyBase.InsufficientApprovalQuantity.selector);
    mpCore.createAction(
      uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
  }

  function testFuzz_RevertIf_NotEnoughDisapprovalQuantity(uint256 _roleQuantity, uint256 _otherRoleHolders) external {
    _roleQuantity = bound(_roleQuantity, 100, 1000);
    uint256 threshold = _roleQuantity / 2;

    ILlamaStrategy testStrategy =
      createAbsoluteQuorumWithDisproportionateQuantity(false, toUint128(threshold), _roleQuantity, _otherRoleHolders);

    vm.expectRevert(LlamaAbsoluteStrategyBase.InsufficientDisapprovalQuantity.selector);
    mpCore.createAction(
      uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
  }

  function testFuzz_DisableDisapprovals(uint256 _roleQuantity, uint256 _otherRoleHolders) external {
    ILlamaStrategy testStrategy =
      createAbsoluteQuorumWithDisproportionateQuantity(false, type(uint128).max, _roleQuantity, _otherRoleHolders);

    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
    ActionInfo memory actionInfo = ActionInfo(
      actionId,
      address(this),
      uint8(Roles.TestRole1),
      testStrategy,
      address(mockProtocol),
      0,
      abi.encodeCall(MockProtocol.pause, (true))
    );

    vm.warp(block.timestamp + 1);

    mpCore.queueAction(actionInfo);

    vm.expectRevert(LlamaAbsoluteStrategyBase.DisapprovalDisabled.selector);

    mpCore.castDisapproval(uint8(Roles.TestRole1), actionInfo, "");
  }
}

contract IsApprovalEnabled is LlamaAbsoluteQuorumTest {
  function test_PassesWhenCorrectRoleIsPassed() public {
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(testStrategy);
    testStrategy.isApprovalEnabled(actionInfo, address(0), uint8(Roles.Approver));
  }

  function test_RevertIf_WrongRoleIsPassed() public {
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(testStrategy);
    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.Approver)));
    testStrategy.isApprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
  }

  function test_ActionCreatorCanApprove() public {
    ILlamaStrategy absoluteQuorum = deployAbsoluteQuorum(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(absoluteQuorum);
    // function reverts if approval disabled, so it not reverting is behavior we are testing
    absoluteQuorum.isApprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Approver));
  }
}

contract IsDisapprovalEnabled is LlamaAbsoluteQuorumTest {
  function test_PassesWhenCorrectRoleIsPassed() public {
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(testStrategy);
    testStrategy.isDisapprovalEnabled(actionInfo, address(0), uint8(Roles.Disapprover));
  }

  function test_RevertIf_WrongRoleIsPassed() public {
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(testStrategy);
    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.Disapprover)));
    testStrategy.isDisapprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
  }

  function test_ActionCreatorCanDisapprove() public {
    ILlamaStrategy absoluteQuorum = deployAbsoluteQuorum(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(absoluteQuorum);
    // function reverts if disapproval is disabled, so it not reverting is behavior we are testing
    absoluteQuorum.isDisapprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Disapprover));
  }
}
