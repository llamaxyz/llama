// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {DeployLlamaFactory} from "script/DeployLlamaFactory.s.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {PolicyholderCheckpoints} from "src/lib/PolicyholderCheckpoints.sol";
import {PermissionData} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaRelativeHolderQuorum} from "src/strategies/LlamaRelativeHolderQuorum.sol";

contract DeployLlamaFactoryTest is Test, DeployLlamaFactory {
  function setUp() public virtual {}
}

contract Run is DeployLlamaFactoryTest {
  // This is the address that we're using with the CreateAction script to
  // automate action creation to deploy new llamaCore instances. It could be
  // replaced with any address that we hold the private key for.
  address LLAMA_INSTANCE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;

  function test_DeploysFactory() public {
    assertEq(address(factory), address(0));

    DeployLlamaFactory.run();

    assertFalse(address(factory) == address(0));
    assertEq(address(factory.LLAMA_CORE_LOGIC()), address(coreLogic));
    assertEq(address(factory.LLAMA_POLICY_LOGIC()), address(policyLogic));
    assertEq(address(factory.LLAMA_POLICY_METADATA_LOGIC()), address(policyMetadataLogic));
  }

  function test_DeploysCoreLogic() public {
    assertEq(address(coreLogic), address(0));

    DeployLlamaFactory.run();

    assertFalse(address(coreLogic) == address(0));
  }

  function test_DeploysStrategyLogic() public {
    assertEq(address(relativeQuorumLogic), address(0));

    DeployLlamaFactory.run();

    assertFalse(address(relativeQuorumLogic) == address(0));
  }

  function test_DeploysAccountLogic() public {
    assertEq(address(accountLogic), address(0));

    DeployLlamaFactory.run();

    assertFalse(address(accountLogic) == address(0));
  }

  function test_DeploysPolicyLogic() public {
    assertEq(address(policyLogic), address(0));

    DeployLlamaFactory.run();

    assertFalse(address(policyLogic) == address(0));
    assertEq(policyLogic.ALL_HOLDERS_ROLE(), 0);
  }

  function test_DeploysPolicyMetadata() public {
    assertEq(address(policyMetadataLogic), address(0));

    DeployLlamaFactory.run();

    assertFalse(address(policyMetadataLogic) == address(0));
    assertFalse(keccak256(abi.encode(policyMetadataLogic.getTokenURI("MyLlama", 42))) == keccak256(abi.encode("")));
  }

  function test_DeploysLens() public {
    assertEq(address(lens), address(0));

    DeployLlamaFactory.run();

    assertFalse(address(lens) == address(0));
    PermissionData memory permissionData = PermissionData(
      makeAddr("target"), // Could be any address, choosing a random one.
      bytes4(bytes32("transfer(address,uint256)")),
      ILlamaStrategy(makeAddr("strategy"))
    );
    assertEq(
      lens.computePermissionId(permissionData),
      bytes32(0xb015298f3f29356efa6d653f1f06c375fa6ad631144702003798f9939f8ce444)
    );
  }

  function assertEqStrategyStatus(
    LlamaCore core,
    ILlamaStrategy strategy,
    bool expectedDeployed,
    bool expectedAuthorized
  ) internal {
    (bool deployed, bool authorized) = core.strategies(strategy);
    assertEq(deployed, expectedDeployed);
    assertEq(authorized, expectedAuthorized);
  }
}
