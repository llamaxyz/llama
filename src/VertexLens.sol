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
import {IVertexLens} from "src/interfaces/IVertexLens.sol";
/// @title Vertex Lens
/// @author Llama (vertex@llama.xyz)
/// @notice Utility contract to compute Vertex contract addresses.

contract VertexLens is IVertexLens {
  function computeVertexCoreAddress(string memory name, address vertexCoreLogic, address factory)
    public
    pure
    returns (VertexCore)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      vertexCoreLogic,
      bytes32(keccak256(abi.encode(name))), // salt
      factory // deployer
    );
    return VertexCore(_computedAddress);
  }

  function computeVertexPolicyAddress(
    string memory _name,
    string memory _symbol,
    PolicyGrantData[] memory _initialPolicies,
    address factory
  ) external pure returns (VertexPolicy) {
    bytes memory bytecode = type(VertexPolicy).creationCode;

    return VertexPolicy(
      computeCreate2Address(
        bytes32(keccak256(abi.encode(_symbol))), // salt
        keccak256(abi.encodePacked(bytecode, abi.encode(_name, _symbol, _initialPolicies))),
        factory // deployer
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
  function computeCreate2Address(bytes32 salt, bytes32 initCodeHash, address factory) internal pure returns (address) {
    return addressFromLast20Bytes(keccak256(abi.encodePacked(bytes1(0xff), factory, salt, initCodeHash)));
  }

  function addressFromLast20Bytes(bytes32 bytesValue) private pure returns (address) {
    return address(uint160(uint256(bytesValue)));
  }
}
