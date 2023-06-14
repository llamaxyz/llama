// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {MockLlamaAbsoluteStrategyBase} from "test/mock/MockLlamaAbsoluteStrategyBase.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/LlamaAbsoluteStrategyBase.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaAbsoluteStrategyBaseTest is LlamaTestSetup {
  event StrategyCreated(LlamaCore llama, LlamaPolicy policy);
  event ApprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);

  uint8 constant DEFAULT_ROLE = uint8(Roles.TestRole1);
  bytes32 constant DEFAULT_PERMISSION = bytes32(0);
  address constant DEFAULT_POLICYHOLDER = address(0xdeadbeef);
  uint64 constant DEFAULT_QUEUING_PERIOD = 1 days;
  uint64 constant DEFAULT_EXPIRATION_PERIOD = 4 days;
  uint64 constant DEFAULT_APPROVAL_PERIOD = 1 days;
  bool constant DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD = true;
  uint16 constant DEFAULT_DISAPPROVALS = 1;
  uint16 constant DEFAULT_APPROVALS = 1;
  uint8[] defaultForceRoles;

  MockLlamaAbsoluteStrategyBase mockLlamaAbsoluteStrategyBaseLogic;

  function setUp() public virtual override {
    LlamaTestSetup.setUp();

    mockLlamaAbsoluteStrategyBaseLogic = new MockLlamaAbsoluteStrategyBase();

    vm.prank(address(rootExecutor));
    factory.authorizeStrategyLogic(mockLlamaAbsoluteStrategyBaseLogic);
  }

  function max(uint8 role, uint8[] memory forceApprovalRoles, uint8[] memory forceDisapprovalRoles)
    internal
    pure
    returns (uint8 largest)
  {
    largest = role;
    for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
      if (forceApprovalRoles[i] > largest) largest = forceApprovalRoles[i];
    }
    for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
      if (forceDisapprovalRoles[i] > largest) largest = forceDisapprovalRoles[i];
    }
  }

  function initializeRolesUpTo(uint8 role) internal {
    while (mpPolicy.numRoles() < role) {
      vm.prank(address(mpExecutor));
      mpPolicy.initializeRole(RoleDescription.wrap("Test Role"));
    }
  }

  function deployTestStrategyAndSetRole(
    uint8 _role,
    bytes32 _permission,
    address _policyHolder,
    uint64 _queuingDuration,
    uint64 _expirationDelay,
    uint64 _approvalPeriod,
    bool _isFixedLengthApprovalPeriod,
    uint16 _minApprovals,
    uint16 _minDisapprovals,
    uint8[] memory _forceApprovalRoles,
    uint8[] memory _forceDisapprovalRoles
  ) internal returns (ILlamaStrategy newStrategy) {
    {
      // Initialize roles if required.
      initializeRolesUpTo(max(_role, _forceApprovalRoles, _forceDisapprovalRoles));

      vm.prank(address(mpExecutor));
      mpPolicy.setRoleHolder(_role, _policyHolder, 1, type(uint64).max);
      vm.prank(address(mpExecutor));
      mpPolicy.setRolePermission(_role, _permission, true);
    }

    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: _approvalPeriod,
      queuingPeriod: _queuingDuration,
      expirationPeriod: _expirationDelay,
      minApprovals: _minApprovals,
      minDisapprovals: _minDisapprovals,
      isFixedLengthApprovalPeriod: _isFixedLengthApprovalPeriod,
      approvalRole: _role,
      disapprovalRole: _role,
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    vm.expectEmit();
    emit StrategyCreated(mpCore, mpPolicy);

    mpCore.createStrategies(mockLlamaAbsoluteStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

    newStrategy = lens.computeLlamaStrategyAddress(
      address(mockLlamaAbsoluteStrategyBaseLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
    );
  }

  function deployTestStrategy() internal returns (ILlamaStrategy testStrategy) {
    LlamaAbsoluteStrategyBase.Config memory testStrategyData = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: DEFAULT_APPROVAL_PERIOD,
      queuingPeriod: DEFAULT_QUEUING_PERIOD,
      expirationPeriod: DEFAULT_EXPIRATION_PERIOD,
      minApprovals: DEFAULT_APPROVALS,
      minDisapprovals: DEFAULT_DISAPPROVALS,
      isFixedLengthApprovalPeriod: DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      approvalRole: DEFAULT_ROLE,
      disapprovalRole: DEFAULT_ROLE,
      forceApprovalRoles: defaultForceRoles,
      forceDisapprovalRoles: defaultForceRoles
    });
    testStrategy = lens.computeLlamaStrategyAddress(
      address(mockLlamaAbsoluteStrategyBaseLogic), DeployUtils.encodeStrategy(testStrategyData), address(mpCore)
    );
    LlamaAbsoluteStrategyBase.Config[] memory testStrategies = new LlamaAbsoluteStrategyBase.Config[](1);
    testStrategies[0] = testStrategyData;
    vm.prank(address(mpExecutor));
    mpCore.createStrategies(mockLlamaAbsoluteStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(testStrategies));
  }

  function generateAndSetRoleHolders(uint256 numberOfHolders) internal {
    for (uint256 i = 0; i < numberOfHolders; i++) {
      address _policyHolder = address(uint160(i + 100));
      if (mpPolicy.balanceOf(_policyHolder) == 0) {
        vm.prank(address(mpExecutor));
        mpPolicy.setRoleHolder(uint8(Roles.TestRole1), _policyHolder, 1, type(uint64).max);
      }
    }
  }
}

contract Constructor is LlamaAbsoluteStrategyBaseTest {
  function test_RevertIf_InitializeImplementationContract() public {
    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mockLlamaAbsoluteStrategyBaseLogic.initialize(bytes(""));
  }
}

contract Initialize is LlamaAbsoluteStrategyBaseTest {
  function testFuzz_SetsStrategyStorageQueuingDuration(uint64 _queuingDuration) public {
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      _queuingDuration,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );
    assertEq(toAbsoluteStrategyBase(newStrategy).queuingPeriod(), _queuingDuration);
  }

  function testFuzz_SetsStrategyStorageExpirationDelay(uint64 _expirationDelay) public {
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      _expirationDelay,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );
    assertEq(toAbsoluteStrategyBase(newStrategy).expirationPeriod(), _expirationDelay);
  }

  function test_SetsStrategyStorageIsFixedLengthApprovalPeriod(bool _isFixedLengthApprovalPeriod) public {
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      _isFixedLengthApprovalPeriod,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );
    assertEq(toAbsoluteStrategyBase(newStrategy).isFixedLengthApprovalPeriod(), _isFixedLengthApprovalPeriod);
  }

  function testFuzz_SetsStrategyStorageApprovalPeriod(uint64 _approvalPeriod) public {
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      _approvalPeriod,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );
    assertEq(toAbsoluteStrategyBase(newStrategy).approvalPeriod(), _approvalPeriod);
  }

  function test_SetsStrategyStoragePolicy() public {
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );
    assertEq(address(newStrategy.policy()), address(mpPolicy));
  }

  function test_SetsStrategyStorageLlama() public {
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );
    assertEq(address(newStrategy.llamaCore()), address(mpCore));
  }

  function testFuzz_SetsStrategyStorageMinApprovals(uint16 _approvals) public {
    _approvals = toUint16(bound(_approvals, 0, mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1))));
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      _approvals,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );
    assertEq(toAbsoluteStrategyBase(newStrategy).minApprovals(), _approvals);
  }

  function testFuzz_SetsStrategyStorageMinDisapprovals(uint16 _disapprovals) public {
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      _disapprovals,
      defaultForceRoles,
      defaultForceRoles
    );
    assertEq(toAbsoluteStrategyBase(newStrategy).minDisapprovals(), _disapprovals);
  }

  function testFuzz_SetsForceApprovalRoles(uint8[] memory forceApprovalRoles) public {
    for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
      // 0 = All Holders Role, which will revert if set as force role
      if (forceApprovalRoles[i] == 0) forceApprovalRoles[i] = 1;
    }
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      forceApprovalRoles,
      defaultForceRoles
    );
    for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
      assertEq(toAbsoluteStrategyBase(newStrategy).forceApprovalRole(forceApprovalRoles[i]), true);
    }
  }

  function testFuzz_SetsForceDisapprovalRoles(uint8[] memory forceDisapprovalRoles) public {
    for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
      // 0 = All Holders Role, which will revert if set as force role
      if (forceDisapprovalRoles[i] == 0) forceDisapprovalRoles[i] = 1;
    }
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      forceDisapprovalRoles
    );
    for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
      assertEq(toAbsoluteStrategyBase(newStrategy).forceDisapprovalRole(forceDisapprovalRoles[i]), true);
    }
  }

  function testFuzz_HandlesDuplicateApprovalRoles(uint8 _role) public {
    _role = uint8(bound(_role, 1, type(uint8).max));
    uint8[] memory forceApprovalRoles = new uint8[](2);
    forceApprovalRoles[0] = _role;
    forceApprovalRoles[1] = _role;
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      forceApprovalRoles,
      defaultForceRoles
    );
    assertEq(toAbsoluteStrategyBase(newStrategy).forceApprovalRole(_role), true);
  }

  function testFuzz_HandlesDuplicateDisapprovalRoles(uint8 _role) public {
    _role = uint8(bound(_role, 1, type(uint8).max));
    uint8[] memory forceDisapprovalRoles = new uint8[](2);
    forceDisapprovalRoles[0] = _role;
    forceDisapprovalRoles[1] = _role;
    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      forceDisapprovalRoles
    );
    assertEq(toAbsoluteStrategyBase(newStrategy).forceDisapprovalRole(_role), true);
  }

  function testFuzz_EmitsStrategyCreatedEvent( /*TODO fuzz this test */ ) public {
    deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );
  }

  function testFuzz_RevertIf_InvalidMinApprovals(uint256 _numberOfPolicies, uint256 _minApprovalIncrease) public {
    _minApprovalIncrease = bound(_minApprovalIncrease, 1, 1000);
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    generateAndSetRoleHolders(_numberOfPolicies);
    uint256 totalQuantity = mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1));
    uint256 minApprovals = totalQuantity + _minApprovalIncrease;

    vm.prank(address(rootExecutor));
    factory.authorizeStrategyLogic(mockLlamaAbsoluteStrategyBaseLogic);

    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: DEFAULT_APPROVAL_PERIOD,
      queuingPeriod: DEFAULT_QUEUING_PERIOD,
      expirationPeriod: DEFAULT_EXPIRATION_PERIOD,
      minApprovals: toUint128(minApprovals),
      minDisapprovals: DEFAULT_DISAPPROVALS,
      isFixedLengthApprovalPeriod: DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      approvalRole: DEFAULT_ROLE,
      disapprovalRole: DEFAULT_ROLE,
      forceApprovalRoles: defaultForceRoles,
      forceDisapprovalRoles: defaultForceRoles
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidMinApprovals.selector, minApprovals));
    mpCore.createStrategies(mockLlamaAbsoluteStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
  }

  function test_RevertIf_SetAllHoldersRoleAsForceApprovalRole() public {
    uint8[] memory _forceApprovalRoles = new uint8[](1);
    _forceApprovalRoles[0] = uint8(Roles.AllHolders);
    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: DEFAULT_APPROVAL_PERIOD,
      queuingPeriod: DEFAULT_QUEUING_PERIOD,
      expirationPeriod: DEFAULT_EXPIRATION_PERIOD,
      minApprovals: DEFAULT_APPROVALS,
      minDisapprovals: DEFAULT_DISAPPROVALS,
      isFixedLengthApprovalPeriod: false,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: defaultForceRoles
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));
    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.AllHolders)));
    mpCore.createStrategies(mockLlamaAbsoluteStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
  }

  function test_RevertIf_SetAllHoldersRoleAsForceDisapprovalRole() public {
    uint8[] memory _forceDisapprovalRoles = new uint8[](1);
    _forceDisapprovalRoles[0] = uint8(Roles.AllHolders);
    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: DEFAULT_APPROVAL_PERIOD,
      queuingPeriod: DEFAULT_QUEUING_PERIOD,
      expirationPeriod: DEFAULT_EXPIRATION_PERIOD,
      minApprovals: DEFAULT_APPROVALS,
      minDisapprovals: DEFAULT_DISAPPROVALS,
      isFixedLengthApprovalPeriod: false,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: defaultForceRoles,
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.AllHolders)));
    mpCore.createStrategies(mockLlamaAbsoluteStrategyBaseLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
  }
}

contract IsActionApproved is LlamaAbsoluteStrategyBaseTest {
  function testFuzz_RevertForNonExistentActionId(ActionInfo calldata actionInfo) public {
    vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
    vm.prank(address(approverAdam));
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
  }
}

contract GetApprovalQuantityAt is LlamaAbsoluteStrategyBaseTest {
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 1, 1, new uint8[](0), new uint8[](0)
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 1, 1, new uint8[](0), new uint8[](0)
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      _role,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      _policyHolder,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(_role, _policyHolder, _quantity, type(uint64).max);

    assertEq(newStrategy.getApprovalQuantityAt(address(0xdeadbeef), uint8(Roles.TestRole2), block.timestamp), 0);
  }
}

contract GetDisapprovalQuantityAt is LlamaAbsoluteStrategyBaseTest {
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 1, 1, new uint8[](0), new uint8[](0)
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 1, 1, new uint8[](0), new uint8[](0)
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      _role,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      _policyHolder,
      1 days,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
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

    ILlamaStrategy newStrategy = deployTestStrategyAndSetRole(
      DEFAULT_ROLE,
      DEFAULT_PERMISSION,
      DEFAULT_POLICYHOLDER,
      DEFAULT_QUEUING_PERIOD,
      DEFAULT_EXPIRATION_PERIOD,
      DEFAULT_APPROVAL_PERIOD,
      DEFAULT_FIXED_LENGTH_APPROVAL_PERIOD,
      DEFAULT_APPROVALS,
      DEFAULT_DISAPPROVALS,
      defaultForceRoles,
      defaultForceRoles
    );

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(_role, _policyHolder, _quantity, type(uint64).max);

    assertEq(newStrategy.getDisapprovalQuantityAt(address(0xdeadbeef), uint8(Roles.TestRole2), block.timestamp), 0);
  }
}
