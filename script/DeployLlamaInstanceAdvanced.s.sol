// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson} from "forge-std/Script.sol";

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaInstanceConfigScript} from "src/llama-scripts/LlamaInstanceConfigScript.sol";
import {DeployUtils} from "script/DeployUtils.sol";
import {Action, ActionInfo} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployLlamaInstance} from "script/DeployLlamaInstance.s.sol";

contract DeployLlamaInstanceAdvanced is Script, DeployLlamaInstance {
  using stdJson for string;

  LlamaInstanceConfigScript configurationScript;
  uint8 constant CONFIG_ROLE = 1;

  function _authorizeScript(address deployer, ILlamaStrategy bootstrapStrategy) internal {
    bytes memory authorizeData = abi.encodeCall(LlamaCore.setScriptAuthorization, (address(configurationScript), true));
    uint256 authorizeActionId = core.createAction(
      CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData, "# Authorize configuration script\n\n"
    );
    ActionInfo memory authorizeActionInfo =
      ActionInfo(authorizeActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData);
    core.queueAction(authorizeActionInfo);
    core.executeAction(authorizeActionInfo);
  }

  function run(
    address deployer,
    string memory configFile,
    string memory strategyType,
    string memory updatedRoleDescription
  ) public {
    RoleDescription updatedDescription = RoleDescription.wrap(bytes32(bytes(updatedRoleDescription)));
    // Deploy Llama instance
    super.run(deployer, configFile, strategyType);
    LlamaExecutor executor = core.executor();

    // Get bootstrap strategy
    string memory jsonInput = DeployUtils.readScriptInput(configFile);
    address strategyLogic = address(jsonInput.readAddress(".strategyLogic"));
    bytes[] memory encodedStrategies = DeployUtils.readStrategies(jsonInput, strategyType);
    ILlamaStrategy bootstrapStrategy =
      ILlamaStrategy(Clones.predictDeterministicAddress(strategyLogic, keccak256(encodedStrategies[0]), address(core)));

    // Deploy configuration script
    vm.broadcast(deployer);
    configurationScript = new LlamaInstanceConfigScript(executor);
    DeployUtils.print(string.concat("  LlamaInstanceConfigScript:", vm.toString(address(configurationScript))));

    // Authorize script
    _authorizeScript(deployer, bootstrapStrategy);

    // Execute script
    bytes memory executeData =
      abi.encodeCall(LlamaInstanceConfigScript.execute, (deployer, bootstrapStrategy, updatedDescription));
    uint256 executeActionId = core.createAction(
      CONFIG_ROLE, bootstrapStrategy, address(configurationScript), 0, executeData, "# Execute configuration script\n\n"
    );
    ActionInfo memory executeActionInfo = ActionInfo(
      executeActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(configurationScript), 0, executeData
    );
    core.queueAction(executeActionInfo);
    core.executeAction(executeActionInfo);
  }
}
