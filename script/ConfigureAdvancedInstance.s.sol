// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson} from "forge-std/Script.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaLens} from "src/LlamaLens.sol";
import {LlamaInstanceConfigScript} from "src/llama-scripts/LlamaInstanceConfigScript.sol";
import {DeployUtils} from "script/DeployUtils.sol";
import {Action, ActionInfo} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployLlamaInstance} from "script/DeployLlamaInstance.s.sol";

contract ConfigureAdvancedInstance is Script, DeployLlamaInstance {
  using stdJson for string;

  LlamaInstanceConfigScript configurationScript;
  uint8 constant CONFIG_ROLE = 1;

  function run(address deployer, string memory configFile, string memory strategyType, LlamaLens lens) public {
    string memory authorizeScriptDescription = "# Authorize configuration script\n\n";
    string memory executeScriptDescription = "# Execute configuration script\n\n";
    RoleDescription description = RoleDescription.wrap(bytes32(bytes("Core Team")));

    // Deploy Llama instance
    super.run(deployer, configFile, strategyType);

    // Get bootstrap strategy
    string memory jsonInput = DeployUtils.readScriptInput(configFile);
    address strategyLogic = address(jsonInput.readAddress(".strategyLogic"));
    bytes[] memory encodedStrategies = DeployUtils.readStrategies(jsonInput, strategyType);
    ILlamaStrategy bootstrapStrategy =
      lens.computeLlamaStrategyAddress(strategyLogic, encodedStrategies[0], address(core));

    // Deploy configuration script
    vm.broadcast();
    configurationScript = new LlamaInstanceConfigScript(core.executor());
    DeployUtils.print(string.concat("  LlamaInstanceConfigScript:", vm.toString(address(configurationScript))));

    // Authorize script
    bytes memory authorizeData = abi.encodeCall(LlamaCore.setScriptAuthorization, (address(configurationScript), true));
    uint256 authorizeActionId =
      core.createAction(CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData, authorizeScriptDescription);
    ActionInfo memory authorizeActionInfo =
      ActionInfo(authorizeActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData);
    core.queueAction(authorizeActionInfo);
    core.executeAction(authorizeActionInfo);

    // Execute script
    bytes memory executeData =
      abi.encodeCall(LlamaInstanceConfigScript.execute, (deployer, bootstrapStrategy, description));
    uint256 executeActionId = core.createAction(
      CONFIG_ROLE, bootstrapStrategy, address(configurationScript), 0, executeData, executeScriptDescription
    );
    ActionInfo memory executeActionInfo = ActionInfo(
      executeActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(configurationScript), 0, executeData
    );
    core.queueAction(executeActionInfo);
    core.executeAction(executeActionInfo);
  }
}
