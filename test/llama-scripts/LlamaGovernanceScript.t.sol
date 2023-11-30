// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionInfo, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
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
  event StrategyLogicAuthorizationSet(ILlamaStrategy indexed strategyLogic, bool authorized);
  event StrategyCreated(ILlamaStrategy strategy, ILlamaStrategy indexed strategyLogic, bytes initializationData);

  mapping(uint8 => uint96) public rolesHoldersSeen;
  mapping(uint8 => uint96) public rolesQuantitySeen;

  uint8[] public roles;
  address[] public revokePolicies;

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
  bytes4 public constant
    CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR =
      LlamaGovernanceScript.createNewStrategiesAndInitializeRolesAndSetRoleHoldersAndSetRolePermissions.selector;
  bytes4 public constant REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR =
    LlamaGovernanceScript.revokePoliciesAndUpdateRoleDescriptions.selector;
  bytes4 public constant REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaGovernanceScript.revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders.selector;
  bytes4 public constant INITIALIZE_ROLES_SELECTOR = LlamaGovernanceScript.initializeRoles.selector;
  bytes4 public constant SET_ROLE_HOLDERS_SELECTOR = LlamaGovernanceScript.setRoleHolders.selector;
  bytes4 public constant SET_ROLE_PERMISSIONS_SELECTOR = LlamaGovernanceScript.setRolePermissions.selector;
  bytes4 public constant REVOKE_POLICIES_SELECTOR = LlamaGovernanceScript.revokePolicies.selector;
  bytes4 public constant UPDATE_ROLE_DESCRIPTIONS_SELECTOR = LlamaGovernanceScript.updateRoleDescriptions.selector;
  bytes4 public constant SET_STRATEGY_LOGIC_AUTHORIZATIONS_SELECTOR = LlamaGovernanceScript.setStrategyLogicAuthorizations.selector;
  bytes4 public constant SET_STRATEGY_AUTHORIZATIONS_SELECTOR = LlamaGovernanceScript.setStrategyAuthorizations.selector;

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
  PermissionData public setStrategyLogicAuthorizationsPermission;
  PermissionData public setStrategyAuthorizationsPermission;

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
      CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR,
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
    setStrategyLogicAuthorizationsPermission = PermissionData(
      address(governanceScript), SET_STRATEGY_LOGIC_AUTHORIZATIONS_SELECTOR, mpStrategy2
    );
    setStrategyAuthorizationsPermission = PermissionData(
      address(governanceScript), SET_STRATEGY_AUTHORIZATIONS_SELECTOR, mpStrategy2
    );

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
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setStrategyLogicAuthorizationsPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setStrategyAuthorizationsPermission, true);

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
    vm.assume(roleHolders.length < 10);
    for (uint256 i = 0; i < roleHolders.length; i++) {
      // Cannot be 0 (all holders role) and cannot be greater than numRoles
      roleHolders[i].role = uint8(bound(roleHolders[i].role, 1, mpPolicy.numRoles()));
      vm.assume(roleHolders[i].expiration > block.timestamp + 1 days);
      vm.assume(roleHolders[i].policyholder != address(0));
      roleHolders[i].quantity = uint96(bound(roleHolders[i].quantity, 1, 100));
    }
  }

  function _assumeStrategies(uint256 salt1, uint256 salt2, uint256 salt3) public {
    vm.assume(salt1 != salt2 && salt1 != salt3 && salt2 != salt3);
  }

  function _assumeUpdateRoleDescriptions(LlamaGovernanceScript.UpdateRoleDescription[] memory descriptions) internal {
    vm.assume(descriptions.length <= 9); //number of roles in the Roles enum
    for (uint256 i = 0; i < descriptions.length; i++) {
      descriptions[i].role = uint8(i);
    }
  }

  function _boundRolePermissions(RolePermissionData[] memory rolePermissions) public {
    for (uint256 i = 0; i < rolePermissions.length; i++) {
      // Cannot be 0 (all holders role) and cannot be greater than numRoles
      rolePermissions[i].role = uint8(bound(rolePermissions[i].role, 1, mpPolicy.numRoles()));
    }
  }

  function _createAction(bytes memory data) internal returns (ActionInfo memory actionInfo, uint256 actionId) {
    vm.prank(actionCreatorAaron);
    actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data, "");
    actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(governanceScript), 0, data
    );
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
  }

  function _createStrategies(uint256 salt1, uint256 salt2, uint256 salt3, bool isFixedLengthApprovalPeriod)
    internal
    returns (
      LlamaRelativeStrategyBase.Config[] memory newStrategies,
      LlamaGovernanceScript.CreateStrategies memory strategies
    )
  {
    newStrategies = new LlamaRelativeStrategyBase.Config[](3);
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);

    newStrategies[0] = _createStrategy(salt1, isFixedLengthApprovalPeriod);
    newStrategies[1] = _createStrategy(salt2, isFixedLengthApprovalPeriod);
    newStrategies[2] = _createStrategy(salt3, isFixedLengthApprovalPeriod);
    strategies.llamaStrategyLogic = relativeHolderQuorumLogic;
    strategies.strategies = DeployUtils.encodeStrategyConfigs(newStrategies);
  }

  function _expectInitializeRolesEvents(RoleDescription[] memory descriptions) internal {
    for (uint256 i = 0; i < descriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i + 9), descriptions[i]);
    }
  }

  function _expectRoleHolderEvents(RoleHolderData[] memory roleHolders) internal {
    for (uint256 i = 0; i < roleHolders.length; i++) {
      vm.expectEmit();
      emit RoleAssigned(
        roleHolders[i].policyholder, roleHolders[i].role, roleHolders[i].expiration, roleHolders[i].quantity
      );
      rolesHoldersSeen[roleHolders[i].role]++;
      rolesQuantitySeen[roleHolders[i].role] += roleHolders[i].quantity;
    }
  }

  function _expectRolePermissionEvents(RolePermissionData[] memory rolePermissions) internal {
    for (uint256 i = 0; i < rolePermissions.length; i++) {
      bytes32 permissionId = lens.computePermissionId(rolePermissions[i].permissionData);
      vm.expectEmit();
      emit RolePermissionAssigned(
        rolePermissions[i].role, permissionId, rolePermissions[i].permissionData, rolePermissions[i].hasPermission
      );
    }
  }

  function _expectCreateStrategiesEvents(LlamaRelativeStrategyBase.Config[] memory newStrategies) internal {
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);
    for (uint256 i = 0; i < newStrategies.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeHolderQuorumLogic), DeployUtils.encodeStrategy(newStrategies[i]), address(mpCore)
      );
    }

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
  }

  function _expectUpdateRoleDescriptionsEvents(LlamaGovernanceScript.UpdateRoleDescription[] memory descriptions)
    internal
  {
    for (uint256 i = 0; i < descriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i), descriptions[i].description);
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

    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);

    _expectInitializeRolesEvents(descriptions);
    vm.expectEmit();
    emit AccountCreated(accountAddresses[0], accountLogic, DeployUtils.encodeAccount(newAccounts[0]));
    mpCore.executeAction(actionInfo);
  }
}

contract InitializeRolesAndSetRoleHolders is LlamaGovernanceScriptTest {
  function testFuzz_initializeRolesAndSetRoleHolders(
    RoleDescription[] memory descriptions,
    RoleHolderData[] memory roleHolders
  ) public {
    _assumeInitializeRoles(descriptions);
    _assumeRoleHolders(roleHolders);

    bytes memory data =
      abi.encodeWithSelector(INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, descriptions, roleHolders);
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);
    _expectInitializeRolesEvents(descriptions);
    _expectRoleHolderEvents(roleHolders);
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
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);
    _expectInitializeRolesEvents(descriptions);
    _expectRolePermissionEvents(rolePermissions);
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

    RoleHolderData[] memory roleHolders = new RoleHolderData[](1); // we don't fuzz the roleholders here because the
      // test takes too long
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
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);
    _expectInitializeRolesEvents(descriptions);
    _expectRoleHolderEvents(roleHolders);
    _expectRolePermissionEvents(rolePermissions);
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
    _assumeStrategies(salt1, salt2, salt3);

    (LlamaRelativeStrategyBase.Config[] memory newStrategies, LlamaGovernanceScript.CreateStrategies memory strategies)
    = _createStrategies(salt1, salt2, salt3, isFixedLengthApprovalPeriod);

    bytes memory data =
      abi.encodeWithSelector(CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR, strategies, roleHolders);
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);

    _expectCreateStrategiesEvents(newStrategies);
    _expectRoleHolderEvents(roleHolders);

    vm.startPrank(address(mpExecutor));
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
    _assumeStrategies(salt1, salt2, salt3);

    (LlamaRelativeStrategyBase.Config[] memory newStrategies, LlamaGovernanceScript.CreateStrategies memory strategies)
    = _createStrategies(salt1, salt2, salt3, isFixedLengthApprovalPeriod);

    bytes memory data = abi.encodeWithSelector(
      CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, strategies, descriptions, roleHolders
    );
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);

    _expectCreateStrategiesEvents(newStrategies);
    _expectInitializeRolesEvents(descriptions);
    _expectRoleHolderEvents(roleHolders);

    vm.startPrank(address(mpExecutor));
    mpCore.executeAction(actionInfo);
  }
}

contract CreateNewStrategiesAndSetRolePermissions is LlamaGovernanceScriptTest {
  function test_CreateNewStrategiesAndSetRolePermissions(
    RolePermissionData[] memory rolePermissions,
    uint256 salt1,
    uint256 salt2,
    uint256 salt3,
    bool isFixedLengthApprovalPeriod
  ) public {
    _boundRolePermissions(rolePermissions);
    _assumeStrategies(salt1, salt2, salt3);

    (LlamaRelativeStrategyBase.Config[] memory newStrategies, LlamaGovernanceScript.CreateStrategies memory strategies)
    = _createStrategies(salt1, salt2, salt3, isFixedLengthApprovalPeriod);

    bytes memory data =
      abi.encodeWithSelector(CREATE_NEW_STRATEGIES_AND_SET_ROLE_PERMISSIONS_SELECTOR, strategies, rolePermissions);
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);

    _expectCreateStrategiesEvents(newStrategies);
    _expectRolePermissionEvents(rolePermissions);

    vm.startPrank(address(mpExecutor));
    mpCore.executeAction(actionInfo);
  }
}

contract CreateNewStrategiesAndInitializeRolesAndSetRoleHoldersAndSetRolePermissions is LlamaGovernanceScriptTest {
  function test_CreateNewStrategiesAndInitializeRolesAndSetRoleHoldersAndSetRolePermissions(
    RoleDescription[] memory descriptions,
    RolePermissionData[] memory rolePermissions,
    uint256 salt1,
    uint256 salt2,
    uint256 salt3,
    bool isFixedLengthApprovalPeriod
  ) public {
    _assumeInitializeRoles(descriptions);
    _boundRolePermissions(rolePermissions);
    _assumeStrategies(salt1, salt2, salt3);

    (LlamaRelativeStrategyBase.Config[] memory newStrategies, LlamaGovernanceScript.CreateStrategies memory strategies)
    = _createStrategies(salt1, salt2, salt3, isFixedLengthApprovalPeriod);

    RoleHolderData[] memory roleHolders = new RoleHolderData[](1); // we don't fuzz the roleholders here because the
      // test takes too long
    roleHolders[0] = RoleHolderData({
      policyholder: address(uint160(1)),
      role: uint8(Roles.ActionCreator),
      expiration: type(uint64).max,
      quantity: 1
    });

    bytes memory data = abi.encodeWithSelector(
      CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR,
      strategies,
      descriptions,
      roleHolders,
      rolePermissions
    );
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);

    _expectCreateStrategiesEvents(newStrategies);
    _expectInitializeRolesEvents(descriptions);
    _expectRoleHolderEvents(roleHolders);
    _expectRolePermissionEvents(rolePermissions);

    mpCore.executeAction(actionInfo);
  }
}

contract RevokePoliciesAndUpdateRoleDescriptions is LlamaGovernanceScriptTest {
  function test_RevokePoliciesAndUpdateRoleDescriptions(
    LlamaGovernanceScript.UpdateRoleDescription[] memory descriptions
  ) public {
    revokePolicies.push(disapproverDave);
    _assumeUpdateRoleDescriptions(descriptions);

    bytes memory data =
      abi.encodeWithSelector(REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR, revokePolicies, descriptions);
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);

    vm.expectEmit();
    emit RoleAssigned(address(disapproverDave), uint8(Roles.Disapprover), 0, 0);
    _expectUpdateRoleDescriptionsEvents(descriptions);

    mpCore.executeAction(actionInfo);
  }
}

contract RevokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders is LlamaGovernanceScriptTest {
  function test_RevokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders(
    LlamaGovernanceScript.UpdateRoleDescription[] memory descriptions
  ) public {
    revokePolicies.push(disapproverDave);
    _assumeUpdateRoleDescriptions(descriptions);

    RoleHolderData[] memory roleHolders = new RoleHolderData[](1); // we don't fuzz the roleholders here because the
    // test takes too long
    roleHolders[0] = RoleHolderData({
      policyholder: address(uint160(1)),
      role: uint8(Roles.ActionCreator),
      expiration: type(uint64).max,
      quantity: 1
    });

    bytes memory data = abi.encodeWithSelector(
      REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_AND_SET_ROLE_HOLDERS_SELECTOR,
      revokePolicies,
      descriptions,
      roleHolders
    );
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);

    vm.expectEmit();
    emit RoleAssigned(address(disapproverDave), uint8(Roles.Disapprover), 0, 0);
    _expectUpdateRoleDescriptionsEvents(descriptions);
    _expectRoleHolderEvents(roleHolders);

    mpCore.executeAction(actionInfo);
  }
}

contract InitializeRoles is LlamaGovernanceScriptTest {
  function testFuzz_initializeRoles(RoleDescription[] memory descriptions) public {
    _assumeInitializeRoles(descriptions);
    bytes memory data = abi.encodeWithSelector(INITIALIZE_ROLES_SELECTOR, descriptions);
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);
    _expectInitializeRolesEvents(descriptions);
    mpCore.executeAction(actionInfo);
  }
}

contract SetRoleHolders is LlamaGovernanceScriptTest {
  function testFuzz_setRoleHolders(RoleHolderData[] memory roleHolders) public {
    _assumeRoleHolders(roleHolders);
    bytes memory data = abi.encodeWithSelector(SET_ROLE_HOLDERS_SELECTOR, roleHolders);
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);
    _expectRoleHolderEvents(roleHolders);
    mpCore.executeAction(actionInfo);
  }
}

contract SetRolePermissions is LlamaGovernanceScriptTest {
  function testFuzz_setRolePermissions(RolePermissionData[] memory rolePermissions) public {
    _boundRolePermissions(rolePermissions);
    bytes memory data = abi.encodeWithSelector(SET_ROLE_PERMISSIONS_SELECTOR, rolePermissions);
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);
    _expectRolePermissionEvents(rolePermissions);
    mpCore.executeAction(actionInfo);
  }
}

contract RevokePolicies is LlamaGovernanceScriptTest {
  function test_revokePolicies() public {
    revokePolicies.push(disapproverDave);
    bytes memory data = abi.encodeWithSelector(REVOKE_POLICIES_SELECTOR, revokePolicies);
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);
    vm.expectEmit();
    emit RoleAssigned(address(disapproverDave), uint8(Roles.Disapprover), 0, 0);
    mpCore.executeAction(actionInfo);
  }
}

contract UpdateRoleDescriptions is LlamaGovernanceScriptTest {
  function testFuzz_updateRoleDescriptions(LlamaGovernanceScript.UpdateRoleDescription[] memory roleDescriptions)
    public
  {
    _assumeUpdateRoleDescriptions(roleDescriptions);
    bytes memory data = abi.encodeWithSelector(UPDATE_ROLE_DESCRIPTIONS_SELECTOR, roleDescriptions);
    (ActionInfo memory actionInfo, uint256 actionId) = _createAction(data);

    _expectUpdateRoleDescriptionsEvents(roleDescriptions);
    mpCore.executeAction(actionInfo);
  }
}

contract SetStrategyLogicAuthorizations is LlamaGovernanceScriptTest {
  function test_setStrategyLogicAuthorizations() public {
    ILlamaStrategy[] memory strategies = new ILlamaStrategy[](3);
    strategies[0] = relativeHolderQuorumLogic;
    strategies[1] = absolutePeerReviewLogic;
    strategies[2] = absoluteQuorumLogic;

    bool[] memory authorizations = new bool[](3);
    authorizations[0] = false;
    authorizations[1] = true;
    authorizations[2] = true;

    bytes memory data = abi.encodeWithSelector(LlamaGovernanceScript.setStrategyLogicAuthorizations.selector, strategies, authorizations);
    (ActionInfo memory actionInfo,) = _createAction(data);

    vm.expectEmit();
    emit StrategyLogicAuthorizationSet(relativeHolderQuorumLogic, false);
    vm.expectEmit();
    emit StrategyLogicAuthorizationSet(absolutePeerReviewLogic, true);
    vm.expectEmit();
    emit StrategyLogicAuthorizationSet(absoluteQuorumLogic, true);

    mpCore.executeAction(actionInfo);
  }
}

contract SetStrategyAuthorizations is LlamaGovernanceScriptTest {
    function test_setStrategyAuthorizations() public {
      ILlamaStrategy[] memory strategies = new ILlamaStrategy[](3);
      strategies[0] = mpStrategy1;

      bool[] memory authorizations = new bool[](3);
      authorizations[0] = false;

      bytes memory data = abi.encodeWithSelector(LlamaGovernanceScript.setStrategyAuthorizations.selector, strategies, authorizations);
      (ActionInfo memory actionInfo,) = _createAction(data);

      vm.expectEmit();
      emit StrategyAuthorizationSet(mpStrategy1, false);

      mpCore.executeAction(actionInfo);
    }
}

/*

  function setAccountLogicAuthorization(ILlamaAccount[] calldata accountLogic, bool[] calldata authorized)
    public
    onlyDelegateCall
  {
    (LlamaCore core,) = _context();
    if (accountLogic.length != authorized.length) revert MismatchedArrayLengths();
    for (uint256 i = 0; i < accountLogic.length; i = LlamaUtils.uncheckedIncrement(i)) {
      core.setAccountLogicAuthorization(accountLogic[i], authorized[i]);
    }
  }


  function setStrategyLogicAuthorizationAndCreateStrategies(
    ILlamaStrategy strategyLogic,
    bool authorized,
    bytes[] calldata strategies
  ) public onlyDelegateCall {
    (LlamaCore core,) = _context();
    core.setStrategyLogicAuthorization(strategyLogic, authorized);
    core.createStrategies(strategyLogic, strategies);
  }
  */
