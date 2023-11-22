// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {Action, ActionInfo, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaGovernanceScript} from "src/llama-scripts/LlamaGovernanceScript.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaRelativeStrategyBase} from "src/strategies/relative/LlamaRelativeStrategyBase.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract LlamaGovernanceScriptTest is LlamaTestSetup {
  event AccountCreated(ILlamaAccount account, ILlamaAccount indexed accountLogic, bytes initializationData);
  event RoleAssigned(address indexed policyholder, uint8 indexed role, uint64 expiration, uint96 quantity);
  event RoleInitialized(uint8 indexed role, RoleDescription description);
  event RolePermissionAssigned(
    uint8 indexed role, bytes32 indexed permissionId, PermissionData permissionData, bool hasPermission
  );
  event StrategyAuthorizationSet(ILlamaStrategy indexed strategy, bool authorized);
  event StrategyCreated(ILlamaStrategy strategy, ILlamaStrategy indexed strategyLogic, bytes initializationData);

  mapping(uint8 => uint96) public rolesHoldersSeen;
  mapping(uint8 => uint96) public rolesQuantitySeen;

  LlamaGovernanceScript governanceScript;

  bytes4 public constant AGGREGATE_SELECTOR = LlamaGovernanceScript.aggregate.selector;
  bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaGovernanceScript.initializeRolesAndSetRoleHolders.selector;
  bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaGovernanceScript.initializeRolesAndSetRolePermissions.selector;
  bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaGovernanceScript.initializeRolesAndSetRoleHoldersAndSetRolePermissions.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaGovernanceScript.createNewStrategiesAndSetRoleHolders.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaGovernanceScript.createNewStrategiesAndInitializeRolesAndSetRoleHolders.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaGovernanceScript.createNewStrategiesAndSetRolePermissions.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_NEW_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaGovernanceScript.createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissions.selector;
  bytes4 public constant REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR =
    LlamaGovernanceScript.revokePoliciesAndUpdateRoleDescriptions.selector;
  bytes4 public constant REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaGovernanceScript.revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders.selector;
  bytes4 public constant INITIALIZE_ROLES_SELECTOR = LlamaGovernanceScript.initializeRoles.selector;
  bytes4 public constant SET_ROLE_HOLDERS_SELECTOR = LlamaGovernanceScript.setRoleHolders.selector;
  bytes4 public constant SET_ROLE_PERMISSIONS_SELECTOR = LlamaGovernanceScript.setRolePermissions.selector;
  bytes4 public constant REVOKE_POLICIES_SELECTOR = LlamaGovernanceScript.revokePolicies.selector;
  bytes4 public constant UPDATE_ROLE_DESCRIPTIONS_SELECTOR = LlamaGovernanceScript.updateRoleDescriptions.selector;

  PermissionData public executeActionPermission;
  PermissionData public aggregatePermission;
  PermissionData public initializeRolesAndSetRoleHoldersPermission;
  PermissionData public initializeRolesAndSetRolePermissionsPermission;
  PermissionData public initializeRolesAndSetRoleHoldersAndSetRolePermissionsPermission;
  PermissionData public createNewStrategiesAndSetRoleHoldersPermission;
  PermissionData public createNewStrategiesAndInitializeRolesAndSetRoleHoldersPermission;
  PermissionData public createNewStrategiesAndSetRolePermissionsPermission;
  PermissionData public createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissionsPermission;
  PermissionData public revokePoliciesAndUpdateRoleDescriptionsPermission;
  PermissionData public revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHoldersPermission;
  PermissionData public initializeRolesPermission;
  PermissionData public setRoleHoldersPermission;
  PermissionData public setRolePermissionsPermission;
  PermissionData public revokePoliciesPermission;
  PermissionData public updateRoleDescriptionPerimssion;

  function setUp() public virtual override {
    LlamaTestSetup.setUp();

    governanceScript = new LlamaGovernanceScript();

    vm.startPrank(address(mpExecutor));

    mpCore.setScriptAuthorization(address(governanceScript), true);

    executeActionPermission = PermissionData(address(governanceScript), EXECUTE_ACTION_SELECTOR, mpStrategy2);
    aggregatePermission = PermissionData(address(governanceScript), AGGREGATE_SELECTOR, mpStrategy2);
    initializeRolesAndSetRoleHoldersPermission =
      PermissionData(address(governanceScript), INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy2);
    initializeRolesAndSetRolePermissionsPermission =
      PermissionData(address(governanceScript), INITIALIZE_ROLES_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2);
    initializeRolesAndSetRoleHoldersAndSetRolePermissionsPermission = PermissionData(
      address(governanceScript), INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2
    );
    createNewStrategiesAndSetRoleHoldersPermission =
      PermissionData(address(governanceScript), CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy2);
    createNewStrategiesAndInitializeRolesAndSetRoleHoldersPermission = PermissionData(
      address(governanceScript), CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy2
    );
    createNewStrategiesAndSetRolePermissionsPermission =
      PermissionData(address(governanceScript), CREATE_NEW_STRATEGIES_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2);
    createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissionsPermission = PermissionData(
      address(governanceScript),
      CREATE_NEW_STRATEGIES_AND_NEW_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR,
      mpStrategy2
    );
    revokePoliciesAndUpdateRoleDescriptionsPermission =
      PermissionData(address(governanceScript), REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR, mpStrategy2);
    revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHoldersPermission = PermissionData(
      address(governanceScript), REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy2
    );
    initializeRolesPermission = PermissionData(address(governanceScript), INITIALIZE_ROLES_SELECTOR, mpStrategy2);
    setRoleHoldersPermission = PermissionData(address(governanceScript), SET_ROLE_HOLDERS_SELECTOR, mpStrategy2);
    setRolePermissionsPermission = PermissionData(address(governanceScript), SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2);
    revokePoliciesPermission = PermissionData(address(governanceScript), REVOKE_POLICIES_SELECTOR, mpStrategy2);
    updateRoleDescriptionPerimssion =
      PermissionData(address(governanceScript), UPDATE_ROLE_DESCRIPTIONS_SELECTOR, mpStrategy2);

    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), executeActionPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), aggregatePermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesAndSetRoleHoldersPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesAndSetRolePermissionsPermission, true);
    mpPolicy.setRolePermission(
      uint8(Roles.ActionCreator), initializeRolesAndSetRoleHoldersAndSetRolePermissionsPermission, true
    );
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), createNewStrategiesAndSetRoleHoldersPermission, true);
    mpPolicy.setRolePermission(
      uint8(Roles.ActionCreator), createNewStrategiesAndInitializeRolesAndSetRoleHoldersPermission, true
    );
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), createNewStrategiesAndSetRolePermissionsPermission, true);
    mpPolicy.setRolePermission(
      uint8(Roles.ActionCreator), createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissionsPermission, true
    );
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokePoliciesAndUpdateRoleDescriptionsPermission, true);
    mpPolicy.setRolePermission(
      uint8(Roles.ActionCreator), revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHoldersPermission, true
    );
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setRoleHoldersPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setRolePermissionsPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokePoliciesPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), updateRoleDescriptionPerimssion, true);

    vm.stopPrank();
  }

  function _approveAction(ActionInfo memory actionInfo) internal {
    vm.warp(block.timestamp + 1);
    vm.prank(approverAdam);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
    vm.prank(approverAlicia);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
    vm.prank(approverAndy);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, ""); // Approves and queues the action.
  }

  function _createStrategy(uint256 salt, bool isFixedLengthApprovalPeriod)
    internal
    pure
    returns (LlamaRelativeStrategyBase.Config memory)
  {
    return LlamaRelativeStrategyBase.Config({
      approvalPeriod: toUint64(salt % 1000 days),
      queuingPeriod: toUint64(salt % 1001 days),
      expirationPeriod: toUint64(salt % 1002 days),
      isFixedLengthApprovalPeriod: isFixedLengthApprovalPeriod,
      minApprovalPct: toUint16(salt % 10_000),
      minDisapprovalPct: toUint16(salt % 10_100),
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });
  }

  function _assumeInitializeRoles(RoleDescription[] memory descriptions) public {
    vm.assume(descriptions.length < 247); // max unit8 (255) - total number of exisitng roles (8)
  }

  function _assumeRoleHolders(RoleHolderData[] memory roleHolders) public {
    vm.assume(roleHolders.length < 50);
    for (uint256 i = 0; i < roleHolders.length; i++) {
      // Cannot be 0 (all holders role) and cannot be greater than numRoles
      roleHolders[i].role = uint8(bound(roleHolders[i].role, 1, mpPolicy.numRoles()));
      vm.assume(roleHolders[i].expiration > block.timestamp + 1 days);
      vm.assume(roleHolders[i].policyholder != address(0));
      roleHolders[i].quantity = uint96(bound(roleHolders[i].quantity, 1, 100));
    }
  }

  function _boundRolePermissions(RolePermissionData[] memory rolePermissions) public {
    for (uint256 i = 0; i < rolePermissions.length; i++) {
      // Cannot be 0 (all holders role) and cannot be greater than numRoles
      rolePermissions[i].role = uint8(bound(rolePermissions[i].role, 1, mpPolicy.numRoles()));
    }
  }
}

contract Aggregate is LlamaGovernanceScriptTest {
  address[] public targets;
  bytes[] public calls;

  function test_aggregate(RoleDescription[] memory descriptions) public {
    _assumeInitializeRoles(descriptions);
    for (uint256 i = 0; i < descriptions.length; i++) {
      targets.push(address(mpPolicy));
      calls.push(abi.encodeWithSelector(LlamaPolicy.initializeRole.selector, descriptions[i]));

      targets.push(address(mpPolicy));
      calls.push(
        abi.encodeWithSelector(
          LlamaPolicy.setRoleHolder.selector, uint8(i + 9), address(uint160(i + 101)), 1, type(uint64).max
        )
      );
    }

    LlamaAccount.Config[] memory newAccounts = new LlamaAccount.Config[](1);
    newAccounts[0] = LlamaAccount.Config({name: "new treasury"});

    ILlamaAccount[] memory accountAddresses = new ILlamaAccount[](1);
    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeLlamaAccountAddress(
        address(accountLogic), DeployUtils.encodeAccount(newAccounts[i]), address(mpCore)
      );
    }

    targets.push(address(mpCore));
    calls.push(abi.encodeWithSelector(0x90010bb0, accountLogic, DeployUtils.encodeAccountConfigs(newAccounts)));

    bytes memory data = abi.encodeWithSelector(AGGREGATE_SELECTOR, targets, calls);

    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");

    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);

    for (uint256 i = 0; i < descriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i + 9), descriptions[i]);
      vm.expectEmit();
      emit RoleAssigned(address(uint160(i + 101)), uint8(i + 9), type(uint64).max, 1);
    }
    vm.expectEmit();
    emit AccountCreated(accountAddresses[0], accountLogic, DeployUtils.encodeAccount(newAccounts[0]));
    mpCore.executeAction(actionInfo);
  }
}

// TODO: write tests for all of the functions below

contract InitializeRolesAndSetRoleHolders is LlamaGovernanceScriptTest {
  function testFuzz_initializeRolesAndSetRoleHolders(
    RoleDescription[] memory descriptions,
    RoleHolderData[] memory roleHolders
  ) public {
    _assumeInitializeRoles(descriptions);
    _assumeRoleHolders(roleHolders);

    bytes memory data =
      abi.encodeWithSelector(INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, descriptions, roleHolders);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");
    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    for (uint256 i = 0; i < descriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i + 9), descriptions[i]);
    }
    for (uint256 i = 0; i < roleHolders.length; i++) {
      vm.expectEmit();
      emit RoleAssigned(
        roleHolders[i].policyholder, roleHolders[i].role, roleHolders[i].expiration, roleHolders[i].quantity
      );
      rolesHoldersSeen[roleHolders[i].role]++;
      rolesQuantitySeen[roleHolders[i].role] += roleHolders[i].quantity;
    }
    mpCore.executeAction(actionInfo);
  }
}

contract InitializeRolesAndSetRolePermissions is LlamaGovernanceScriptTest {
  function test_initializesRolesAndSetRolePermissions(
    RoleDescription[] memory descriptions,
    RolePermissionData[] memory rolePermissions
  ) public {
    vm.assume(rolePermissions.length < 50);
    _assumeInitializeRoles(descriptions);
    _boundRolePermissions(rolePermissions);

    bytes memory data =
      abi.encodeWithSelector(INITIALIZE_ROLES_AND_SET_ROLE_PERMISSIONS_SELECTOR, descriptions, rolePermissions);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");
    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    for (uint256 i = 0; i < descriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i + 9), descriptions[i]);
    }
    for (uint256 i = 0; i < rolePermissions.length; i++) {
      bytes32 permissionId = lens.computePermissionId(rolePermissions[i].permissionData);
      vm.expectEmit();
      emit RolePermissionAssigned(
        rolePermissions[i].role, permissionId, rolePermissions[i].permissionData, rolePermissions[i].hasPermission
      );
    }
    mpCore.executeAction(actionInfo);
  }
}

contract InitializeRolesAndSetRoleHoldersAndSetRolePermissions is LlamaGovernanceScriptTest {
  function test_InitializeRolesAndSetRoleHoldersAndSetRolePermissions(
    RoleDescription[] memory descriptions,
    RolePermissionData[] memory rolePermissions
  ) public {
    vm.assume(rolePermissions.length < 10);
    _assumeInitializeRoles(descriptions);
    _boundRolePermissions(rolePermissions);

    RoleHolderData[] memory roleHolders = new RoleHolderData[](1); // we don't fuzz the roleholders here because the test takes too long
    roleHolders[0] = RoleHolderData({
      policyholder: address(uint160(1)),
      role: uint8(Roles.ActionCreator),
      expiration: type(uint64).max,
      quantity: 1
    });

    bytes memory data = abi.encodeWithSelector(
      INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR,
      descriptions,
      roleHolders,
      rolePermissions
    );
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");
    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    for (uint256 i = 0; i < descriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i + 9), descriptions[i]);
    }
    for (uint256 i = 0; i < roleHolders.length; i++) {
      vm.expectEmit();
      emit RoleAssigned(
        roleHolders[i].policyholder, roleHolders[i].role, roleHolders[i].expiration, roleHolders[i].quantity
      );
      rolesHoldersSeen[roleHolders[i].role]++;
      rolesQuantitySeen[roleHolders[i].role] += roleHolders[i].quantity;
    }
    for (uint256 i = 0; i < rolePermissions.length; i++) {
      bytes32 permissionId = lens.computePermissionId(rolePermissions[i].permissionData);
      vm.expectEmit();
      emit RolePermissionAssigned(
        rolePermissions[i].role, permissionId, rolePermissions[i].permissionData, rolePermissions[i].hasPermission
      );
    }
    mpCore.executeAction(actionInfo);
  }
}

contract CreateNewStrategiesAndSetRoleHolders is LlamaGovernanceScriptTest {
  function test_CreateNewStrategiesAndSetRoleHolders(
    RoleHolderData[] memory roleHolders,
    uint256 salt1,
    uint256 salt2,
    uint256 salt3,
    bool isFixedLengthApprovalPeriod
  ) public {
    _assumeRoleHolders(roleHolders);

    LlamaRelativeStrategyBase.Config[] memory newStrategies = new LlamaRelativeStrategyBase.Config[](3);
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);

    vm.assume(salt1 != salt2);
    vm.assume(salt1 != salt3);
    vm.assume(salt2 != salt3);

    newStrategies[0] = _createStrategy(salt1, isFixedLengthApprovalPeriod);
    newStrategies[1] = _createStrategy(salt2, isFixedLengthApprovalPeriod);
    newStrategies[2] = _createStrategy(salt3, isFixedLengthApprovalPeriod);

    LlamaGovernanceScript.CreateStrategies memory strategies;
    strategies.llamaStrategyLogic = relativeHolderQuorumLogic;
    strategies.strategies = DeployUtils.encodeStrategyConfigs(newStrategies);

    bytes memory data =
      abi.encodeWithSelector(CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR, strategies, roleHolders);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");

    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );

    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);

    for (uint256 i = 0; i < newStrategies.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeHolderQuorumLogic), DeployUtils.encodeStrategy(newStrategies[i]), address(mpCore)
      );
    }

    vm.startPrank(address(mpExecutor));

    vm.expectEmit();
    emit StrategyAuthorizationSet(strategyAddresses[0], true);
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[0], relativeHolderQuorumLogic, DeployUtils.encodeStrategy(newStrategies[0]));

    vm.expectEmit();
    emit StrategyAuthorizationSet(strategyAddresses[1], true);
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[1], relativeHolderQuorumLogic, DeployUtils.encodeStrategy(newStrategies[1]));

    vm.expectEmit();
    emit StrategyAuthorizationSet(strategyAddresses[2], true);
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[2], relativeHolderQuorumLogic, DeployUtils.encodeStrategy(newStrategies[2]));

    for (uint256 i = 0; i < roleHolders.length; i++) {
      vm.expectEmit();
      emit RoleAssigned(
        roleHolders[i].policyholder, roleHolders[i].role, roleHolders[i].expiration, roleHolders[i].quantity
      );
      rolesHoldersSeen[roleHolders[i].role]++;
      rolesQuantitySeen[roleHolders[i].role] += roleHolders[i].quantity;
    }
    mpCore.executeAction(actionInfo);
  }
}

contract CreateNewStrategiesAndInitializeRolesAndSetRoleHolders is LlamaGovernanceScriptTest {
  function test_CreateNewStrategiesAndSetRoleHolders(
    RoleDescription[] memory descriptions,
    RoleHolderData[] memory roleHolders,
    uint256 salt1,
    uint256 salt2,
    uint256 salt3,
    bool isFixedLengthApprovalPeriod
  ) public {
    _assumeInitializeRoles(descriptions);
    _assumeRoleHolders(roleHolders);

    LlamaRelativeStrategyBase.Config[] memory newStrategies = new LlamaRelativeStrategyBase.Config[](3);
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);

    vm.assume(salt1 != salt2);
    vm.assume(salt1 != salt3);
    vm.assume(salt2 != salt3);

    newStrategies[0] = _createStrategy(salt1, isFixedLengthApprovalPeriod);
    newStrategies[1] = _createStrategy(salt2, isFixedLengthApprovalPeriod);
    newStrategies[2] = _createStrategy(salt3, isFixedLengthApprovalPeriod);

    LlamaGovernanceScript.CreateStrategies memory strategies;
    strategies.llamaStrategyLogic = relativeHolderQuorumLogic;
    strategies.strategies = DeployUtils.encodeStrategyConfigs(newStrategies);

    bytes memory data =
      abi.encodeWithSelector(CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, strategies, descriptions, roleHolders);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");

    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );

    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);

    for (uint256 i = 0; i < newStrategies.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeHolderQuorumLogic), DeployUtils.encodeStrategy(newStrategies[i]), address(mpCore)
      );
    }

    vm.startPrank(address(mpExecutor));

    vm.expectEmit();
    emit StrategyAuthorizationSet(strategyAddresses[0], true);
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[0], relativeHolderQuorumLogic, DeployUtils.encodeStrategy(newStrategies[0]));

    vm.expectEmit();
    emit StrategyAuthorizationSet(strategyAddresses[1], true);
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[1], relativeHolderQuorumLogic, DeployUtils.encodeStrategy(newStrategies[1]));

    vm.expectEmit();
    emit StrategyAuthorizationSet(strategyAddresses[2], true);
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[2], relativeHolderQuorumLogic, DeployUtils.encodeStrategy(newStrategies[2]));
    for (uint256 i = 0; i < roleHolders.length; i++) {
      vm.expectEmit();
      emit RoleAssigned(
        roleHolders[i].policyholder, roleHolders[i].role, roleHolders[i].expiration, roleHolders[i].quantity
      );
    // TODO expect these events
    // for (uint256 j = 0; j < descriptions.length; j++) {
    //   vm.expectEmit();
    //   emit RoleInitialized(uint8(j + 9), descriptions[j]);
    // }
      rolesHoldersSeen[roleHolders[i].role]++;
      rolesQuantitySeen[roleHolders[i].role] += roleHolders[i].quantity;
    }
    mpCore.executeAction(actionInfo);
  }
}

contract CreateNewStrategiesAndSetRolePermissions is LlamaGovernanceScriptTest {}

contract CreateNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolesPermissions is LlamaGovernanceScriptTest {}

contract RevokePoliciesAndUpdateRoleDescriptions is LlamaGovernanceScriptTest {}

contract RevokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders is LlamaGovernanceScriptTest {}

contract InitializeRoles is LlamaGovernanceScriptTest {
  function testFuzz_initializeRoles(RoleDescription[] memory descriptions) public {
    _assumeInitializeRoles(descriptions);
    bytes memory data = abi.encodeWithSelector(INITIALIZE_ROLES_SELECTOR, descriptions);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");
    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    for (uint256 i = 0; i < descriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i + 9), descriptions[i]);
    }
    mpCore.executeAction(actionInfo);
  }
}

contract SetRoleHolders is LlamaGovernanceScriptTest {
  function testFuzz_setRoleHolders(RoleHolderData[] memory roleHolders) public {
    _assumeRoleHolders(roleHolders);
    bytes memory data = abi.encodeWithSelector(SET_ROLE_HOLDERS_SELECTOR, roleHolders);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");
    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    for (uint256 i = 0; i < roleHolders.length; i++) {
      vm.expectEmit();
      emit RoleAssigned(
        roleHolders[i].policyholder, roleHolders[i].role, roleHolders[i].expiration, roleHolders[i].quantity
      );
      rolesHoldersSeen[roleHolders[i].role]++;
      rolesQuantitySeen[roleHolders[i].role] += roleHolders[i].quantity;
    }
    mpCore.executeAction(actionInfo);
  }
}

contract SetRolePermissions is LlamaGovernanceScriptTest {
  function testFuzz_setRolePermissions(RolePermissionData[] memory rolePermissions) public {
    _boundRolePermissions(rolePermissions);
    bytes memory data = abi.encodeWithSelector(SET_ROLE_PERMISSIONS_SELECTOR, rolePermissions);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");
    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    for (uint256 i = 0; i < rolePermissions.length; i++) {
      bytes32 permissionId = lens.computePermissionId(rolePermissions[i].permissionData);
      vm.expectEmit();
      emit RolePermissionAssigned(
        rolePermissions[i].role, permissionId, rolePermissions[i].permissionData, rolePermissions[i].hasPermission
      );
    }
    mpCore.executeAction(actionInfo);
  }
}

contract RevokePolicies is LlamaGovernanceScriptTest {
  uint8[] public roles;
  address[] public revokePolicies;

  function test_revokePolicies() public {
    revokePolicies.push(disapproverDave);
    bytes memory data = abi.encodeWithSelector(REVOKE_POLICIES_SELECTOR, revokePolicies);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");
    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    vm.expectEmit();
    emit RoleAssigned(address(disapproverDave), uint8(Roles.Disapprover), 0, 0);
    mpCore.executeAction(actionInfo);
  }
}

contract UpdateRoleDescriptions is LlamaGovernanceScriptTest {
  function testFuzz_updateRoleDescriptions(LlamaGovernanceScript.UpdateRoleDescription[] memory roleDescriptions)
    public
  {
    vm.assume(roleDescriptions.length <= 9); //number of roles in the Roles enum
    for (uint256 i = 0; i < roleDescriptions.length; i++) {
      roleDescriptions[i].role = uint8(i);
    }
    vm.prank(actionCreatorAaron);
    bytes memory data = abi.encodeWithSelector(UPDATE_ROLE_DESCRIPTIONS_SELECTOR, roleDescriptions);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");
    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    _approveAction(actionInfo);
    for (uint256 i = 0; i < roleDescriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i), roleDescriptions[i].description);
    }
    mpCore.executeAction(actionInfo);
  }
}
