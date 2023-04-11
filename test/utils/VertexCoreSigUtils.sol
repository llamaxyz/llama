// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract VertexCoreSigUtils {
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
    bytes4 selector;
    bytes data;
    address policyholder;
    uint256 nonce;
  }

  struct CastApproval {
    uint256 actionId;
    uint8 role;
    string reason;
    address policyholder;
    uint256 nonce;
  }

  struct CastDisapproval {
    uint256 actionId;
    uint8 role;
    string reason;
    address policyholder;
    uint256 nonce;
  }

  /// @notice EIP-712 base typehash.
  bytes32 public constant EIP712_DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @notice EIP-712 createAction typehash.
  bytes32 public constant CREATE_ACTION_TYPEHASH = keccak256(
    "CreateAction(uint8 role,address strategy,address target,uint256 value,bytes4 selector,bytes data,address policyholder,uint256 nonce)"
  );

  /// @notice EIP-712 castApproval typehash.
  bytes32 public constant CAST_APPROVAL_TYPEHASH =
    keccak256("CastApproval(uint256 actionId,uint8 role,string reason,address policyholder,uint256 nonce)");

  /// @notice EIP-712 castDisapproval typehash.
  bytes32 public constant CAST_DISAPPROVAL_TYPEHASH =
    keccak256("CastDisapproval(uint256 actionId,uint8 role,string reason,address policyholder,uint256 nonce)");

  bytes32 internal DOMAIN_SEPARATOR;

  constructor(EIP712Domain memory eip712Domain) {
    DOMAIN_SEPARATOR = getDomainHash(eip712Domain);
  }

  /// @notice Returns the EIP-712 domain separator.
  function getDomainHash(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
    return keccak256(
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
        createAction.selector,
        keccak256(createAction.data),
        createAction.policyholder,
        createAction.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CreateAction domain, which can be used to
  /// recover the signer.
  function getCreateActionTypedDataHash(CreateAction memory createAction) public view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCreateActionHash(createAction)));
  }

  /// @notice Returns the hash of CastApproval.
  function getCastApprovalHash(CastApproval memory castApproval) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        CAST_APPROVAL_TYPEHASH,
        castApproval.actionId,
        castApproval.role,
        keccak256(bytes(castApproval.reason)),
        castApproval.policyholder,
        castApproval.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CastApproval domain, which can be used to
  /// recover the signer.
  function getCastApprovalTypedDataHash(CastApproval memory castApproval) public view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCastApprovalHash(castApproval)));
  }

  /// @notice Returns the hash of CastDisapproval.
  function getCastDisapprovalHash(CastDisapproval memory castDisapproval) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        CAST_DISAPPROVAL_TYPEHASH,
        castDisapproval.actionId,
        castDisapproval.role,
        keccak256(bytes(castDisapproval.reason)),
        castDisapproval.policyholder,
        castDisapproval.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CastDisapproval domain, which can be used to
  /// recover the signer.
  function getCastDisapprovalTypedDataHash(CastDisapproval memory castDisapproval) public view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCastDisapprovalHash(castDisapproval)));
  }
}
