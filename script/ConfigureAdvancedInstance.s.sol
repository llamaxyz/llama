// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson} from "forge-std/Script.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaLens} from "src/LlamaLens.sol";
import {LlamaInstanceConfigScript} from "src/llama-scripts/LlamaInstanceConfigScript.sol";
import {DeployUtils} from "script/DeployUtils.sol";
import {Action, ActionInfo} from "src/lib/Structs.sol";
import {DeployLlamaInstance} from "script/DeployLlamaInstance.s.sol";

contract ConfigureAdvancedInstance is Script, DeployLlamaInstance {
  using stdJson for string;

  uint8 constant CONFIG_ROLE = 1;

  function run(
    address deployer,
    LlamaInstanceConfigScript configurationScript,
    string memory configFile,
    string memory strategyType,
    LlamaLens lens
  ) public {
    super.run(deployer, configFile);

    RoleDescription description = RoleDescription("Core Team");

    string memory jsonInput = DeployUtils.readScriptInput(configFile);
    address strategyLogic = address(jsonInput.readAddress(".strategyLogic"));
    bytes[] memory encodedStrategies = DeployUtils.readRelativeStrategies(jsonInput);
    ILlamaStrategy bootstrapStrategy =
      lens.computeLlamaStrategyAddress(strategyLogic, encodedStrategies[0], address(core));

    string memory authorizeScriptDescription = "# Authorize configuration script\n\n";
    string memory executeScriptDescription = "# Execute configuration script\n\n";

    vm.broadcast();
    configurationScript = new LlamaInstanceConfigScript(core.executor());
    DeployUtils.print(string.concat("  LlamaInstanceConfigScript:", vm.toString(address(configurationScript))));

    Authorize script
    bytes memory authorizeData = abi.encodeCall(LlamaCore.setScriptAuthorization, (address(configurationScript),
    true));
    uint256 authorizeActionId =
      core.createAction(CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData, authorizeScriptDescription);
    ActionInfo memory authorizeActionInfo =
      ActionInfo(authorizeActionId, deployer, CONFIG_ROLE, bootstrapStrategy, address(core), 0, authorizeData);
    core.queueAction(authorizeActionInfo);
    core.executeAction(authorizeActionInfo);

    // Execute script
    bytes memory executeData = abi.encodeCall(LlamaInstanceConfigScript.execute, (deployer, bootstrapStrategy));
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
