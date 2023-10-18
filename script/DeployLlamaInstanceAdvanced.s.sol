// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson} from "forge-std/Script.sol";

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaInstanceConfigScript} from "src/llama-scripts/LlamaInstanceConfigScript.sol";
import {DeployUtils} from "script/DeployUtils.sol";
import {Action, ActionInfo, PermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

contract DeployLlamaInstanceAdvanced is Script {
  using stdJson for string;

  LlamaInstanceConfigScript configurationScript;
  uint8 constant CONFIG_ROLE = 1;

  function _authorizeScript(address deployer, ILlamaStrategy bootstrapStrategy, LlamaCore core) internal {
    LlamaPolicy policy = core.policy();
    PermissionData memory authorizePermission =
      PermissionData(address(core), LlamaCore.setScriptAuthorization.selector, bootstrapStrategy);
    bytes memory authPermissionData =
      abi.encodeCall(LlamaPolicy.setRolePermission, (CONFIG_ROLE, authorizePermission, true));

    vm.broadcast();
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

    vm.broadcast();
    core.queueAction(authPermissionActionInfo);

    vm.broadcast();
    core.executeAction(authPermissionActionInfo);

    bytes memory authorizeData = abi.encodeCall(LlamaCore.setScriptAuthorization, (address(configurationScript), true));

    vm.broadcast();
    uint256 authorizeActionId = core.createAction(
      CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData, "# Authorize configuration script\n\n"
    );
    ActionInfo memory authorizeActionInfo =
      ActionInfo(authorizeActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData);

    vm.broadcast();
    core.queueAction(authorizeActionInfo);

    vm.broadcast();
    core.executeAction(authorizeActionInfo);
  }

  function _executeScript(
    address deployer,
    ILlamaStrategy bootstrapStrategy,
    LlamaCore core,
    string memory updatedRoleDescription
  ) internal {
    LlamaPolicy policy = core.policy();
    PermissionData memory executePermission =
      PermissionData(address(configurationScript), LlamaInstanceConfigScript.execute.selector, bootstrapStrategy);
    bytes memory executePermissionData =
      abi.encodeCall(LlamaPolicy.setRolePermission, (CONFIG_ROLE, executePermission, true));

    vm.broadcast();
    uint256 executePermissionActionId = core.createAction(
      CONFIG_ROLE,
      bootstrapStrategy,
      address(policy),
      0,
      executePermissionData,
      "# Grant permission to execute configuration script\n\n"
    );
    ActionInfo memory executePermissionActionInfo = ActionInfo(
      executePermissionActionId,
      deployer,
      CONFIG_ROLE,
      bootstrapStrategy,
      address(configurationScript),
      0,
      executePermissionData
    );

    core.queueAction(executePermissionActionInfo);
    core.executeAction(executePermissionActionInfo);

    RoleDescription updatedDescription = RoleDescription.wrap(bytes32(bytes(updatedRoleDescription)));
    bytes memory executeData =
      abi.encodeCall(LlamaInstanceConfigScript.execute, (deployer, bootstrapStrategy, updatedDescription));

    vm.broadcast();
    uint256 executeActionId = core.createAction(
      CONFIG_ROLE, bootstrapStrategy, address(configurationScript), 0, executeData, "# Execute configuration script\n\n"
    );

    ActionInfo memory executeActionInfo = ActionInfo(
      executeActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(configurationScript), 0, executeData
    );

    vm.broadcast();
    core.queueAction(executeActionInfo);

    vm.broadcast();
    core.executeAction(executeActionInfo);
  }

  function run(address deployer, LlamaCore core, string memory configFile) public {
    string memory updatedRoleDescription = "Core team";

    // Get bootstrap strategy
    string memory jsonInput = DeployUtils.readScriptInput(configFile);
    address strategyLogic = address(jsonInput.readAddress(".strategyLogic"));
    bytes[] memory encodedStrategies = DeployUtils.readStrategies(jsonInput);
    ILlamaStrategy bootstrapStrategy =
      ILlamaStrategy(Clones.predictDeterministicAddress(strategyLogic, keccak256(encodedStrategies[0]), address(core)));

    // Deploy configuration script
    vm.broadcast();
    configurationScript = new LlamaInstanceConfigScript();
    DeployUtils.print(string.concat("  LlamaInstanceConfigScript: ", vm.toString(address(configurationScript))));

    // Authorize script
    _authorizeScript(deployer, bootstrapStrategy, core);

    // Execute script
    _executeScript(deployer, bootstrapStrategy, core, updatedRoleDescription);
  }
}
