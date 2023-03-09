import {VertexFactoryTest} from "./VertexFactory.t.sol";
import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {Strategy, PolicyGrantData} from "src/lib/Structs.sol";

contract ComputeAddress is VertexFactoryTest {
  // TODO Tests for Vertex Lens.

  function test_ComputesExpectedAddressForVertexCore() public {
    VertexCore computedVertexCore =
      vertexLens.computeVertexCoreAddress("NewProject", address(vertexCoreLogic), address(vertexFactory));
    VertexCore deployedVertexCore = deployVertex();
    assertEq(address(computedVertexCore), address(deployedVertexCore));
  }

  function test_ComputesExpectedAddressForPolicy() public {
    VertexPolicy computedVertexPolicy =
      vertexLens.computeVertexPolicyAddress("NewProject", address(vertexPolicyLogic), address(vertexFactory));
    VertexCore deployedVertexCore = deployVertex();
    VertexPolicy deployedVertexPolicy = VertexPolicy(VertexCore(deployedVertexCore).policy());
    assertEq(address(computedVertexPolicy), address(deployedVertexPolicy));
  }

  function test_ComputeVertexStrategyAddress() public {
    // Strategy memory _strategy, VertexPolicy _policy, VertexCore _vertex
    Strategy[] memory initialStrategies = createInitialStrategies();
    VertexPolicy computedVertexPolicy =
      vertexLens.computeVertexPolicyAddress("NewProject", address(vertexPolicyLogic), address(vertexFactory));
    VertexCore computedVertexCore =
      vertexLens.computeVertexCoreAddress("NewProject", address(vertexCoreLogic), address(vertexFactory));

    VertexStrategy computedVertexStrategy =
      vertexLens.computeVertexStrategyAddress(initialStrategies[0], computedVertexPolicy, address(computedVertexCore));
    console2.logAddress(address(computedVertexStrategy));
    vm.expectEmit(true, true, true, true);
    emit StrategyAuthorized(computedVertexStrategy, initialStrategies[0]);
    deployVertex();
  }

  function deployVertex() public returns (VertexCore) {
    Strategy[] memory initialStrategies = createInitialStrategies();
    string[] memory initialAccounts = buildInitialAccounts();
    PolicyGrantData[] memory initialPolicies = buildInitialPolicyGrantData();
    vm.prank(address(rootVertex));
    return vertexFactory.deploy("NewProject", "NP", initialStrategies, initialAccounts, initialPolicies);
  }
}
