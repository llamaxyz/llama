// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {IVertexFactory} from "src/interfaces/IVertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, PolicyGrantData} from "src/lib/Structs.sol";
import {IVertexCore} from "src/interfaces/IVertexCore.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory is IVertexFactory {
  error OnlyVertex();

  /// @notice The VertexCore implementation (logic) contract.
  VertexCore public immutable vertexCoreLogic;

  /// @notice The Vertex Account implementation (logic) contract.
  VertexAccount public immutable vertexAccountLogic;

  /// @notice The Vertex instance responsible for deploying new Vertex instances.
  VertexCore public immutable rootVertex;

  /// @notice The current number of vertex systems created.
  uint256 public vertexCount;

  constructor(
    VertexCore _vertexCoreLogic,
    VertexAccount _vertexAccountLogic,
    string memory name,
    string memory symbol,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) {
    vertexCoreLogic = _vertexCoreLogic;
    vertexAccountLogic = _vertexAccountLogic;
    rootVertex = _deploy(name, symbol, initialStrategies, initialAccounts, initialPolicies);
  }

  modifier onlyRootVertex() {
    if (msg.sender != address(rootVertex)) revert OnlyVertex();
    _;
  }

  function deploy(
    string memory name,
    string memory symbol,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) external onlyRootVertex returns (VertexCore) {
    return _deploy(name, symbol, initialStrategies, initialAccounts, initialPolicies);
  }

  function _deploy(
    string memory name,
    string memory symbol,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) internal returns (VertexCore vertex) {
    VertexPolicy policy = new VertexPolicy{salt: keccak256(abi.encode(symbol))}(name, symbol, initialPolicies);

    vertex = VertexCore(Clones.cloneDeterministic(address(vertexCoreLogic), keccak256(abi.encode(name)))); //Clones.cloneDeterministic(address(vertexAccountImplementation),
      // salt)
    vertex.initialize(name, policy, vertexAccountLogic, initialStrategies, initialAccounts);

    policy.setVertex(address(vertex));
    unchecked {
      emit VertexCreated(vertexCount++, name, address(vertex), address(policy));
    }
  }

  function computeVertexCoreAddress(string memory name) public view returns (VertexCore) {
    address _computedAddress = Clones.predictDeterministicAddress(
      address(vertexCoreLogic),
      bytes32(keccak256(abi.encode(name))), // salt
      address(this) // deployer
    );
    return VertexCore(_computedAddress);
  }

  function computeVertexPolicyAddress(
    string memory _name,
    string memory _symbol,
    PolicyGrantData[] memory _initialPolicies
  ) external view returns (VertexPolicy) {
    bytes memory bytecode = type(VertexPolicy).creationCode;

    return VertexPolicy(
      computeCreate2Address(
        bytes32(keccak256(abi.encode(_symbol))), // salt
        keccak256(abi.encodePacked(bytecode, abi.encode(_name, _symbol, _initialPolicies))),
        address(this) // deployer
      )
    );
  }

  function computeVertexStrategyAddress(Strategy memory _strategy, VertexPolicy _policy, VertexCore _vertex)
    external
    pure
    returns (VertexStrategy)
  {
    bytes memory bytecode = type(VertexStrategy).creationCode;
    return VertexStrategy(
      computeCreate2Address(
        keccak256(
          abi.encodePacked(
            _strategy.approvalPeriod,
            _strategy.queuingPeriod,
            _strategy.expirationPeriod,
            _strategy.minApprovalPct,
            _strategy.minDisapprovalPct,
            _strategy.isFixedLengthApprovalPeriod
          )
        ), // salt
        keccak256(abi.encodePacked(bytecode, abi.encode(_strategy, _policy, address(_vertex)))),
        address(_vertex) // deployer
      )
    );
  }

  // pulled from the foundry StdUtils.sol contract
  function computeCreate2Address(bytes32 salt, bytes32 initCodeHash) internal view returns (address) {
    return computeCreate2Address(salt, initCodeHash, address(this));
  }

  function computeCreate2Address(bytes32 salt, bytes32 initcodeHash, address deployer)
    internal
    pure
    virtual
    returns (address)
  {
    return addressFromLast20Bytes(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initcodeHash)));
  }

  function addressFromLast20Bytes(bytes32 bytesValue) private pure returns (address) {
    return address(uint160(uint256(bytesValue)));
  }
}
