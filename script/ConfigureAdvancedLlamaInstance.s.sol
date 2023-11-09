// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson} from "forge-std/Script.sol";

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaInstanceConfigScriptTemplate} from "src/llama-scripts/LlamaInstanceConfigScriptTemplate.sol";
import {DeployUtils} from "script/DeployUtils.sol";
import {Action, ActionInfo, PermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

contract ConfigureAdvancedLlamaInstance is Script {
  using stdJson for string;

  uint8 constant CONFIG_ROLE = 1;

  ILlamaStrategy bootstrapStrategy;

  function _authorizeScript(address deployer, LlamaCore core, address configurationScript) internal {
    // Grant the CONFIG_ROLE permission to authorize scripts with the instant execution strategy
    LlamaPolicy policy = core.policy();
    PermissionData memory authorizePermission =
      PermissionData(address(core), LlamaCore.setScriptAuthorization.selector, bootstrapStrategy);
    bytes memory authPermissionData =
      abi.encodeCall(LlamaPolicy.setRolePermission, (CONFIG_ROLE, authorizePermission, true));

    vm.broadcast(deployer);
    uint256 authPermissionActionId = core.createAction(
      CONFIG_ROLE,
      bootstrapStrategy,
      address(policy),
      0,
      authPermissionData,
      "# Grant permission to authorize configuration script\n\n"
    );
    ActionInfo memory authPermissionActionInfo = ActionInfo(
      authPermissionActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(policy), 0, authPermissionData
    );

    vm.broadcast(deployer);
    core.queueAction(authPermissionActionInfo);

    vm.broadcast(deployer);
    core.executeAction(authPermissionActionInfo);

    bytes memory authorizeData = abi.encodeCall(LlamaCore.setScriptAuthorization, (configurationScript, true));

    vm.broadcast(deployer);
    uint256 authorizeActionId = core.createAction(
      CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData, "# Authorize configuration script\n\n"
    );
    ActionInfo memory authorizeActionInfo =
      ActionInfo(authorizeActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData);

    vm.broadcast(deployer);
    core.queueAction(authorizeActionInfo);

    vm.broadcast(deployer);
    core.executeAction(authorizeActionInfo);
  }

  function _executeScript(
    address deployer,
    LlamaCore core,
    address configurationScript,
    string memory updatedRoleDescription
  ) internal {
    // Grant the CONFIG_ROLE permission to execute the deployed script with the instant execution strategy
    LlamaPolicy policy = core.policy();
    PermissionData memory executePermission =
      PermissionData(configurationScript, LlamaInstanceConfigScriptTemplate.execute.selector, bootstrapStrategy);
    bytes memory executePermissionData =
      abi.encodeCall(LlamaPolicy.setRolePermission, (CONFIG_ROLE, executePermission, true));

    vm.broadcast(deployer);
    uint256 executePermissionActionId = core.createAction(
      CONFIG_ROLE,
      bootstrapStrategy,
      address(policy),
      0,
      executePermissionData,
      "# Grant permission to execute configuration script\n\n"
    );
    ActionInfo memory executePermissionActionInfo = ActionInfo(
      executePermissionActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(policy), 0, executePermissionData
    );

    vm.broadcast(deployer);
    core.queueAction(executePermissionActionInfo);

    vm.broadcast(deployer);
    core.executeAction(executePermissionActionInfo);

    RoleDescription updatedDescription = RoleDescription.wrap(bytes32(bytes(updatedRoleDescription)));
    bytes memory executeData =
      abi.encodeCall(LlamaInstanceConfigScriptTemplate.execute, (deployer, bootstrapStrategy, updatedDescription));

    vm.broadcast(deployer);
    uint256 executeActionId = core.createAction(
      CONFIG_ROLE, bootstrapStrategy, configurationScript, 0, executeData, "# Execute configuration script\n\n"
    );

    ActionInfo memory executeActionInfo =
      ActionInfo(executeActionId, deployer, CONFIG_ROLE, bootstrapStrategy, configurationScript, 0, executeData);

    vm.broadcast(deployer);
    core.queueAction(executeActionInfo);

    vm.broadcast(deployer);
    core.executeAction(executeActionInfo);
  }

  function run(
    address deployer,
    string memory configFile,
    LlamaCore core,
    address configurationScript,
    string memory updatedRoleDescription
  ) public {
    // Get bootstrap strategy
    string memory jsonInput = DeployUtils.readScriptInput(configFile);
    address strategyLogic = address(jsonInput.readAddress(".strategyLogic"));
    bytes[] memory encodedStrategies = DeployUtils.readStrategies(jsonInput);
    bootstrapStrategy =
      ILlamaStrategy(Clones.predictDeterministicAddress(strategyLogic, keccak256(encodedStrategies[0]), address(core)));

    // Authorize script
    _authorizeScript(deployer, core, configurationScript);

    // Execute script
    _executeScript(deployer, core, configurationScript, updatedRoleDescription);
  }
}
