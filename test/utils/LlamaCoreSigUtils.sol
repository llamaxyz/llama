// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ActionInfo} from "src/lib/Structs.sol";

contract LlamaCoreSigUtils {
  struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
  }

  struct CreateAction {
    uint8 role;
    address strategy;
    address target;
    uint256 value;
    bytes data;
    address policyholder;
    uint256 nonce;
  }

  struct CastApproval {
    ActionInfo actionInfo;
    uint8 role;
    string reason;
    address policyholder;
    uint256 nonce;
  }

  struct CastDisapproval {
    ActionInfo actionInfo;
    uint8 role;
    string reason;
    address policyholder;
    uint256 nonce;
  }

  /// @notice EIP-712 base typehash.
  bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @notice EIP-712 createAction typehash.
  bytes32 internal constant CREATE_ACTION_TYPEHASH = keccak256(
    "CreateAction(uint8 role,address strategy,address target,uint256 value,bytes data,address policyholder,uint256 nonce)"
  );

  /// @notice EIP-712 castApproval typehash.
  bytes32 internal constant CAST_APPROVAL_TYPEHASH = keccak256(
    "CastApproval((uint256 id,address creator,address strategy,address target,uint256 value,bytes data),uint8 role,string reason,address policyholder,uint256 nonce)"
  );

  /// @notice EIP-712 castDisapproval typehash.
  bytes32 internal constant CAST_DISAPPROVAL_TYPEHASH = keccak256(
    "CastDisapproval((uint256 id,address creator,address strategy,address target,uint256 value, bytes data),uint8 role,string reason,address policyholder,uint256 nonce)"
  );

  bytes32 internal DOMAIN_SEPARATOR;

  /// @notice Sets the EIP-712 domain separator.
  function setDomainHash(EIP712Domain memory eip712Domain) internal {
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        EIP712_DOMAIN_TYPEHASH,
        keccak256(bytes(eip712Domain.name)),
        keccak256(bytes(eip712Domain.version)),
        eip712Domain.chainId,
        eip712Domain.verifyingContract
      )
    );
  }

  /// @notice Returns the hash of CreateAction.
  function getCreateActionHash(CreateAction memory createAction) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        CREATE_ACTION_TYPEHASH,
        createAction.role,
        createAction.strategy,
        createAction.target,
        createAction.value,
        keccak256(createAction.data),
        createAction.policyholder,
        createAction.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CreateAction domain, which can be used to
  /// recover the signer.
  function getCreateActionTypedDataHash(CreateAction memory createAction) internal view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCreateActionHash(createAction)));
  }

  /// @notice Returns the hash of CastApproval.
  function getCastApprovalHash(CastApproval memory castApproval) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        CAST_APPROVAL_TYPEHASH,
        castApproval.actionInfo,
        castApproval.role,
        keccak256(bytes(castApproval.reason)),
        castApproval.policyholder,
        castApproval.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CastApproval domain, which can be used to
  /// recover the signer.
  function getCastApprovalTypedDataHash(CastApproval memory castApproval) internal view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCastApprovalHash(castApproval)));
  }

  /// @notice Returns the hash of CastDisapproval.
  function getCastDisapprovalHash(CastDisapproval memory castDisapproval) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        CAST_DISAPPROVAL_TYPEHASH,
        castDisapproval.actionInfo,
        castDisapproval.role,
        keccak256(bytes(castDisapproval.reason)),
        castDisapproval.policyholder,
        castDisapproval.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CastDisapproval domain, which can be used to
  /// recover the signer.
  function getCastDisapprovalTypedDataHash(CastDisapproval memory castDisapproval) internal view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCastDisapprovalHash(castDisapproval)));
  }
}
