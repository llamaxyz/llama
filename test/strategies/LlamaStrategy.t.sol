// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import {Test, console2} from "forge-std/Test.sol";

// import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

// import {MockProtocol} from "test/mock/MockProtocol.sol";
// import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

// import {DeployUtils} from "script/DeployUtils.sol";

// import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
// import {ActionState} from "src/lib/Enums.sol";
// import {ActionInfo} from "src/lib/Structs.sol";
// import {RoleDescription} from "src/lib/UDVTs.sol";
// import {LlamaAbsolutePeerReview} from "src/strategies/LlamaAbsolutePeerReview.sol";
// import {LlamaAbsoluteQuorum} from "src/strategies/LlamaAbsoluteQuorum.sol";
// import {LlamaAbsoluteStrategyBase} from "src/strategies/LlamaAbsoluteStrategyBase.sol";
// import {LlamaRelativeQuorum} from "src/strategies/LlamaRelativeQuorum.sol";
// import {LlamaCore} from "src/LlamaCore.sol";
// import {LlamaPolicy} from "src/LlamaPolicy.sol";

// contract LlamaStrategyTest is LlamaTestSetup {
//   event StrategyCreated(LlamaCore llama, LlamaPolicy policy);
//   event ApprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
//   event DisapprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);

//   function max(uint8 role, uint8[] memory forceApprovalRoles, uint8[] memory forceDisapprovalRoles)
//     internal
//     pure
//     returns (uint8 largest)
//   {
//     largest = role;
//     for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
//       if (forceApprovalRoles[i] > largest) largest = forceApprovalRoles[i];
//     }
//     for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
//       if (forceDisapprovalRoles[i] > largest) largest = forceDisapprovalRoles[i];
//     }
//   }

//   function initializeRolesUpTo(uint8 role) internal {
//     while (mpPolicy.numRoles() < role) {
//       vm.prank(address(mpExecutor));
//       mpPolicy.initializeRole(RoleDescription.wrap("Test Role"));
//     }
//   }

//   function deployRelativeQuorumAndSetRole(
//     uint8 _role,
//     bytes32 _permission,
//     address _policyHolder,
//     uint64 _queuingDuration,
//     uint64 _expirationDelay,
//     uint64 _approvalPeriod,
//     bool _isFixedLengthApprovalPeriod,
//     uint16 _minApprovalPct,
//     uint16 _minDisapprovalPct,
//     uint8[] memory _forceApprovalRoles,
//     uint8[] memory _forceDisapprovalRoles
//   ) internal returns (ILlamaStrategy newStrategy) {
//     {
//       // Initialize roles if required.
//       initializeRolesUpTo(max(_role, _forceApprovalRoles, _forceDisapprovalRoles));

//       vm.prank(address(mpExecutor));
//       mpPolicy.setRoleHolder(_role, _policyHolder, 1, type(uint64).max);
//       vm.prank(address(mpExecutor));
//       mpPolicy.setRolePermission(_role, _permission, true);
//     }

//     LlamaRelativeQuorum.Config memory strategyConfig = LlamaRelativeQuorum.Config({
//       approvalPeriod: _approvalPeriod,
//       queuingPeriod: _queuingDuration,
//       expirationPeriod: _expirationDelay,
//       isFixedLengthApprovalPeriod: _isFixedLengthApprovalPeriod,
//       minApprovalPct: _minApprovalPct,
//       minDisapprovalPct: _minDisapprovalPct,
//       approvalRole: _role,
//       disapprovalRole: _role,
//       forceApprovalRoles: _forceApprovalRoles,
//       forceDisapprovalRoles: _forceDisapprovalRoles
//     });

//     LlamaRelativeQuorum.Config[] memory strategyConfigs = new LlamaRelativeQuorum.Config[](1);
//     strategyConfigs[0] = strategyConfig;

//     vm.prank(address(mpExecutor));

//     vm.expectEmit();
//     emit StrategyCreated(mpCore, mpPolicy);

//     mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

//     newStrategy = lens.computeLlamaStrategyAddress(
//       address(relativeQuorumLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
//     );
//   }

//   function deployAbsolutePeerReviewAndSetRole(
//     uint8 _role,
//     bytes32 _permission,
//     address _policyHolder,
//     uint64 _queuingDuration,
//     uint64 _expirationDelay,
//     uint64 _approvalPeriod,
//     bool _isFixedLengthApprovalPeriod,
//     uint128 _minApprovals,
//     uint128 _minDisapprovals,
//     uint8[] memory _forceApprovalRoles,
//     uint8[] memory _forceDisapprovalRoles
//   ) internal returns (ILlamaStrategy newStrategy) {
//     {
//       vm.prank(address(rootExecutor));
//       factory.authorizeStrategyLogic(absolutePeerReviewLogic);
//       // Initialize roles if required.
//       initializeRolesUpTo(max(_role, _forceApprovalRoles, _forceDisapprovalRoles));

//       vm.startPrank(address(mpExecutor));
//       mpPolicy.setRoleHolder(_role, _policyHolder, 1, type(uint64).max);
//       mpPolicy.setRolePermission(_role, _permission, true);
//       vm.stopPrank();
//     }

//     LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
//       approvalPeriod: _approvalPeriod,
//       queuingPeriod: _queuingDuration,
//       expirationPeriod: _expirationDelay,
//       isFixedLengthApprovalPeriod: _isFixedLengthApprovalPeriod,
//       minApprovals: _minApprovals,
//       minDisapprovals: _minDisapprovals,
//       approvalRole: _role,
//       disapprovalRole: _role,
//       forceApprovalRoles: _forceApprovalRoles,
//       forceDisapprovalRoles: _forceDisapprovalRoles
//     });

//     LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
//     strategyConfigs[0] = strategyConfig;

//     vm.prank(address(mpExecutor));

//     mpCore.createStrategies(absolutePeerReviewLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

//     newStrategy = lens.computeLlamaStrategyAddress(
//       address(absolutePeerReviewLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
//     );
//   }

//   function deployTestStrategy() internal returns (ILlamaStrategy testStrategy) {
//     LlamaRelativeQuorum.Config memory testStrategyData = LlamaRelativeQuorum.Config({
//       approvalPeriod: 1 days,
//       queuingPeriod: 2 days,
//       expirationPeriod: 8 days,
//       isFixedLengthApprovalPeriod: true,
//       minApprovalPct: 4000,
//       minDisapprovalPct: 2000,
//       approvalRole: uint8(Roles.TestRole1),
//       disapprovalRole: uint8(Roles.TestRole1),
//       forceApprovalRoles: new uint8[](0),
//       forceDisapprovalRoles: new uint8[](0)
//     });
//     testStrategy = lens.computeLlamaStrategyAddress(
//       address(relativeQuorumLogic), DeployUtils.encodeStrategy(testStrategyData), address(mpCore)
//     );
//     LlamaRelativeQuorum.Config[] memory testStrategies = new LlamaRelativeQuorum.Config[](1);
//     testStrategies[0] = testStrategyData;
//     vm.prank(address(mpExecutor));
//     mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(testStrategies));
//   }

//   function deployRelativeQuorumWithForceApproval() internal returns (ILlamaStrategy testStrategy) {
//     // Define strategy parameters.
//     uint8[] memory forceApproveRoles = new uint8[](1);
//     forceApproveRoles[0] = uint8(Roles.ForceApprover);
//     uint8[] memory forceDisapproveRoles = new uint8[](1);
//     forceDisapproveRoles[0] = uint8(Roles.ForceDisapprover);

//     LlamaRelativeQuorum.Config memory testStrategyData = LlamaRelativeQuorum.Config({
//       approvalPeriod: 1 days,
//       queuingPeriod: 2 days,
//       expirationPeriod: 8 days,
//       isFixedLengthApprovalPeriod: false,
//       minApprovalPct: 4000,
//       minDisapprovalPct: 2000,
//       approvalRole: uint8(Roles.TestRole1),
//       disapprovalRole: uint8(Roles.TestRole1),
//       forceApprovalRoles: forceApproveRoles,
//       forceDisapprovalRoles: forceDisapproveRoles
//     });

//     // Get the address of the strategy we'll deploy.
//     testStrategy = lens.computeLlamaStrategyAddress(
//       address(relativeQuorumLogic), DeployUtils.encodeStrategy(testStrategyData), address(mpCore)
//     );

//     // Create and authorize the strategy.
//     LlamaRelativeQuorum.Config[] memory testStrategies = new LlamaRelativeQuorum.Config[](1);
//     testStrategies[0] = testStrategyData;
//     vm.prank(address(mpExecutor));
//     mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(testStrategies));

//     vm.prank(address(mpExecutor));
//     mpPolicy.setRoleHolder(uint8(Roles.ForceApprover), address(approverAdam), 1, type(uint64).max);
//   }

//   function createAction(ILlamaStrategy testStrategy) internal returns (ActionInfo memory actionInfo) {
//     // Give the action creator the ability to use this strategy.
//     bytes32 newPermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy));
//     vm.prank(address(mpExecutor));
//     mpPolicy.setRolePermission(uint8(Roles.ActionCreator), newPermissionId, true);

//     // Create the action.
//     bytes memory data = abi.encodeCall(MockProtocol.pause, (true));
//     vm.prank(actionCreatorAaron);
//     uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), testStrategy, address(mockProtocol), 0, data,
// "");

//     actionInfo =
//       ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), testStrategy, address(mockProtocol), 0,
// data);

//     vm.warp(block.timestamp + 1);
//   }

//   function approveAction(uint256 numberOfApprovals, ActionInfo memory actionInfo) internal {
//     for (uint256 i = 0; i < numberOfApprovals; i++) {
//       address _policyholder = address(uint160(i + 100));
//       vm.prank(_policyholder);
//       mpCore.castApproval(uint8(Roles.TestRole1), actionInfo, "");
//     }
//   }

//   function disapproveAction(uint256 numberOfDisapprovals, ActionInfo memory actionInfo) internal {
//     for (uint256 i = 0; i < numberOfDisapprovals; i++) {
//       address _policyholder = address(uint160(i + 100));
//       vm.prank(_policyholder);
//       mpCore.castDisapproval(uint8(Roles.TestRole1), actionInfo, "");
//     }
//   }

//   function generateAndSetRoleHolders(uint256 numberOfHolders) internal {
//     for (uint256 i = 0; i < numberOfHolders; i++) {
//       address _policyHolder = address(uint160(i + 100));
//       if (mpPolicy.balanceOf(_policyHolder) == 0) {
//         vm.prank(address(mpExecutor));
//         mpPolicy.setRoleHolder(uint8(Roles.TestRole1), _policyHolder, 1, type(uint64).max);
//       }
//     }
//   }
// }

// contract Constructor is LlamaStrategyTest {
//   function test_RevertIf_InitializeAbsoluteImplementationContract() public {
//     vm.expectRevert(bytes("Initializable: contract is already initialized"));
//     absolutePeerReviewLogic.initialize(bytes(""));
//   }

//   function test_RevertIf_InitializeRelativeImplementationContract() public {
//     vm.expectRevert(bytes("Initializable: contract is already initialized"));
//     relativeQuorumLogic.initialize(bytes(""));
//   }
// }

// contract Initialize is LlamaStrategyTest {
//   function testFuzz_SetsStrategyStorageQueuingDuration(uint64 _queuingDuration) public {
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       _queuingDuration,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(toRelativeQuorum(newStrategy).queuingPeriod(), _queuingDuration);
//   }

//   function testFuzz_SetsStrategyStorageExpirationDelay(uint64 _expirationDelay) public {
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       _expirationDelay,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(toRelativeQuorum(newStrategy).expirationPeriod(), _expirationDelay);
//   }

//   function test_SetsStrategyStorageIsFixedLengthApprovalPeriod(bool _isFixedLengthApprovalPeriod) public {
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       _isFixedLengthApprovalPeriod,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(toRelativeQuorum(newStrategy).isFixedLengthApprovalPeriod(), _isFixedLengthApprovalPeriod);
//   }

//   function testFuzz_SetsStrategyStorageApprovalPeriod(uint64 _approvalPeriod) public {
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       _approvalPeriod,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(toRelativeQuorum(newStrategy).approvalPeriod(), _approvalPeriod);
//   }

//   function test_SetsStrategyStoragePolicy() public {
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(address(newStrategy.policy()), address(mpPolicy));
//   }

//   function test_SetsStrategyStorageLlama() public {
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(address(newStrategy.llamaCore()), address(mpCore));
//   }

//   function testFuzz_SetsStrategyStorageMinApprovalPct(uint256 _percent) public {
//     _percent = bound(_percent, 0, 10_000);
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       toUint16(_percent),
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(toRelativeQuorum(newStrategy).minApprovalPct(), _percent);
//   }

//   function testFuzz_SetsStrategyStorageMinApprovals(uint128 _approvals) public {
//     _approvals = toUint128(bound(_approvals, 0, mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1))));
//     ILlamaStrategy newStrategy = deployAbsolutePeerReviewAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       _approvals,
//       5,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(toAbsolutePeerReview(newStrategy).minApprovals(), _approvals);
//   }

//   function testFuzz_SetsStrategyStorageMinDisapprovalPct(uint16 _percent) public {
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       _percent,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(toRelativeQuorum(newStrategy).minDisapprovalPct(), _percent);
//   }

//   function testFuzz_SetsStrategyStorageMinDisapprovals(uint128 _disapprovals) public {
//     ILlamaStrategy newStrategy = deployAbsolutePeerReviewAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       1,
//       _disapprovals,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     assertEq(toAbsolutePeerReview(newStrategy).minDisapprovals(), _disapprovals);
//   }

//   function testFuzz_SetsForceApprovalRoles(uint8[] memory forceApprovalRoles) public {
//     for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
//       // 0 = All Holders Role, which will revert if set as force role
//       if (forceApprovalRoles[i] == 0) forceApprovalRoles[i] = 1;
//     }
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       forceApprovalRoles,
//       new uint8[](0)
//     );
//     for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
//       assertEq(toRelativeQuorum(newStrategy).forceApprovalRole(forceApprovalRoles[i]), true);
//     }
//   }

//   function testFuzz_SetsForceDisapprovalRoles(uint8[] memory forceDisapprovalRoles) public {
//     for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
//       // 0 = All Holders Role, which will revert if set as force role
//       if (forceDisapprovalRoles[i] == 0) forceDisapprovalRoles[i] = 1;
//     }
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       forceDisapprovalRoles
//     );
//     for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
//       assertEq(toRelativeQuorum(newStrategy).forceDisapprovalRole(forceDisapprovalRoles[i]), true);
//     }
//   }

//   function testFuzz_HandlesDuplicateApprovalRoles(uint8 _role) public {
//     _role = uint8(bound(_role, 1, type(uint8).max));
//     uint8[] memory forceApprovalRoles = new uint8[](2);
//     forceApprovalRoles[0] = _role;
//     forceApprovalRoles[1] = _role;
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       forceApprovalRoles,
//       new uint8[](0)
//     );
//     assertEq(toRelativeQuorum(newStrategy).forceApprovalRole(_role), true);
//   }

//   function testFuzz_HandlesDuplicateDisapprovalRoles(uint8 _role) public {
//     _role = uint8(bound(_role, 1, type(uint8).max));
//     uint8[] memory forceDisapprovalRoles = new uint8[](2);
//     forceDisapprovalRoles[0] = _role;
//     forceDisapprovalRoles[1] = _role;
//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       forceDisapprovalRoles
//     );
//     assertEq(toRelativeQuorum(newStrategy).forceDisapprovalRole(_role), true);
//   }

//   function testFuzz_EmitsStrategyCreatedEvent( /*TODO fuzz this test */ ) public {
//     deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );
//   }

//   function testFuzz_RevertIf_InvalidMinApprovalsPeerReview(uint256 _numberOfPolicies, uint256 _minApprovalIncrease)
//     public
//   {
//     _minApprovalIncrease = bound(_minApprovalIncrease, 1, 1000);
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     generateAndSetRoleHolders(_numberOfPolicies);
//     uint256 totalQuantity = mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1));
//     uint256 minApprovals = totalQuantity + _minApprovalIncrease;

//     vm.prank(address(rootExecutor));
//     factory.authorizeStrategyLogic(absolutePeerReviewLogic);

//     LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
//       approvalPeriod: 1 days,
//       queuingPeriod: 1 days,
//       expirationPeriod: 1 days,
//       isFixedLengthApprovalPeriod: false,
//       minApprovals: toUint128(minApprovals),
//       minDisapprovals: 0,
//       approvalRole: uint8(Roles.TestRole1),
//       disapprovalRole: uint8(Roles.Disapprover),
//       forceApprovalRoles: new uint8[](0),
//       forceDisapprovalRoles: new uint8[](0)
//     });

//     LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
//     strategyConfigs[0] = strategyConfig;

//     vm.prank(address(rootExecutor));

//     factory.authorizeStrategyLogic(absolutePeerReviewLogic);

//     vm.prank(address(mpExecutor));

//     vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidMinApprovals.selector, minApprovals));
//     mpCore.createStrategies(absolutePeerReviewLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
//   }

//   function test_RevertIf_SetAllHoldersRoleAsForceApprovalRoleAbsolutePeerReview() public {
//     uint8[] memory _forceApprovalRoles = new uint8[](1);
//     _forceApprovalRoles[0] = uint8(Roles.AllHolders);
//     LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
//       approvalPeriod: 1 days,
//       queuingPeriod: 1 days,
//       expirationPeriod: 1 days,
//       isFixedLengthApprovalPeriod: false,
//       minApprovals: 1,
//       minDisapprovals: 1,
//       approvalRole: uint8(Roles.Approver),
//       disapprovalRole: uint8(Roles.Disapprover),
//       forceApprovalRoles: _forceApprovalRoles,
//       forceDisapprovalRoles: new uint8[](0)
//     });

//     LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
//     strategyConfigs[0] = strategyConfig;

//     vm.prank(address(rootExecutor));

//     factory.authorizeStrategyLogic(absolutePeerReviewLogic);

//     vm.prank(address(mpExecutor));
//     vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.AllHolders)));
//     mpCore.createStrategies(absolutePeerReviewLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
//   }

//   function test_RevertIf_SetAllHoldersRoleAsForceDisapprovalRoleAbsolutePeerReview() public {
//     uint8[] memory _forceDisapprovalRoles = new uint8[](1);
//     _forceDisapprovalRoles[0] = uint8(Roles.AllHolders);
//     LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
//       approvalPeriod: 1 days,
//       queuingPeriod: 1 days,
//       expirationPeriod: 1 days,
//       isFixedLengthApprovalPeriod: false,
//       minApprovals: 1,
//       minDisapprovals: 1,
//       approvalRole: uint8(Roles.Approver),
//       disapprovalRole: uint8(Roles.Disapprover),
//       forceApprovalRoles: new uint8[](0),
//       forceDisapprovalRoles: _forceDisapprovalRoles
//     });

//     LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
//     strategyConfigs[0] = strategyConfig;

//     vm.prank(address(rootExecutor));

//     factory.authorizeStrategyLogic(absolutePeerReviewLogic);

//     vm.prank(address(mpExecutor));

//     vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.AllHolders)));
//     mpCore.createStrategies(absolutePeerReviewLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
//   }

//   function test_RevertIf_SetAllHoldersRoleAsForceApprovalRoleRelativeQuorum() public {
//     uint8[] memory _forceApprovalRoles = new uint8[](1);
//     _forceApprovalRoles[0] = uint8(Roles.AllHolders);
//     LlamaRelativeQuorum.Config memory strategyConfig = LlamaRelativeQuorum.Config({
//       approvalPeriod: 1 days,
//       queuingPeriod: 1 days,
//       expirationPeriod: 1 days,
//       isFixedLengthApprovalPeriod: false,
//       minApprovalPct: 5000,
//       minDisapprovalPct: 5000,
//       approvalRole: uint8(Roles.Approver),
//       disapprovalRole: uint8(Roles.Disapprover),
//       forceApprovalRoles: _forceApprovalRoles,
//       forceDisapprovalRoles: new uint8[](0)
//     });

//     LlamaRelativeQuorum.Config[] memory strategyConfigs = new LlamaRelativeQuorum.Config[](1);
//     strategyConfigs[0] = strategyConfig;

//     vm.prank(address(mpExecutor));

//     vm.expectRevert(abi.encodeWithSelector(LlamaRelativeQuorum.InvalidRole.selector, uint8(Roles.AllHolders)));
//     mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
//   }

//   function test_RevertIf_SetAllHoldersRoleAsForceDisapprovalRoleRelativeQuorum() public {
//     uint8[] memory _forceDisapprovalRoles = new uint8[](1);
//     _forceDisapprovalRoles[0] = uint8(Roles.AllHolders);
//     LlamaRelativeQuorum.Config memory strategyConfig = LlamaRelativeQuorum.Config({
//       approvalPeriod: 1 days,
//       queuingPeriod: 1 days,
//       expirationPeriod: 1 days,
//       isFixedLengthApprovalPeriod: false,
//       minApprovalPct: 5000,
//       minDisapprovalPct: 5000,
//       approvalRole: uint8(Roles.Approver),
//       disapprovalRole: uint8(Roles.Disapprover),
//       forceApprovalRoles: new uint8[](0),
//       forceDisapprovalRoles: _forceDisapprovalRoles
//     });

//     LlamaRelativeQuorum.Config[] memory strategyConfigs = new LlamaRelativeQuorum.Config[](1);
//     strategyConfigs[0] = strategyConfig;

//     vm.prank(address(mpExecutor));

//     vm.expectRevert(abi.encodeWithSelector(LlamaRelativeQuorum.InvalidRole.selector, uint8(Roles.AllHolders)));
//     mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
//   }
// }

// contract IsActionApproved is LlamaStrategyTest {
//   function testFuzz_ReturnsTrueForPassedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     _actionApprovals =
//       bound(_actionApprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000), _numberOfPolicies);

//     ILlamaStrategy testStrategy = deployTestStrategy();

//     generateAndSetRoleHolders(_numberOfPolicies);

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     approveAction(_actionApprovals, actionInfo);

//     bool _isActionApproved = testStrategy.isActionApproved(actionInfo);

//     assertEq(_isActionApproved, true);
//   }

//   function testFuzz_AbsolutePeerReview_ReturnsTrueForPassedActions(uint256 _actionApprovals, uint256
// _numberOfPolicies)
//     public
//   {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     _actionApprovals =
//       bound(_actionApprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000), _numberOfPolicies);

//     generateAndSetRoleHolders(_numberOfPolicies);

//     ILlamaStrategy testStrategy = deployAbsolutePeerReviewAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       toUint128(_actionApprovals),
//       1,
//       new uint8[](0),
//       new uint8[](0)
//     );

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     approveAction(_actionApprovals, actionInfo);

//     bool _isActionApproved = testStrategy.isActionApproved(actionInfo);

//     assertEq(_isActionApproved, true);
//   }

//   function testFuzz_ReturnsFalseForFailedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     _actionApprovals = bound(_actionApprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000) - 1);

//     ILlamaStrategy testStrategy = deployTestStrategy();

//     generateAndSetRoleHolders(_numberOfPolicies);

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     approveAction(_actionApprovals, actionInfo);

//     bool _isActionApproved = testStrategy.isActionApproved(actionInfo);

//     assertEq(_isActionApproved, false);
//   }

//   function testFuzz_AbsolutePeerReview_ReturnsFalseForFailedActions(uint256 _actionApprovals, uint256
// _numberOfPolicies)
//     public
//   {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     _actionApprovals = bound(_actionApprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 3000, 10_000) - 1);
//     uint256 approvalThreshold = FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000);

//     generateAndSetRoleHolders(_numberOfPolicies);

//     ILlamaStrategy testStrategy = deployAbsolutePeerReviewAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       toUint128(approvalThreshold),
//       1,
//       new uint8[](0),
//       new uint8[](0)
//     );

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     approveAction(_actionApprovals, actionInfo);

//     bool _isActionApproved = testStrategy.isActionApproved(actionInfo);

//     assertEq(_isActionApproved, false);
//   }

//   function testFuzz_RevertForNonExistentActionId(ActionInfo calldata actionInfo) public {
//     vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
//     vm.prank(address(approverAdam));
//     mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
//   }
// }

// contract ValidateActionCancelation is LlamaStrategyTest {
//   function testFuzz_RevertIf_RelativeQuorum_ActionNotFullyDisapprovedAndCallerIsNotCreator(
//     uint256 _actionDisapprovals,
//     uint256 _numberOfPolicies
//   ) public {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) -
// 1);

//     ILlamaStrategy testStrategy = deployRelativeQuorumWithForceApproval();

//     generateAndSetRoleHolders(_numberOfPolicies);

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     vm.prank(address(approverAdam));
//     mpCore.castApproval(uint8(Roles.ForceApprover), actionInfo, "");

//     mpCore.queueAction(actionInfo);

//     disapproveAction(_actionDisapprovals, actionInfo);
//     assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));

//     vm.expectRevert(LlamaRelativeQuorum.OnlyActionCreator.selector);
//     testStrategy.validateActionCancelation(actionInfo, address(this));
//   }

//   function testFuzz_NoRevertIf_RelativeQuorum_ActionNotFullyDisapprovedAndCallerIsNotCreator(
//     uint256 _actionDisapprovals,
//     uint256 _numberOfPolicies
//   ) public {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) -
// 1);

//     ILlamaStrategy testStrategy = deployRelativeQuorumWithForceApproval();

//     generateAndSetRoleHolders(_numberOfPolicies);

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     vm.prank(address(approverAdam));
//     mpCore.castApproval(uint8(Roles.ForceApprover), actionInfo, "");

//     mpCore.queueAction(actionInfo);

//     disapproveAction(_actionDisapprovals, actionInfo);
//     assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));

//     testStrategy.validateActionCancelation(actionInfo, actionInfo.creator); // This should not revert.
//   }

//   function testFuzz_RevertIf_AbsolutePeerReview_ActionNotFullyDisapprovedAndCallerIsNotCreator(
//     uint256 _actionDisapprovals,
//     uint256 _numberOfPolicies
//   ) public {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) -
// 1);
//     uint256 disapprovalThreshold = FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000);

//     ILlamaStrategy testStrategy = deployAbsolutePeerReviewAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       false,
//       0,
//       toUint128(disapprovalThreshold),
//       new uint8[](0),
//       new uint8[](0)
//     );

//     generateAndSetRoleHolders(_numberOfPolicies);

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     mpCore.queueAction(actionInfo);

//     disapproveAction(_actionDisapprovals, actionInfo);
//     assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));

//     vm.expectRevert(LlamaRelativeQuorum.OnlyActionCreator.selector);
//     testStrategy.validateActionCancelation(actionInfo, address(this));
//   }

//   function testFuzz_NoRevertIf_AbsolutePeerReview_ActionNotFullyDisapprovedAndCallerIsNotCreator(
//     uint256 _actionDisapprovals,
//     uint256 _numberOfPolicies
//   ) public {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) -
// 1);
//     uint256 disapprovalThreshold = FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000);

//     ILlamaStrategy testStrategy = deployAbsolutePeerReviewAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(this),
//       1 days,
//       4 days,
//       1 days,
//       false,
//       0,
//       toUint128(disapprovalThreshold),
//       new uint8[](0),
//       new uint8[](0)
//     );

//     generateAndSetRoleHolders(_numberOfPolicies);

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     mpCore.queueAction(actionInfo);

//     disapproveAction(_actionDisapprovals, actionInfo);
//     assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));

//     testStrategy.validateActionCancelation(actionInfo, actionInfo.creator); // This should not revert.
//   }

//   function testFuzz_RevertForNonExistentActionId(ActionInfo calldata actionInfo) public {
//     vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
//     vm.prank(address(disapproverDave));
//     mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");
//   }
// }

// contract GetApprovalQuantityAt is LlamaStrategyTest {
//   function testFuzz_ReturnsZeroQuantityPriorToAccountGainingPermission(
//     uint256 _timeUntilPermission,
//     uint8 _role,
//     bytes32 _permission,
//     address _policyHolder
//   ) public {
//     vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
//     vm.assume(_role > 0);
//     vm.assume(_permission > bytes32(0));
//     vm.assume(_policyHolder != address(0));
//     uint256 _referenceTime = block.timestamp;
//     vm.warp(_timeUntilPermission);

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
//     );

//     assertEq(
//       newStrategy.getApprovalQuantityAt(_policyHolder, _role, _referenceTime),
//       0 // there should be zero quantity before permission was granted
//     );
//   }

//   function testFuzz_ReturnsQuantityAfterBlockThatAccountGainedPermission(
//     uint256 _timeSincePermission, // no assume for this param, we want 0 tested
//     bytes32 _permission,
//     uint8 _role,
//     address _policyHolder
//   ) public {
//     vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
//     vm.assume(_role > 0);
//     vm.assume(_permission > bytes32(0));
//     vm.assume(_policyHolder != address(0));

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
//     );
//     vm.warp(_timeSincePermission);
//     assertEq(
//       newStrategy.getApprovalQuantityAt(
//         _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
//       ),
//       1 // the account should still have the quantity
//     );
//   }

//   function testFuzz_ReturnsZeroQuantityForNonPolicyHolders(uint64 _timestamp, uint8 _role, address _nonPolicyHolder)
//     public
//   {
//     _timestamp = uint64(bound(_timestamp, block.timestamp + 1, type(uint64).max));
//     vm.assume(_nonPolicyHolder != address(0));
//     vm.assume(_nonPolicyHolder != address(0xdeadbeef)); // Given a policy below.
//     vm.assume(mpPolicy.balanceOf(_nonPolicyHolder) == 0);
//     vm.assume(_role != 0);

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       _role, bytes32(0), address(0xdeadbeef), 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new
// uint8[](0)
//     );

//     vm.warp(_timestamp);

//     assertEq(
//       newStrategy.getApprovalQuantityAt(_nonPolicyHolder, _role, _timestamp - 1),
//       0 // the account should not have a quantity
//     );
//   }

//   function testFuzz_ReturnsDefaultQuantityForPolicyHolderWithoutExplicitQuantity(
//     uint256 _timestamp,
//     uint8 _role,
//     address _policyHolder
//   ) public {
//     _timestamp = bound(_timestamp, block.timestamp - 1, type(uint64).max);
//     _role = uint8(bound(_role, 8, 255)); // ignoring all roles in the test setup to avoid conflicts with pre-assigned
//       // roles
//     vm.assume(_policyHolder != address(0));

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       _policyHolder,
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );

//     vm.warp(_timestamp);

//     assertEq(
//       newStrategy.getApprovalQuantityAt(_policyHolder, _role, _timestamp - 1),
//       0 // the account should not have a quantity
//     );
//   }

//   function testFuzz_ReturnsZeroForNonApprovalRoles(uint8 _role, address _policyHolder, uint128 _quantity) public {
//     _role = uint8(bound(_role, 1, 8)); // only using roles in the test setup to avoid having to create new roles
//     vm.assume(_role != uint8(Roles.TestRole1));
//     vm.assume(_policyHolder != address(0));
//     vm.assume(mpPolicy.balanceOf(_policyHolder) == 0);
//     _quantity = uint128(bound(_quantity, 1, type(uint128).max - mpPolicy.getRoleSupplyAsQuantitySum(_role)));

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(0xdeadbeef),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );

//     vm.prank(address(mpExecutor));
//     mpPolicy.setRoleHolder(_role, _policyHolder, _quantity, type(uint64).max);

//     assertEq(newStrategy.getApprovalQuantityAt(address(0xdeadbeef), uint8(Roles.TestRole2), block.timestamp), 0);
//   }
// }

// contract GetDisapprovalQuantityAt is LlamaStrategyTest {
//   function testFuzz_ReturnsZeroQuantityPriorToAccountGainingPermission(
//     uint256 _timeUntilPermission,
//     bytes32 _permission,
//     uint8 _role,
//     address _policyHolder
//   ) public {
//     vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
//     vm.assume(_role > 0);
//     vm.assume(_permission > bytes32(0));
//     vm.assume(_policyHolder != address(0));
//     uint256 _referenceTime = block.timestamp;
//     vm.warp(_timeUntilPermission);

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
//     );

//     assertEq(
//       newStrategy.getDisapprovalQuantityAt(_policyHolder, _role, _referenceTime),
//       0 // there should be zero quantity before permission was granted
//     );
//   }

//   function testFuzz_ReturnsQuantityAfterBlockThatAccountGainedPermission(
//     uint256 _timeSincePermission, // no assume for this param, we want 0 tested
//     bytes32 _permission,
//     uint8 _role,
//     address _policyHolder
//   ) public {
//     vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
//     vm.assume(_role > 0);
//     vm.assume(_permission > bytes32(0));
//     vm.assume(_policyHolder != address(0));

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
//     );
//     vm.warp(_timeSincePermission);
//     assertEq(
//       newStrategy.getDisapprovalQuantityAt(
//         _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
//       ),
//       1 // the account should still have the quantity
//     );
//   }

//   function testFuzz_ReturnsZeroQuantityForNonPolicyHolders(uint256 _timestamp, uint8 _role, address _nonPolicyHolder)
//     public
//   {
//     vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
//     vm.assume(_nonPolicyHolder != address(0));
//     vm.assume(_nonPolicyHolder != address(0xdeadbeef)); // Given a policy below.
//     vm.assume(mpPolicy.balanceOf(_nonPolicyHolder) == 0);
//     vm.assume(_role != 0);

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       _role, bytes32(0), address(0xdeadbeef), 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new
// uint8[](0)
//     );

//     vm.warp(_timestamp);

//     assertEq(
//       newStrategy.getDisapprovalQuantityAt(_nonPolicyHolder, _role, _timestamp - 1),
//       0 // the account should not have a quantity
//     );
//   }

//   function testFuzz_ReturnsDefaultQuantityForPolicyHolderWithoutExplicitQuantity(
//     uint256 _timestamp,
//     uint8 _role,
//     address _policyHolder
//   ) public {
//     _timestamp = bound(_timestamp, block.timestamp - 1, type(uint64).max);
//     _role = uint8(bound(_role, 8, 255)); // ignoring all roles in the test setup to avoid conflicts with pre-assigned
//       // roles
//     vm.assume(_policyHolder != address(0));

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       _policyHolder,
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );

//     vm.warp(_timestamp);

//     assertEq(
//       newStrategy.getDisapprovalQuantityAt(_policyHolder, _role, _timestamp - 1),
//       0 // the account should not have a quantity
//     );
//   }

//   function testFuzz_ReturnsZeroForNonApprovalRoles(uint8 _role, address _policyHolder, uint128 _quantity) public {
//     _role = uint8(bound(_role, 1, 8)); // ignoring all roles in the test setup to avoid conflicts with pre-assigned
//       // roles
//     vm.assume(_role != uint8(Roles.TestRole1));
//     vm.assume(_policyHolder != address(0));
//     vm.assume(mpPolicy.balanceOf(_policyHolder) == 0);
//     _quantity = uint128(bound(_quantity, 1, type(uint128).max - mpPolicy.getRoleSupplyAsQuantitySum(_role)));

//     ILlamaStrategy newStrategy = deployRelativeQuorumAndSetRole(
//       uint8(Roles.TestRole1),
//       bytes32(0),
//       address(0xdeadbeef),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       4000,
//       2000,
//       new uint8[](0),
//       new uint8[](0)
//     );

//     vm.prank(address(mpExecutor));
//     mpPolicy.setRoleHolder(_role, _policyHolder, _quantity, type(uint64).max);

//     assertEq(newStrategy.getDisapprovalQuantityAt(address(0xdeadbeef), uint8(Roles.TestRole2), block.timestamp), 0);
//   }
// }

// contract RelativeQuorumHarness is LlamaRelativeQuorum {
//   function exposed_getMinimumAmountNeeded(uint256 supply, uint256 minPct) external pure returns (uint256) {
//     return _getMinimumAmountNeeded(supply, minPct);
//   }
// }

// contract GetMinimumAmountNeeded is LlamaStrategyTest {
//   function testFuzz_calculatesMinimumAmountCorrectly(uint256 supply, uint256 minPct) public {
//     RelativeQuorumHarness newStrategy = new RelativeQuorumHarness();
//     minPct = bound(minPct, 0, 10_000);
//     vm.assume(minPct == 0 || supply <= type(uint256).max / minPct); // avoid solmate revert statement

//     uint256 product = FixedPointMathLib.mulDivUp(supply, minPct, 10_000);
//     assertEq(newStrategy.exposed_getMinimumAmountNeeded(supply, minPct), product);
//   }
// }

// contract ValidateActionCreation is LlamaStrategyTest {
//   function createAbsolutePeerReviewWithDisproportionateQuantity(
//     bool isApproval,
//     uint128 threshold,
//     uint256 _roleQuantity,
//     uint256 _otherRoleHolders
//   ) internal returns (ILlamaStrategy testStrategy) {
//     _roleQuantity = bound(_roleQuantity, 100, 1000);
//     _otherRoleHolders = bound(_otherRoleHolders, 1, 10);

//     vm.prank(address(mpExecutor));
//     mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(this), uint128(_roleQuantity), type(uint64).max);

//     generateAndSetRoleHolders(_otherRoleHolders);

//     vm.prank(address(rootExecutor));
//     factory.authorizeStrategyLogic(absolutePeerReviewLogic);

//     testStrategy = deployAbsolutePeerReview(
//       uint8(Roles.TestRole1),
//       uint8(Roles.Disapprover),
//       1 days,
//       4 days,
//       1 days,
//       false,
//       isApproval ? threshold : 0,
//       isApproval ? 0 : threshold,
//       new uint8[](0),
//       new uint8[](0)
//     );

//     bytes32 newPermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy));

//     vm.prank(address(mpExecutor));
//     mpPolicy.setRolePermission(uint8(Roles.TestRole1), newPermissionId, true);
//   }

//   function testFuzz_RevertIf_AbsolutePeerReview_NotEnoughApprovalQuantity(
//     uint256 _roleQuantity,
//     uint256 _otherRoleHolders
//   ) external {
//     _roleQuantity = bound(_roleQuantity, 100, 1000);
//     uint256 threshold = _roleQuantity / 2;
//     ILlamaStrategy testStrategy =
//       createAbsolutePeerReviewWithDisproportionateQuantity(true, toUint128(threshold), _roleQuantity,
// _otherRoleHolders);

//     vm.expectRevert(LlamaAbsoluteStrategyBase.InsufficientApprovalQuantity.selector);
//     mpCore.createAction(
//       uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
//     );
//   }

//   function testFuzz_RevertIf_AbsolutePeerReview_NotEnoughDisapprovalQuantity(
//     uint256 _roleQuantity,
//     uint256 _otherRoleHolders
//   ) external {
//     _roleQuantity = bound(_roleQuantity, 100, 1000);
//     uint256 threshold = _roleQuantity / 2;

//     ILlamaStrategy testStrategy = createAbsolutePeerReviewWithDisproportionateQuantity(
//       false, toUint128(threshold), _roleQuantity, _otherRoleHolders
//     );

//     vm.expectRevert(LlamaAbsoluteStrategyBase.InsufficientDisapprovalQuantity.selector);
//     mpCore.createAction(
//       uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
//     );
//   }

//   function testFuzz_AbsolutePeerReview_DisableDisapprovals(uint256 _roleQuantity, uint256 _otherRoleHolders) external
// {
//     ILlamaStrategy testStrategy =
//       createAbsolutePeerReviewWithDisproportionateQuantity(false, type(uint128).max, _roleQuantity,
// _otherRoleHolders);

//     uint256 actionId = mpCore.createAction(
//       uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
//     );
//     ActionInfo memory actionInfo = ActionInfo(
//       actionId,
//       address(this),
//       uint8(Roles.TestRole1),
//       testStrategy,
//       address(mockProtocol),
//       0,
//       abi.encodeCall(MockProtocol.pause, (true))
//     );

//     vm.warp(block.timestamp + 1);

//     mpCore.queueAction(actionInfo);

//     vm.expectRevert(LlamaAbsoluteStrategyBase.DisapprovalDisabled.selector);

//     mpCore.castDisapproval(uint8(Roles.TestRole1), actionInfo, "");
//   }

//   function test_CalculateSupplyWhenActionCreatorDoesNotHaveRole(uint256 _numberOfPolicies) external {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);

//     ILlamaStrategy testStrategy = deployTestStrategy();

//     generateAndSetRoleHolders(_numberOfPolicies);

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     assertEq(LlamaRelativeQuorum(address(testStrategy)).actionApprovalSupply(actionInfo.id), _numberOfPolicies);
//     assertEq(LlamaRelativeQuorum(address(testStrategy)).actionDisapprovalSupply(actionInfo.id), _numberOfPolicies);
//   }

//   function test_CalculateSupplyWhenActionCreatorHasRole(uint256 _numberOfPolicies, uint256 _creatorQuantity) external
// {
//     _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
//     _creatorQuantity = bound(_creatorQuantity, 1, 1000);

//     ILlamaStrategy testStrategy = deployTestStrategy();

//     generateAndSetRoleHolders(_numberOfPolicies);

//     vm.prank(address(mpExecutor));
//     mpPolicy.setRoleHolder(uint8(Roles.TestRole1), actionCreatorAaron, uint128(_creatorQuantity), type(uint64).max);

//     uint256 supply = mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1));

//     ActionInfo memory actionInfo = createAction(testStrategy);

//     assertEq(LlamaRelativeQuorum(address(testStrategy)).actionApprovalSupply(actionInfo.id), supply);
//     assertEq(LlamaRelativeQuorum(address(testStrategy)).actionDisapprovalSupply(actionInfo.id), supply);
//   }
// }

// contract IsApprovalEnabledRelative is LlamaStrategyTest {
//   function test_PassesWhenCorrectRoleIsPassed() public {
//     ActionInfo memory actionInfo = createAction(mpStrategy1);
//     mpStrategy1.isApprovalEnabled(actionInfo, address(0), uint8(Roles.Approver)); // address and actionInfo are not
// used
//   }

//   function test_RevertIf_WrongRoleIsPassed() public {
//     ActionInfo memory actionInfo = createAction(mpStrategy1);
//     vm.expectRevert(abi.encodeWithSelector(LlamaRelativeQuorum.InvalidRole.selector, uint8(Roles.Approver)));
//     mpStrategy1.isApprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1)); // address and actionInfo are not
//       // used
//   }
// }

// contract IsDisapprovalEnabledRelative is LlamaStrategyTest {
//   function test_PassesWhenCorrectRoleIsPassed() public {
//     ActionInfo memory actionInfo = createAction(mpStrategy1);
//     mpStrategy1.isDisapprovalEnabled(actionInfo, address(0), uint8(Roles.Disapprover)); // address and actionInfo are
//       // not used
//   }

//   function test_RevertIf_WrongRoleIsPassed() public {
//     ActionInfo memory actionInfo = createAction(mpStrategy1);
//     vm.expectRevert(abi.encodeWithSelector(LlamaRelativeQuorum.InvalidRole.selector, uint8(Roles.Disapprover)));
//     mpStrategy1.isDisapprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1)); // address and actionInfo are
// not
//       // used
//   }
// }

// contract IsApprovalEnabledAbsolute is LlamaStrategyTest {
//   function test_AbsolutePeerReview_PassesWhenCorrectRoleIsPassed() public {
//     ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
//       uint8(Roles.Approver),
//       uint8(Roles.Disapprover),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       2,
//       0,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     ActionInfo memory actionInfo = createAction(absolutePeerReview);
//     absolutePeerReview.isApprovalEnabled(actionInfo, address(0), uint8(Roles.Approver));
//   }

//   function test_RevertIf_AbsolutePeerReview_WrongRoleIsPassed() public {
//     ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
//       uint8(Roles.Approver),
//       uint8(Roles.Disapprover),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       2,
//       0,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     ActionInfo memory actionInfo = createAction(absolutePeerReview);
//     vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.Approver)));
//     absolutePeerReview.isApprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
//   }

//   function test_AbsolutePeerReview_ActionCreatorCannotApprove() public {
//     ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
//       uint8(Roles.Approver),
//       uint8(Roles.Disapprover),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       2,
//       0,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     ActionInfo memory actionInfo = createAction(absolutePeerReview);
//     vm.expectRevert(LlamaAbsolutePeerReview.ActionCreatorCannotCast.selector);
//     absolutePeerReview.isApprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Approver));
//   }

//   function test_AbsoluteQuorum_ActionCreatorCanApprove() public {
//     ILlamaStrategy absoluteQuorum = deployAbsoluteQuorum(
//       uint8(Roles.Approver),
//       uint8(Roles.Disapprover),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       2,
//       0,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     ActionInfo memory actionInfo = createAction(absoluteQuorum);
//     // function reverts if approval disabled, so it not reverting is behavior we are testing
//     absoluteQuorum.isApprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Approver));
//   }
// }

// contract IsDisapprovalEnabledAbsolute is LlamaStrategyTest {
//   function test_AbsolutePeerReview_PassesWhenCorrectRoleIsPassed() public {
//     ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
//       uint8(Roles.Approver),
//       uint8(Roles.Disapprover),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       2,
//       0,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     ActionInfo memory actionInfo = createAction(absolutePeerReview);
//     absolutePeerReview.isDisapprovalEnabled(actionInfo, address(0), uint8(Roles.Disapprover));
//   }

//   function test_RevertIf_AbsolutePeerReview_WrongRoleIsPassed() public {
//     ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
//       uint8(Roles.Approver),
//       uint8(Roles.Disapprover),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       2,
//       0,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     ActionInfo memory actionInfo = createAction(absolutePeerReview);
//     vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector,
// uint8(Roles.Disapprover)));
//     absolutePeerReview.isDisapprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
//   }

//   function test_AbsolutePeerReview_ActionCreatorCannotDisapprove() public {
//     ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
//       uint8(Roles.Approver),
//       uint8(Roles.Disapprover),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       2,
//       0,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     ActionInfo memory actionInfo = createAction(absolutePeerReview);
//     vm.expectRevert(LlamaAbsolutePeerReview.ActionCreatorCannotCast.selector);
//     absolutePeerReview.isDisapprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Disapprover));
//   }

//   function test_AbsoluteQuorum_ActionCreatorCanDisapprove() public {
//     ILlamaStrategy absoluteQuorum = deployAbsoluteQuorum(
//       uint8(Roles.Approver),
//       uint8(Roles.Disapprover),
//       1 days,
//       4 days,
//       1 days,
//       true,
//       2,
//       0,
//       new uint8[](0),
//       new uint8[](0)
//     );
//     ActionInfo memory actionInfo = createAction(absoluteQuorum);
//     // function reverts if disapproval is disabled, so it not reverting is behavior we are testing
//     absoluteQuorum.isDisapprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Disapprover));
//   }
// }
