// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {Solarray} from "@solarray/Solarray.sol";

import {MockActionGuard} from "test/mock/MockActionGuard.sol";
import {MockMaliciousExtension} from "test/mock/MockMaliciousExtension.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";
import {SolarrayLlama} from "test/utils/SolarrayLlama.sol";
import {LlamaFactoryWithoutInitialization} from "test/utils/LlamaFactoryWithoutInitialization.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {IActionGuard} from "src/interfaces/IActionGuard.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {
  Action,
  ActionInfo,
  RelativeStrategyConfig,
  PermissionData,
  RoleHolderData,
  RolePermissionData
} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaCoreAndPolicyScript} from "src/LlamaScripts/LlamaCoreAndPolicyScript.sol";
import {RelativeStrategy} from "src/strategies/RelativeStrategy.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaCoreAndPolicyScriptTest is LlamaTestSetup {
  event RoleAssigned(
    address indexed policyholder, uint8 indexed role, uint256 expiration, LlamaPolicy.RoleSupply roleSupply
  );
  event RoleInitialized(uint8 indexed role, RoleDescription description);

  LlamaCoreAndPolicyScript llamaCoreAndPolicyScript;

  bytes4 public constant AGGREGATE_SELECTOR = LlamaCoreAndPolicyScript.aggregate.selector;
  bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaCoreAndPolicyScript.initializeRolesAndSetRoleHolders.selector;
  bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaCoreAndPolicyScript.initializeRolesAndSetRolePermissions.selector;
  bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaCoreAndPolicyScript.initializeRolesAndSetRoleHoldersAndSetRolePermissions.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaCoreAndPolicyScript.createNewStrategiesAndSetRoleHolders.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaCoreAndPolicyScript.createNewStrategiesAndInitializeRolesAndSetRoleHolders.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaCoreAndPolicyScript.createNewStrategiesAndSetRolePermissions.selector;
  bytes4 public constant CREATE_NEW_STRATEGIES_AND_NEW_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR =
    LlamaCoreAndPolicyScript.createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissions.selector;
  bytes4 public constant REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR =
    LlamaCoreAndPolicyScript.revokePoliciesAndUpdateRoleDescriptions.selector;
  bytes4 public constant REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_AND_SET_ROLE_HOLDERS_SELECTOR =
    LlamaCoreAndPolicyScript.revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders.selector;
  bytes4 public constant INITIALIZE_ROLES_SELECTOR = LlamaCoreAndPolicyScript.initializeRoles.selector;
  bytes4 public constant SET_ROLE_HOLDERS_SELECTOR = LlamaCoreAndPolicyScript.setRoleHolders.selector;
  bytes4 public constant SET_ROLE_PERMISSIONS_SELECTOR = LlamaCoreAndPolicyScript.setRolePermissions.selector;
  bytes4 public constant REVOKE_EXPIRED_ROLES_SELECTOR = LlamaCoreAndPolicyScript.revokeExpiredRoles.selector;
  bytes4 public constant REVOKE_POLICIES_SELECTOR = LlamaCoreAndPolicyScript.revokePolicies.selector;
  bytes4 public constant UPDATE_ROLE_DESCRIPTIONS_SELECTOR = LlamaCoreAndPolicyScript.updateRoleDescriptions.selector;

  bytes32 public executeActionPermission;
  bytes32 public aggregatePermission;
  bytes32 public initializeRolesAndSetRoleHoldersPermissionId;
  bytes32 public initializeRolesAndSetRolePermissionsPermissionId;
  bytes32 public initializeRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId;
  bytes32 public createNewStrategiesAndSetRoleHoldersPermissionId;
  bytes32 public createNewStrategiesAndInitializeRolesAndSetRoleHoldersPermissionId;
  bytes32 public createNewStrategiesAndSetRolePermissionsPermissionId;
  bytes32 public createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId;
  bytes32 public revokePoliciesAndUpdateRoleDescriptionsPermissionId;
  bytes32 public revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHoldersPermissionId;
  bytes32 public initializeRolesPermissionId;
  bytes32 public setRoleHoldersPermissionId;
  bytes32 public setRolePermissionsPermissionId;
  bytes32 public revokeExpiredRolesPermissionId;
  bytes32 public revokePoliciesPermissionId;
  bytes32 public updateRoleDescriptionPerimssionId;

  function setUp() public virtual override {
    LlamaTestSetup.setUp();

    llamaCoreAndPolicyScript = new LlamaCoreAndPolicyScript();

    vm.startPrank(address(mpCore));

    mpCore.authorizeScript(address(llamaCoreAndPolicyScript), true);

    executeActionPermission =
      keccak256(abi.encode(address(llamaCoreAndPolicyScript), EXECUTE_ACTION_SELECTOR, mpStrategy2));
    aggregatePermission = keccak256(abi.encode(address(llamaCoreAndPolicyScript), AGGREGATE_SELECTOR, mpStrategy2));
    initializeRolesAndSetRoleHoldersPermissionId = keccak256(
      abi.encode(address(llamaCoreAndPolicyScript), INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy2)
    );
    initializeRolesAndSetRolePermissionsPermissionId = keccak256(
      abi.encode(address(llamaCoreAndPolicyScript), INITIALIZE_ROLES_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2)
    );
    initializeRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId = keccak256(
      abi.encode(
        address(llamaCoreAndPolicyScript),
        INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR,
        mpStrategy2
      )
    );
    createNewStrategiesAndSetRoleHoldersPermissionId = keccak256(
      abi.encode(address(llamaCoreAndPolicyScript), CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy2)
    );
    createNewStrategiesAndInitializeRolesAndSetRoleHoldersPermissionId = keccak256(
      abi.encode(
        address(llamaCoreAndPolicyScript),
        CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR,
        mpStrategy2
      )
    );
    createNewStrategiesAndSetRolePermissionsPermissionId = keccak256(
      abi.encode(
        address(llamaCoreAndPolicyScript), CREATE_NEW_STRATEGIES_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2
      )
    );
    createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId = keccak256(
      abi.encode(
        address(llamaCoreAndPolicyScript),
        CREATE_NEW_STRATEGIES_AND_NEW_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR,
        mpStrategy2
      )
    );
    revokePoliciesAndUpdateRoleDescriptionsPermissionId = keccak256(
      abi.encode(address(llamaCoreAndPolicyScript), REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR, mpStrategy2)
    );
    revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHoldersPermissionId = keccak256(
      abi.encode(
        address(llamaCoreAndPolicyScript),
        REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_AND_SET_ROLE_HOLDERS_SELECTOR,
        mpStrategy2
      )
    );
    initializeRolesPermissionId =
      keccak256(abi.encode(address(llamaCoreAndPolicyScript), INITIALIZE_ROLES_SELECTOR, mpStrategy2));
    setRoleHoldersPermissionId =
      keccak256(abi.encode(address(llamaCoreAndPolicyScript), SET_ROLE_HOLDERS_SELECTOR, mpStrategy2));
    setRolePermissionsPermissionId =
      keccak256(abi.encode(address(llamaCoreAndPolicyScript), SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy2));
    revokeExpiredRolesPermissionId =
      keccak256(abi.encode(address(llamaCoreAndPolicyScript), REVOKE_EXPIRED_ROLES_SELECTOR, mpStrategy2));
    revokePoliciesPermissionId =
      keccak256(abi.encode(address(llamaCoreAndPolicyScript), REVOKE_POLICIES_SELECTOR, mpStrategy2));
    updateRoleDescriptionPerimssionId =
      keccak256(abi.encode(address(llamaCoreAndPolicyScript), UPDATE_ROLE_DESCRIPTIONS_SELECTOR, mpStrategy2));

    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), executeActionPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), aggregatePermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesAndSetRoleHoldersPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesAndSetRolePermissionsPermissionId, true);
    mpPolicy.setRolePermission(
      uint8(Roles.ActionCreator), initializeRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId, true
    );
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), createNewStrategiesAndSetRoleHoldersPermissionId, true);
    mpPolicy.setRolePermission(
      uint8(Roles.ActionCreator), createNewStrategiesAndInitializeRolesAndSetRoleHoldersPermissionId, true
    );
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), createNewStrategiesAndSetRolePermissionsPermissionId, true);
    mpPolicy.setRolePermission(
      uint8(Roles.ActionCreator), createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId, true
    );
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokePoliciesAndUpdateRoleDescriptionsPermissionId, true);
    mpPolicy.setRolePermission(
      uint8(Roles.ActionCreator), revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHoldersPermissionId, true
    );
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setRoleHoldersPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setRolePermissionsPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokeExpiredRolesPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokePoliciesPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), updateRoleDescriptionPerimssionId, true);

    vm.stopPrank();
  }

  function _approveAction(ActionInfo memory actionInfo) internal {
    vm.warp(block.timestamp + 1);

    vm.prank(approverAdam);
    mpCore.castApproval(actionInfo, uint8(Roles.Approver));
    vm.prank(approverAlicia);
    mpCore.castApproval(actionInfo, uint8(Roles.Approver));
    vm.prank(approverAndy);
    mpCore.castApproval(actionInfo, uint8(Roles.Approver));
    mpCore.queueAction(actionInfo);
  }
}

contract Aggregate is LlamaCoreAndPolicyScriptTest {}

contract InitializeRolesAndSetRoleHolders is LlamaCoreAndPolicyScriptTest {}

contract InitializeRolesAndSetRolePermissions is LlamaCoreAndPolicyScriptTest {}

contract InitializeRolesAndSetRoleHoldersAndSetRolePermissions is LlamaCoreAndPolicyScriptTest {}

contract CreateNewStrategiesAndSetRoleHolders is LlamaCoreAndPolicyScriptTest {}

contract CreateNewStrategiesAndInitializeRolesAndSetRoleHolders is LlamaCoreAndPolicyScriptTest {}

contract CreateNewStrategiesAndSetRolePermissions is LlamaCoreAndPolicyScriptTest {}

contract CreateNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolesPermissions is LlamaCoreAndPolicyScriptTest {}

contract RevokePoliciesAndUpdateRoleDescriptions is LlamaCoreAndPolicyScriptTest {}

contract RevokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders is LlamaCoreAndPolicyScriptTest {}

contract InitializeRoles is LlamaCoreAndPolicyScriptTest {
  function testFuzz_initializeRoles(RoleDescription[] memory descriptions) public {
    vm.assume(descriptions.length < 247); // max unit8 (256) - total number of exisitng roles (9)
    bytes memory data = abi.encodeWithSelector(INITIALIZE_ROLES_SELECTOR, descriptions);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(llamaCoreAndPolicyScript), 0, data);
    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, mpStrategy2, address(llamaCoreAndPolicyScript), 0, data);
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    for (uint256 i = 0; i < descriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i + 9), descriptions[i]);
    }
    mpCore.executeAction(actionInfo);
  }
}

contract SetRoleHolders is LlamaCoreAndPolicyScriptTest {
  function testFuzz_setRoleHolders(LlamaCoreAndPolicyScript.SetRoleHolder[] memory roleHolders) public {
    for (uint256 i = 0; i < roleHolders.length; i++) {
      roleHolders[i].role = uint8(bound(roleHolders[i].role, 1, 9)); // number of exisitng roles (9) and cannot be 0
        // (all holders role)
      vm.assume(roleHolders[i].expiration > block.timestamp);
    }
    bytes memory data = abi.encodeWithSelector(SET_ROLE_HOLDERS_SELECTOR, roleHolders);
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(llamaCoreAndPolicyScript), 0, data);
    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, mpStrategy2, address(llamaCoreAndPolicyScript), 0, data);
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    for (uint256 i = 0; i < roleHolders.length; i++) {
      vm.expectEmit();
      emit RoleAssigned(
        roleHolders[i].policyholder,
        roleHolders[i].role,
        roleHolders[i].expiration,
        LlamaPolicy.RoleSupply(
          mpPolicy.getRoleSupplyAsNumberOfHolders(roleHolders[i].role) + 1,
          mpPolicy.getRoleSupplyAsQuantitySum(roleHolders[i].role) + roleHolders[i].quantity
        )
      );
    }
    mpCore.executeAction(actionInfo);
  }
}

contract SetRolePermissions is LlamaCoreAndPolicyScriptTest {}

contract RevokeExpiredRoles is LlamaCoreAndPolicyScriptTest {}

contract RevokePolicies is LlamaCoreAndPolicyScriptTest {
  function testFuzz_revokePolicies(LlamaCoreAndPolicyScript.RevokePolicy[] memory policies) public {}
}

contract UpdateRoleDescriptions is LlamaCoreAndPolicyScriptTest {
  function testFuzz_updateRoleDescriptions(LlamaCoreAndPolicyScript.UpdateRoleDescription[] memory roleDescriptions)
    public
  {
    vm.assume(roleDescriptions.length <= 9); //number of roles in the Roles enum
    for (uint256 i = 0; i < roleDescriptions.length; i++) {
      roleDescriptions[i].role = uint8(i);
    }
    vm.prank(actionCreatorAaron);
    bytes memory data = abi.encodeWithSelector(UPDATE_ROLE_DESCRIPTIONS_SELECTOR, roleDescriptions);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(llamaCoreAndPolicyScript), 0, data);
    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, mpStrategy2, address(llamaCoreAndPolicyScript), 0, data);
    _approveAction(actionInfo);
    for (uint256 i = 0; i < roleDescriptions.length; i++) {
      vm.expectEmit();
      emit RoleInitialized(uint8(i), roleDescriptions[i].description);
    }
    mpCore.executeAction(actionInfo);
  }
}
