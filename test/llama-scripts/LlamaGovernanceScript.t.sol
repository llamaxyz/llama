// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {ActionInfo, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaGovernanceScript} from "src/llama-scripts/LlamaGovernanceScript.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaRelativeStrategyBase} from "src/strategies/relative/LlamaRelativeStrategyBase.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract LlamaGovernanceScriptTest is LlamaTestSetup {
  event AccountCreated(ILlamaAccount account, ILlamaAccount indexed accountLogic, bytes initializationData);
  event AccountLogicAuthorizationSet(ILlamaAccount indexed accountLogic, bool authorized);
  event RoleAssigned(address indexed policyholder, uint8 indexed role, uint64 expiration, uint96 quantity);
  event RoleInitialized(uint8 indexed role, RoleDescription description);
  event RolePermissionAssigned(
    uint8 indexed role, bytes32 indexed permissionId, PermissionData permissionData, bool hasPermission
  );
  event ScriptAuthorizationSet(address indexed script, bool authorized);
  event StrategyAuthorizationSet(ILlamaStrategy indexed strategy, bool authorized);
  event StrategyLogicAuthorizationSet(ILlamaStrategy indexed strategyLogic, bool authorized);
  event StrategyCreated(ILlamaStrategy strategy, ILlamaStrategy indexed strategyLogic, bytes initializationData);

  mapping(uint8 => uint96) public rolesHoldersSeen;
  mapping(uint8 => uint96) public rolesQuantitySeen;

  uint8[] public roles;
  address[] public revokePolicies;

  LlamaGovernanceScript govScript;

  bytes4 public constant AGGREGATE_SELECTOR = LlamaGovernanceScript.aggregate.selector;
  bytes4 public constant INIT_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaGovernanceScript.initRolesAndSetRoleHolders.selector;
  bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaGovernanceScript.initRolesAndSetRolePermissions.selector;
  bytes4 public constant INIT_ROLES_AND_HOLDERS_AND_PERMISSIONS_SELECTOR =
    LlamaGovernanceScript.initRolesAndHoldersAndPermissions.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaGovernanceScript.createNewStrategiesAndSetRoleHolders.selector;
  bytes4 public constant CREATE_STRATEGIES_AND_INIT_ROLES_AND_HOLDERS_SELECTOR =
    LlamaGovernanceScript.createStrategiesAndInitRolesAndHolders.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaGovernanceScript.createNewStrategiesAndSetRolePermissions.selector;
  bytes4 public constant CREATE_STRATEGIES_WITH_ROLES_AND_PERMISSIONS_SELECTOR =
    LlamaGovernanceScript.createStrategiesWithRolesAndPermissions.selector;
  bytes4 public constant REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR =
    LlamaGovernanceScript.revokePoliciesAndUpdateRoleDescriptions.selector;
  bytes4 public constant REVOKE_POLICIES_AND_SET_ROLE_DESCS_AND_HOLDERS_SELECTOR =
    LlamaGovernanceScript.revokePoliciesAndSetRoleDescsAndHolders.selector;
  bytes4 public constant INIT_ROLES_SELECTOR = LlamaGovernanceScript.initRoles.selector;
  bytes4 public constant SET_ROLE_HOLDERS_SELECTOR = LlamaGovernanceScript.setRoleHolders.selector;
  bytes4 public constant SET_ROLE_PERMISSIONS_SELECTOR = LlamaGovernanceScript.setRolePermissions.selector;
  bytes4 public constant REVOKE_POLICIES_SELECTOR = LlamaGovernanceScript.revokePolicies.selector;
  bytes4 public constant UPDATE_ROLE_DESCRIPTIONS_SELECTOR = LlamaGovernanceScript.updateRoleDescriptions.selector;
  bytes4 public constant SET_STRATEGY_LOGIC_AUTHORIZATIONS_SELECTOR =
    LlamaGovernanceScript.setStrategyLogicAuthorizations.selector;
  bytes4 public constant SET_STRATEGY_AUTHORIZATIONS_SELECTOR = LlamaGovernanceScript.setStrategyAuthorizations.selector;
  bytes4 public constant SET_ACCOUNT_LOGIC_AUTHORIZATIONS_SELECTOR =
    LlamaGovernanceScript.setAccountLogicAuthorizations.selector;
  bytes4 public constant SET_STRATEGY_LOGIC_AUTH_AND_NEW_STRATEGIES_SELECTOR =
    LlamaGovernanceScript.setStrategyLogicAuthAndNewStrategies.selector;
  bytes4 SET_SCRIPT_AUTH_AND_SET_PERMISSIONS_SELECTOR = LlamaGovernanceScript.setScriptAuthAndSetPermissions.selector;
  bytes4 CREATE_ACCOUNTS_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaGovernanceScript.createAccountsAndSetRolePermissions.selector;

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
  PermissionData public revokePoliciesAndSetRoleDescsAndHolders;
  PermissionData public initializeRolesPermission;
  PermissionData public setRoleHoldersPermission;
  PermissionData public setRolePermissionsPermission;
  PermissionData public revokePoliciesPermission;
  PermissionData public updateRoleDescriptionPerimssion;
  PermissionData public setStrategyLogicAuthorizationsPermission;
  PermissionData public setStrategyAuthorizationsPermission;
  PermissionData public setAccountLogicAuthorizationsPermission;
  PermissionData public setStrategyLogicAuthAndNewStrategiesPermission;
  PermissionData public setScriptAuthAndSetPermissionsPermission;
  PermissionData public createAccountsAndSetRolePermissionsPermission;

  function setUp() public virtual override {
    LlamaTestSetup.setUp();

    govScript = new LlamaGovernanceScript();

    vm.startPrank(address(mpExecutor));

    mpCore.setScriptAuthorization(address(govScript), true);

    executeActionPermission = PermissionData(address(govScript), EXECUTE_ACTION_SELECTOR, mpStrategy2);
    aggregatePermission = PermissionData(address(govScript), AGGREGATE_SELECTOR, mpStrategy2);
    initializeRolesAndSetRoleHoldersPermission =
      PermissionData(address(govScript), INIT_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy2);
    initializeRolesAndSetRolePermissionsPermission =
      PermissionData(address(govScript), INITIALIZE_ROLES_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2);
    initializeRolesAndSetRoleHoldersAndSetRolePermissionsPermission =
      PermissionData(address(govScript), INIT_ROLES_AND_HOLDERS_AND_PERMISSIONS_SELECTOR, mpStrategy2);
    createNewStrategiesAndSetRoleHoldersPermission =
      PermissionData(address(govScript), CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy2);
    createNewStrategiesAndInitializeRolesAndSetRoleHoldersPermission =
      PermissionData(address(govScript), CREATE_STRATEGIES_AND_INIT_ROLES_AND_HOLDERS_SELECTOR, mpStrategy2);
    createNewStrategiesAndSetRolePermissionsPermission =
      PermissionData(address(govScript), CREATE_NEW_STRATEGIES_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2);
    createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissionsPermission =
      PermissionData(address(govScript), CREATE_STRATEGIES_WITH_ROLES_AND_PERMISSIONS_SELECTOR, mpStrategy2);
    revokePoliciesAndUpdateRoleDescriptionsPermission =
      PermissionData(address(govScript), REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR, mpStrategy2);
    revokePoliciesAndSetRoleDescsAndHolders =
      PermissionData(address(govScript), REVOKE_POLICIES_AND_SET_ROLE_DESCS_AND_HOLDERS_SELECTOR, mpStrategy2);
    initializeRolesPermission = PermissionData(address(govScript), INIT_ROLES_SELECTOR, mpStrategy2);
    setRoleHoldersPermission = PermissionData(address(govScript), SET_ROLE_HOLDERS_SELECTOR, mpStrategy2);
    setRolePermissionsPermission = PermissionData(address(govScript), SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2);
    revokePoliciesPermission = PermissionData(address(govScript), REVOKE_POLICIES_SELECTOR, mpStrategy2);
    updateRoleDescriptionPerimssion = PermissionData(address(govScript), UPDATE_ROLE_DESCRIPTIONS_SELECTOR, mpStrategy2);
    setStrategyLogicAuthorizationsPermission =
      PermissionData(address(govScript), SET_STRATEGY_LOGIC_AUTHORIZATIONS_SELECTOR, mpStrategy2);
    setStrategyAuthorizationsPermission =
      PermissionData(address(govScript), SET_STRATEGY_AUTHORIZATIONS_SELECTOR, mpStrategy2);
    setAccountLogicAuthorizationsPermission =
      PermissionData(address(govScript), SET_ACCOUNT_LOGIC_AUTHORIZATIONS_SELECTOR, mpStrategy2);
    setStrategyLogicAuthAndNewStrategiesPermission =
      PermissionData(address(govScript), SET_STRATEGY_LOGIC_AUTH_AND_NEW_STRATEGIES_SELECTOR, mpStrategy2);
    setScriptAuthAndSetPermissionsPermission =
      PermissionData(address(govScript), SET_SCRIPT_AUTH_AND_SET_PERMISSIONS_SELECTOR, mpStrategy2);
    createAccountsAndSetRolePermissionsPermission =
      PermissionData(address(govScript), CREATE_ACCOUNTS_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2);

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
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokePoliciesAndSetRoleDescsAndHolders, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setRoleHoldersPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setRolePermissionsPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokePoliciesPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), updateRoleDescriptionPerimssion, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setStrategyLogicAuthorizationsPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setStrategyAuthorizationsPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setAccountLogicAuthorizationsPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setStrategyLogicAuthAndNewStrategiesPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setScriptAuthAndSetPermissionsPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), createAccountsAndSetRolePermissionsPermission, true);

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

  function _assumeInitializeRoles(RoleDescription[] memory descriptions) public pure {
    vm.assume(descriptions.length < 247); // max unit8 (255) - total number of exisitng roles (8)
  }

  function _assumeRoleHolders(RoleHolderData[] memory roleHolders) public view {
    vm.assume(roleHolders.length < 10);
    for (uint256 i = 0; i < roleHolders.length; i++) {
      // Cannot be 0 (all holders role) and cannot be greater than numRoles
      roleHolders[i].role = uint8(bound(roleHolders[i].role, 1, mpPolicy.numRoles()));
      vm.assume(roleHolders[i].expiration > block.timestamp + 1 days);
      vm.assume(roleHolders[i].policyholder != address(0));
      roleHolders[i].quantity = uint96(bound(roleHolders[i].quantity, 1, 100));
    }
  }

  function _assumeStrategies(uint256 salt1, uint256 salt2, uint256 salt3) public pure {
    vm.assume(salt1 != salt2 && salt1 != salt3 && salt2 != salt3);
  }

  function _assumeUpdateRoleDescriptions(LlamaGovernanceScript.UpdateRoleDescription[] memory descriptions) public pure {
    vm.assume(descriptions.length <= 9); //number of roles in the Roles enum
    for (uint256 i = 0; i < descriptions.length; i++) {
      descriptions[i].role = uint8(i);
    }
  }

  function _boundRolePermissions(RolePermissionData[] memory rolePermissions) public view {
    for (uint256 i = 0; i < rolePermissions.length; i++) {
      // Cannot be 0 (all holders role) and cannot be greater than numRoles
      rolePermissions[i].role = uint8(bound(rolePermissions[i].role, 1, mpPolicy.numRoles()));
    }
  }

  function _createAction(bytes memory data) internal returns (ActionInfo memory actionInfo) {
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(govScript), 0, data, "");
    actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(govScript), 0, data);
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
  }

  function _createStrategies(uint256 salt1, uint256 salt2, uint256 salt3, bool isFixedLengthApprovalPeriod)
    internal
    view
    returns (
      LlamaRelativeStrategyBase.Config[] memory newStrategies,
      LlamaGovernanceScript.CreateStrategies memory strategies
    )
  {
    newStrategies = new LlamaRelativeStrategyBase.Config[](3);
    // ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);

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

    (ActionInfo memory actionInfo) = _createAction(data);

    _expectInitializeRolesEvents(descriptions);
    vm.expectEmit();
    emit AccountCreated(accountAddresses[0], accountLogic, DeployUtils.encodeAccount(newAccounts[0]));
    mpCore.executeAction(actionInfo);
  }

  function test_RevertsIf_CallReverted(RoleDescription description) public {
    targets.push(address(0));
    calls.push(abi.encodeWithSelector(LlamaPolicy.initializeRole.selector, description));

    bytes memory data = abi.encodeWithSelector(AGGREGATE_SELECTOR, targets, calls);

    (ActionInfo memory actionInfo) = _createAction(data);

    vm.expectRevert();
    // CallReverted error cannot be reached because we get a "FailedActionExecution" error first.
    mpCore.executeAction(actionInfo);
  }

  function test_RevertsIf_UnauthorizedTarget(address target) public {
    vm.assume(target != address(mpPolicy) && target != address(mpCore));
    targets.push(address(target));
    calls.push(abi.encodeWithSelector(LlamaPolicy.initializeRole.selector, "test"));

    bytes memory data = abi.encodeWithSelector(AGGREGATE_SELECTOR, targets, calls);
    (ActionInfo memory actionInfo) = _createAction(data);

    vm.expectRevert();
    // UnauthorizedTarget error cannot be reached because we get a "FailedActionExecution" error first.
    mpCore.executeAction(actionInfo);
  }

  function test_RevertsIf_MismatchedArrayLength(address[] calldata _targets, uint8 length) public {
    vm.assume(targets.length != length);
    bytes[] memory _calls = new bytes[](length);
    for (uint256 i = 0; i < length; i++) {
      _calls[i] = abi.encodeWithSelector(LlamaPolicy.initializeRole.selector, "test");
    }
    bytes memory data = abi.encodeWithSelector(AGGREGATE_SELECTOR, _targets, _calls);
    (ActionInfo memory actionInfo) = _createAction(data);

    vm.expectRevert();
    // MismatchedArrayLength error cannot be reached because we get a "FailedActionExecution" error first.
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

    bytes memory data = abi.encodeWithSelector(INIT_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, descriptions, roleHolders);
    (ActionInfo memory actionInfo) = _createAction(data);
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
    (ActionInfo memory actionInfo) = _createAction(data);
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
      INIT_ROLES_AND_HOLDERS_AND_PERMISSIONS_SELECTOR, descriptions, roleHolders, rolePermissions
    );
    (ActionInfo memory actionInfo) = _createAction(data);
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
    (ActionInfo memory actionInfo) = _createAction(data);

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
      CREATE_STRATEGIES_AND_INIT_ROLES_AND_HOLDERS_SELECTOR, strategies, descriptions, roleHolders
    );
    (ActionInfo memory actionInfo) = _createAction(data);

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
    (ActionInfo memory actionInfo) = _createAction(data);

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
      CREATE_STRATEGIES_WITH_ROLES_AND_PERMISSIONS_SELECTOR, strategies, descriptions, roleHolders, rolePermissions
    );
    (ActionInfo memory actionInfo) = _createAction(data);

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
    (ActionInfo memory actionInfo) = _createAction(data);

    vm.expectEmit();
    emit RoleAssigned(address(disapproverDave), uint8(Roles.Disapprover), 0, 0);
    _expectUpdateRoleDescriptionsEvents(descriptions);

    mpCore.executeAction(actionInfo);
  }
}

contract RevokePoliciesAndSetRoleDescsAndHolders is LlamaGovernanceScriptTest {
  function test_RevokePoliciesAndSetRoleDescsAndHolders(
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
      REVOKE_POLICIES_AND_SET_ROLE_DESCS_AND_HOLDERS_SELECTOR, revokePolicies, descriptions, roleHolders
    );
    (ActionInfo memory actionInfo) = _createAction(data);

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
    bytes memory data = abi.encodeWithSelector(INIT_ROLES_SELECTOR, descriptions);
    (ActionInfo memory actionInfo) = _createAction(data);
    _expectInitializeRolesEvents(descriptions);
    mpCore.executeAction(actionInfo);
  }
}

contract SetRoleHolders is LlamaGovernanceScriptTest {
  function testFuzz_setRoleHolders(RoleHolderData[] memory roleHolders) public {
    _assumeRoleHolders(roleHolders);
    bytes memory data = abi.encodeWithSelector(SET_ROLE_HOLDERS_SELECTOR, roleHolders);
    (ActionInfo memory actionInfo) = _createAction(data);
    _expectRoleHolderEvents(roleHolders);
    mpCore.executeAction(actionInfo);
  }
}

contract SetRolePermissions is LlamaGovernanceScriptTest {
  function testFuzz_setRolePermissions(RolePermissionData[] memory rolePermissions) public {
    _boundRolePermissions(rolePermissions);
    bytes memory data = abi.encodeWithSelector(SET_ROLE_PERMISSIONS_SELECTOR, rolePermissions);
    (ActionInfo memory actionInfo) = _createAction(data);
    _expectRolePermissionEvents(rolePermissions);
    mpCore.executeAction(actionInfo);
  }
}

contract RevokePolicies is LlamaGovernanceScriptTest {
  function test_revokePolicies() public {
    revokePolicies.push(disapproverDave);
    bytes memory data = abi.encodeWithSelector(REVOKE_POLICIES_SELECTOR, revokePolicies);
    (ActionInfo memory actionInfo) = _createAction(data);
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
    (ActionInfo memory actionInfo) = _createAction(data);

    _expectUpdateRoleDescriptionsEvents(roleDescriptions);
    mpCore.executeAction(actionInfo);
  }
}

contract SetStrategyLogicAuthorizations is LlamaGovernanceScriptTest {
  function test_setStrategyLogicAuthorizations(bool authorized) public {
    ILlamaStrategy[] memory strategies = new ILlamaStrategy[](3);
    strategies[0] = relativeHolderQuorumLogic;
    strategies[1] = absolutePeerReviewLogic;
    strategies[2] = absoluteQuorumLogic;

    bytes memory data =
      abi.encodeWithSelector(LlamaGovernanceScript.setStrategyLogicAuthorizations.selector, strategies, authorized);
    (ActionInfo memory actionInfo) = _createAction(data);

    vm.expectEmit();
    emit StrategyLogicAuthorizationSet(relativeHolderQuorumLogic, authorized);
    vm.expectEmit();
    emit StrategyLogicAuthorizationSet(absolutePeerReviewLogic, authorized);
    vm.expectEmit();
    emit StrategyLogicAuthorizationSet(absoluteQuorumLogic, authorized);

    mpCore.executeAction(actionInfo);
  }
}

contract SetStrategyAuthorizations is LlamaGovernanceScriptTest {
  function test_setStrategyAuthorizations(bool authorized) public {
    ILlamaStrategy[] memory strategies = new ILlamaStrategy[](1);
    strategies[0] = mpStrategy1;

    bytes memory data =
      abi.encodeWithSelector(LlamaGovernanceScript.setStrategyAuthorizations.selector, strategies, authorized);
    (ActionInfo memory actionInfo) = _createAction(data);

    vm.expectEmit();
    emit StrategyAuthorizationSet(mpStrategy1, authorized);

    mpCore.executeAction(actionInfo);
  }
}

contract SetAccountLogicAuthorizations is LlamaGovernanceScriptTest {
  function test_SetAccountLogicAuthorizations(ILlamaAccount[] calldata accountLogics, bool authorized) public {
    vm.assume(accountLogics.length < 5);

    bytes memory data =
      abi.encodeWithSelector(LlamaGovernanceScript.setAccountLogicAuthorizations.selector, accountLogics, authorized);
    (ActionInfo memory actionInfo) = _createAction(data);

    for (uint256 i = 0; i < accountLogics.length; i++) {
      vm.expectEmit();
      emit AccountLogicAuthorizationSet(accountLogics[i], authorized);
    }

    mpCore.executeAction(actionInfo);
  }
}

contract SetStrategyLogicAuthorizationAndCreateStrategies is LlamaGovernanceScriptTest {
  function test_SetStrategyLogicAuthorizationAndCreateStrategies() public {
    LlamaRelativeStrategyBase.Config[] memory newStrategies = new LlamaRelativeStrategyBase.Config[](1);
    newStrategies[0] = LlamaRelativeStrategyBase.Config({
      approvalPeriod: 0,
      queuingPeriod: 0,
      expirationPeriod: 2 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 10_001,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });
    ILlamaStrategy instantExecutionStrategy = lens.computeLlamaStrategyAddress(
      address(relativeQuantityQuorumLogic), DeployUtils.encodeStrategy(newStrategies[0]), address(mpCore)
    );
    bytes memory data = abi.encodeWithSelector(
      LlamaGovernanceScript.setStrategyLogicAuthAndNewStrategies.selector,
      relativeQuantityQuorumLogic,
      DeployUtils.encodeStrategyConfigs(newStrategies)
    );
    (ActionInfo memory actionInfo) = _createAction(data);

    vm.expectEmit();
    emit StrategyLogicAuthorizationSet(relativeQuantityQuorumLogic, true);
    vm.expectEmit();
    emit StrategyCreated(
      instantExecutionStrategy, relativeQuantityQuorumLogic, DeployUtils.encodeStrategy(newStrategies[0])
    );
    mpCore.executeAction(actionInfo);
  }
}

contract SetScriptAuthAndSetPermissions is LlamaGovernanceScriptTest {
  function test_SetScriptAuthAndSetPermissions(address script, bool authorized, bytes4[] calldata selectors) public {
    ILlamaStrategy[] memory strategies = new ILlamaStrategy[](selectors.length);

    bytes memory data = abi.encodeWithSelector(
      LlamaGovernanceScript.setScriptAuthAndSetPermissions.selector,
      script,
      authorized,
      uint8(Roles.ActionCreator),
      selectors,
      strategies
    );
    (ActionInfo memory actionInfo) = _createAction(data);

    vm.expectEmit();
    emit ScriptAuthorizationSet(script, authorized);
    for (uint256 i = 0; i < selectors.length; i++) {
      PermissionData memory permissionData = PermissionData(script, selectors[i], strategies[i]);
      bytes32 permissionId = lens.computePermissionId(permissionData);
      vm.expectEmit();
      emit RolePermissionAssigned(uint8(Roles.ActionCreator), permissionId, permissionData, authorized);
    }
    mpCore.executeAction(actionInfo);
  }
}

contract CreateAccountsAndSetRolePermissions is LlamaGovernanceScriptTest {
  function test_CreateAccountsAndSetRolePermissions() public {
    LlamaGovernanceScript.CreateAccounts[] memory accounts = new LlamaGovernanceScript.CreateAccounts[](2);
    bytes[] memory config1 = new bytes[](1);
    bytes[] memory config2 = new bytes[](1);
    accounts[0].accountLogic = accountLogic;
    accounts[1].accountLogic = accountLogic;

    config1[0] = abi.encode(LlamaAccount.Config({name: "mockAccountERC20"}));
    config2[0] = abi.encode(LlamaAccount.Config({name: "mockAccountERC721"}));
    accounts[0].config = config1;
    accounts[1].config = config2;

    ILlamaAccount accountAddress1 = lens.computeLlamaAccountAddress(address(accountLogic), config1[0], address(mpCore));

    ILlamaAccount accountAddress2 = lens.computeLlamaAccountAddress(address(accountLogic), config2[0], address(mpCore));

    PermissionData memory permissionData1 =
      PermissionData(address(accountAddress1), LlamaAccount.batchTransferNativeToken.selector, mpStrategy2);
    PermissionData memory permissionData2 =
      PermissionData(address(accountAddress1), LlamaAccount.batchTransferERC20.selector, mpStrategy2);
    PermissionData memory permissionData3 =
      PermissionData(address(accountAddress1), LlamaAccount.batchApproveERC20.selector, mpStrategy2);
    PermissionData memory permissionData4 =
      PermissionData(address(accountAddress2), LlamaAccount.batchTransferERC721.selector, mpStrategy2);
    PermissionData memory permissionData5 =
      PermissionData(address(accountAddress2), LlamaAccount.batchApproveERC721.selector, mpStrategy2);
    PermissionData memory permissionData6 =
      PermissionData(address(accountAddress2), LlamaAccount.batchApproveOperatorERC721.selector, mpStrategy2);

    RolePermissionData[] memory _permissions = new RolePermissionData[](6);
    _permissions[0] = RolePermissionData(uint8(Roles.ActionCreator), permissionData1, true);
    _permissions[1] = RolePermissionData(uint8(Roles.ActionCreator), permissionData2, true);
    _permissions[2] = RolePermissionData(uint8(Roles.ActionCreator), permissionData3, true);
    _permissions[3] = RolePermissionData(uint8(Roles.ActionCreator), permissionData4, true);
    _permissions[4] = RolePermissionData(uint8(Roles.ActionCreator), permissionData5, true);
    _permissions[5] = RolePermissionData(uint8(Roles.ActionCreator), permissionData6, true);

    bytes memory data =
      abi.encodeWithSelector(LlamaGovernanceScript.createAccountsAndSetRolePermissions.selector, accounts, _permissions);

    (ActionInfo memory actionInfo) = _createAction(data);

    vm.expectEmit();
    emit AccountCreated(accountAddress1, accountLogic, config1[0]);
    vm.expectEmit();
    emit AccountCreated(accountAddress2, accountLogic, config2[0]);

    vm.expectEmit();
    emit RolePermissionAssigned(
      uint8(Roles.ActionCreator), LlamaUtils.computePermissionId(permissionData1), permissionData1, true
    );

    vm.expectEmit();
    emit RolePermissionAssigned(
      uint8(Roles.ActionCreator), LlamaUtils.computePermissionId(permissionData2), permissionData2, true
    );

    vm.expectEmit();
    emit RolePermissionAssigned(
      uint8(Roles.ActionCreator), LlamaUtils.computePermissionId(permissionData3), permissionData3, true
    );

    vm.expectEmit();
    emit RolePermissionAssigned(
      uint8(Roles.ActionCreator), LlamaUtils.computePermissionId(permissionData4), permissionData4, true
    );

    vm.expectEmit();
    emit RolePermissionAssigned(
      uint8(Roles.ActionCreator), LlamaUtils.computePermissionId(permissionData5), permissionData5, true
    );

    vm.expectEmit();
    emit RolePermissionAssigned(
      uint8(Roles.ActionCreator), LlamaUtils.computePermissionId(permissionData6), permissionData6, true
    );

    mpCore.executeAction(actionInfo);
  }
}
