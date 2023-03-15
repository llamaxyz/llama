// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, PolicyGrantData, PermissionData} from "src/lib/Structs.sol";
import {IVertexLens} from "src/interfaces/IVertexLens.sol";

/// @title Vertex Lens
/// @author Llama (vertex@llama.xyz)
/// @notice Utility contract to compute Vertex contract addresses.
contract VertexLens is IVertexLens {
  /// @inheritdoc IVertexLens
  function computePermissionId(PermissionData calldata permission) external pure returns (bytes32) {
    return keccak256(abi.encode(permission));
  }
  /// @inheritdoc IVertexLens

  function computeVertexCoreAddress(string memory name, address vertexCoreLogic, address factory)
    external
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

  /// @inheritdoc IVertexLens
  function computeVertexPolicyAddress(string memory name, address vertexPolicyLogic, address factory)
    external
    pure
    returns (VertexPolicy)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      vertexPolicyLogic,
      bytes32(keccak256(abi.encode(name))), // salt
      factory // deployer
    );
    return VertexPolicy(_computedAddress);
  }

  /// @inheritdoc IVertexLens
  function computeVertexStrategyAddress(address vertexStrategyLogic, Strategy memory _strategy, address _vertexCore)
    external
    pure
    returns (VertexStrategy)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      vertexStrategyLogic,
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
      _vertexCore // deployer
    );
    return VertexStrategy(_computedAddress);
  }

  /// @inheritdoc IVertexLens
  function computeVertexAccountAddress(address accountLogic, string calldata _account, address _vertexCore)
    external
    pure
    returns (VertexAccount)
  {
    return VertexAccount(
      payable(
        Clones.predictDeterministicAddress(
          accountLogic,
          keccak256(abi.encodePacked(_account)), // salt
          address(_vertexCore) // deployer
        )
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
