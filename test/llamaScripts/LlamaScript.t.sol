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
import {LlamaScript} from "src/LlamaScripts/LlamaScript.sol";
import {RelativeStrategy} from "src/strategies/RelativeStrategy.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaScriptTest is LlamaTestSetup {

    bytes4 public constant EXECUTE_ACTION_SELECTOR = LlamaCore.executeAction.selector;
    bytes4 public constant AGGREGATE_SELECTOR = Llamacore.aggregate.selector;
    bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR = Llamacore.initializeRolesAndSetRoleHolders.selector;
    bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_PERMISSIONS_SELECTOR = Llamacore.initializeRolesAndSetRolePermissions.selector;
    bytes4 public constant INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR = Llamacore.initializeRolesAndSetRoleHoldersAndSetRolePermissions.selector;
    bytes4 public constant CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR = Llamacore.createNewStrategiesAndSetRoleHolders.selector;
    bytes4 public constant CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR = Llamacore.createNewStrategiesAndInitializeRolesAndSetRoleHolders.selector;
    bytes4 public constant CREATE_NEW_STRATEGIES_AND_SET_ROLE_PERMISSIONS_SELECTOR = Llamacore.createNewStrategiesAndSetRolePermissions.selector;
    bytes4 public constant CREATE_NEW_STRATEGIES_AND_NEW_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR = Llamacore.createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissions.selector;
    bytes4 public constant REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR = Llamacore.revokePoliciesAndUpdateRoleDescriptions.selector;
    bytes4 public constant REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_AND_SET_ROLE_HOLDERS_SELECTOR = Llamacore.revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders.selector;
    bytes4 public constant INITIALIZE_ROLES_SELECTOR = Llamacore.initializeRoles.selector;
    bytes4 public constant SET_ROLE_HOLDERS_SELECTOR = Llamacore.setRoleHolders.selector;
    bytes4 public constant SET_ROLE_PERMISSIONS_SELECTOR = Llamacore.setRolePermissions.selector;
    bytes4 public constant REVOKE_EXPIRED_ROLES_SELECTOR = Llamacore.revokeExpiredRoles.selector;
    bytes4 public constant REVOKE_POLICIES_SELECTOR = Llamacore.revokePolicies.selector;
    bytes4 public constant UPDATE_ROLE_DESCRIPTIONS_SELECTOR = Llamacore.updateRoleDescriptions.selector;

    keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, mpStrategy1));
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

    function setUp() public {
        LlamaTestSetup.setUp();

        LlamaScript llamaScript = new LlamaScript();
        llamaCore.authorizeScript(address(llamaScript), true);
        
        vm.startPrank(address(mpCore));
        executeActionPermission = keccak256(abi.encode(address(llamaScript), EXECUTE_ACTION_SELECTOR, mpStrategy1));
        aggregatePermission = keccak256(abi.encode(address(llamaScript), AGGREGATE_SELECTOR, mpStrategy1));
        initializeRolesAndSetRoleHoldersPermissionId = keccak256(abi.encode(address(llamaScript), INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy1));
        initializeRolesAndSetRolePermissionsPermissionId = keccak256(abi.encode(address(llamaScript), INITIALIZE_ROLES_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy1));
        initializeRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId = keccak256(abi.encode(address(llamaScript), INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy1));
        createNewStrategiesAndSetRoleHoldersPermissionId = keccak256(abi.encode(address(llamaScript), CREATE_NEW_STRATEGIES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy1));
        createNewStrategiesAndInitializeRolesAndSetRoleHoldersPermissionId = keccak256(abi.encode(address(llamaScript), CREATE_NEW_STRATEGIES_AND_INITIALIZE_ROLES_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy1));
        createNewStrategiesAndSetRolePermissionsPermissionId = keccak256(abi.encode(address(llamaScript), CREATE_NEW_STRATEGIES_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy1));
        createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId = keccak256(abi.encode(address(llamaScript), CREATE_NEW_STRATEGIES_AND_NEW_ROLES_AND_SET_ROLE_HOLDERS_AND_SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy1));
        revokePoliciesAndUpdateRoleDescriptionsPermissionId = keccak256(abi.encode(address(llamaScript), REVOKE_POLICIES_AND_UPDATE_ROLE_DESCRIPTIONS_SELECTOR, mpStrategy1));
        revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHoldersPermissionId = keccak256(abi.encode(address(llamaScript), REVOKE_POLICIES_AND_UPDATE_ROLES_DESCRIPTIONS_AND_SET_ROLE_HOLDERS_SELECTOR, mpStrategy1));
        initializeRolesPermissionId = keccak256(abi.encode(address(llamaScript), INITIALIZE_ROLES_SELECTOR, mpStrategy1));
        setRoleHoldersPermissionId = keccak256(abi.encode(address(llamaScript), SET_ROLE_HOLDERS_SELECTOR, mpStrategy1));
        setRolePermissionsPermissionId = keccak256(abi.encode(address(llamaScript), SET_ROLE_PERMISSIONS_SELECTOR, mpStrategy1));
        revokeExpiredRolesPermissionId = keccak256(abi.encode(address(llamaScript), REVOKE_EXPIRED_ROLES_SELECTOR, mpStrategy1));
        revokePoliciesPermissionId = keccak256(abi.encode(address(llamaScript), REVOKE_POLICIES_SELECTOR, mpStrategy1));
        updateRoleDescriptionPerimssionId = keccak256(abi.encode(address(llamaScript), UPDATE_ROLE_DESCRIPTIONS_SELECTOR, mpStrategy1));

        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), executeActionPermission, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), aggregatePermission, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesAndSetRoleHoldersPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesAndSetRolePermissionsPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), createNewStrategiesAndSetRoleHoldersPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), createNewStrategiesAndInitializeRolesAndSetRoleHoldersPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), createNewStrategiesAndSetRolePermissionsPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissionsPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokePoliciesAndUpdateRoleDescriptionsPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHoldersPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), initializeRolesPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setRoleHoldersPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setRolePermissionsPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokeExpiredRolesPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), revokePoliciesPermissionId, true);
        mpPolicy.setRolePermission(uint8(Roles.ActionCreator), updateRoleDescriptionPerimssionId, true);
    }
}


contract Aggregate is LlamaTestSetup {}

contract InitializeRolesAndSetRoleHolders is LlamaTestSetup {}

contract InitializeRolesAndSetRolePermissions is LlamaTestSetup {}

contract InitializeRolesAndSetRoleHoldersAndSetRolePermissions is LlamaTestSetup {}

contract CreateNewStrategiesAndSetRoleHolders is LlamaTestSetup {}

contract CreateNewStrategiesAndInitializeRolesAndSetRoleHolders is LlamaTestSetup {}

contract CreateNewStrategiesAndSetRolePermissions is LlamaTestSetup {}

contract CreateNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolesPermissions is LlamaTestSetup {}

contract RevokePoliciesAndUpdateRoleDescriptions is LlamaTestSetup {}

contract RevokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders is LlamaTestSetup {}

contract InitializeRoles is LlamaTestSetup {}

contract SetRoleHolders is LlamaTestSetup {}

contract SetRolePermissions is LlamaTestSetup {}

contract RevokeExpiredRoles is LlamaTestSetup {}

contract RevokePolicies is LlamaTestSetup {}

contract UpdateRoleDescriptions is LlamaTestSetup  {
    function testFuzz_updateRoleDescriptions(UpdateRoleDescription[] calldata roleDescriptions) public {
        
    }
}

