// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721MinimalProxy} from "src/lib/ERC721MinimalProxy.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {IVertexPolicy} from "src/interfaces/IVertexPolicy.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";
import {
  PermissionData,
  PermissionIdCheckpoint,
  PermissionMetadata,
  PolicyUpdateData,
  PolicyGrantData,
  PolicyRevokeData
} from "src/lib/Structs.sol";
import {console} from "lib/forge-std/src/console.sol";

/// @title VertexPolicy
/// @author Llama (vertex@llama.xyz)
/// @dev VertexPolicy is a (TODO: pick a soulbound standard) ERC721 contract where each token has permissions
/// @notice The permissions determine how the token can interact with the vertex administrator contract
contract VertexPolicy is ERC721MinimalProxy, IVertexPolicy {
  error SoulboundToken();
  error InvalidInput(); // TODO: Probably need more than one error?
  error OnlyVertex();
  error OnlyOnePolicyPerHolder();
  error AlreadyInitialized();
  error Expired();

  mapping(uint256 => mapping(bytes8 => PermissionIdCheckpoint[])) internal tokenPermissionCheckpoints;
  mapping(bytes8 => PermissionIdCheckpoint[]) internal permissionSupplyCheckpoints;
  mapping(uint256 => mapping(bytes8 => uint256)) public tokenToPermissionExpirationTimestamp;
  uint256[] public policyIds;
  string public baseURI;
  uint256 internal _totalSupply;
  address public vertex;

  modifier onlyVertex() {
    if (msg.sender != vertex) revert OnlyVertex();
    _;
  }

  constructor() initializer {}

  function initialize(string memory _name, string memory _symbol, PolicyGrantData[] memory initialPolicies)
    external
    initializer
  {
    __initializeERC721MinimalProxy(_name, _symbol);
    uint256 policyLength = initialPolicies.length;
    for (uint256 i = 0; i < policyLength; ++i) {
      _grantPolicy(initialPolicies[i]);
    }
  }

  function setVertex(address _vertex) external {
    if (vertex != address(0)) revert AlreadyInitialized();
    vertex = _vertex;
  }

  /// @inheritdoc IVertexPolicy
  function holderHasPermissionAt(address policyholder, bytes8 permissionId, uint256 timestamp)
    external
    view
    override
    returns (bool)
  {
    uint256 policyId = uint256(uint160(policyholder));
    PermissionIdCheckpoint[] storage _checkpoints = tokenPermissionCheckpoints[policyId][permissionId];
    uint256 length = _checkpoints.length;
    if (length == 0) return false;
    if (timestamp >= _checkpoints[length - 1].timestamp) return hasPermission(policyId, permissionId);
    if (timestamp < _checkpoints[0].timestamp) return false;
    uint256 min = 0;
    uint256 max = length - 1;
    while (max > min) {
      uint256 mid = (max + min + 1) / 2;
      if (_checkpoints[mid].timestamp <= timestamp) min = mid;
      else max = mid - 1;
    }
    bool hasQuantity = _checkpoints[min].quantity > 0;
    bool expired = tokenToPermissionExpirationTimestamp[policyId][permissionId] == 0
      ? false
      : tokenToPermissionExpirationTimestamp[policyId][permissionId] < timestamp;
    return hasQuantity && !expired;
  }

  /// @inheritdoc IVertexPolicy
  function getSupplyByPermissions(bytes8[] calldata _permissions) external view override returns (uint256) {
    uint256 permissionLength = _permissions.length;
    uint256 supply;
    unchecked {
      for (uint256 i; i < permissionLength; ++i) {
        PermissionIdCheckpoint[] storage _checkpoints = permissionSupplyCheckpoints[_permissions[i]];
        uint256 length = _checkpoints.length;
        if (length != 0) supply += _checkpoints[length - 1].quantity;
      }
    }
    return supply;
  }

  /// @inheritdoc IVertexPolicy
  function batchGrantPolicies(PolicyGrantData[] memory policyData) public override onlyVertex {
    uint256 length = policyData.length;
    for (uint256 i = 0; i < length; ++i) {
      _grantPolicy(policyData[i]);
      emit PolicyAdded(policyData[i]);
    }
  }

  /// @inheritdoc IVertexPolicy
  function batchUpdatePermissions(PolicyUpdateData[] calldata updateData) public override onlyVertex {
    uint256 length = updateData.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        if (updateData[i].permissionsToAdd.length == 0 && updateData[i].permissionsToRemove.length == 0) {
          revert InvalidInput();
        }
        _updatePermissions(updateData[i]);
        emit PermissionUpdated(updateData[i]);
      }
    }
  }

  /// @inheritdoc IVertexPolicy
  function batchRevokePolicies(PolicyRevokeData[] calldata policyData) public override onlyVertex {
    uint256 length = policyData.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        _revokePolicy(policyData[i]);
        emit PolicyRevoked(policyData[i]);
      }
    }
  }

  /// @inheritdoc IVertexPolicy
  function hasPermission(uint256 policyId, bytes8 permissionId) public view override returns (bool) {
    PermissionIdCheckpoint[] storage _permissionIdCheckpoint = tokenPermissionCheckpoints[policyId][permissionId];
    uint256 length = _permissionIdCheckpoint.length;
    bool expired = _isPermissionExpired(policyId, permissionId);
    bool hasQuantity = length > 0 ? _permissionIdCheckpoint[length - 1].quantity > 0 : false;
    return hasQuantity && !expired;
  }

  /// @notice updates a policyID with a new set of permissions
  /// @notice will delete and add permissions as needed
  /// @param updateData the policy token Id being updated
  function _updatePermissions(PolicyUpdateData calldata updateData) internal {
    if (ownerOf(updateData.policyId) == address(0)) revert InvalidInput();
    uint256 permissionsToAddLength = updateData.permissionsToAdd.length;
    uint256 permissionsToRemoveLength = updateData.permissionsToRemove.length;
    unchecked {
      for (uint256 i; i < permissionsToRemoveLength; ++i) {
        PermissionMetadata calldata data = updateData.permissionsToRemove[i];
        tokenPermissionCheckpoints[updateData.policyId][data.permissionId].push(
          PermissionIdCheckpoint(uint224(block.timestamp), 0)
        );
        PermissionIdCheckpoint[] storage supplyCheckpoint = permissionSupplyCheckpoints[data.permissionId];
        uint256 supplyIndex = supplyCheckpoint.length > 0 ? supplyCheckpoint.length - 1 : 0;
        supplyCheckpoint.push(
          PermissionIdCheckpoint(uint224(block.timestamp), supplyCheckpoint[supplyIndex].quantity - 1)
        );
      }
      for (uint256 j; j < permissionsToAddLength; ++j) {
        PermissionMetadata calldata data = updateData.permissionsToAdd[j];
        bool _hasPermission = hasPermission(updateData.policyId, data.permissionId);
        if (!_hasPermission) {
          tokenPermissionCheckpoints[updateData.policyId][data.permissionId].push(
            PermissionIdCheckpoint(uint224(block.timestamp), 1)
          );
          PermissionIdCheckpoint[] storage checkpoints = permissionSupplyCheckpoints[data.permissionId];
          uint32 quantity = checkpoints.length > 0 ? checkpoints[checkpoints.length - 1].quantity : 0;
          checkpoints.push(PermissionIdCheckpoint(uint224(block.timestamp), quantity + 1));
        }
        if (
          data.expirationTimestamp > 0
            && data.expirationTimestamp != tokenToPermissionExpirationTimestamp[updateData.policyId][data.permissionId]
        ) {
          if (data.expirationTimestamp < block.timestamp) revert Expired();
          tokenToPermissionExpirationTimestamp[updateData.policyId][data.permissionId] = data.expirationTimestamp;
        }
      }
    }
  }

  /// @notice mints a new policy token with the given permissions
  /// @param policyData the policy data to mint
  function _grantPolicy(PolicyGrantData memory policyData) internal {
    if (balanceOf(policyData.user) != 0) revert OnlyOnePolicyPerHolder();
    uint256 length = policyData.permissionsToAdd.length;
    uint256 policyId = uint256(uint160(policyData.user));
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        uint256 expiration = policyData.permissionsToAdd[i].expirationTimestamp;
        bytes8 permission = policyData.permissionsToAdd[i].permissionId;
        if (!hasPermission(policyId, permission)) {
          if (expiration > 0) {
            if (expiration < block.timestamp) revert Expired();
            tokenToPermissionExpirationTimestamp[policyId][permission] = expiration;
          }
          tokenPermissionCheckpoints[policyId][permission].push(PermissionIdCheckpoint(uint224(block.timestamp), 1));
          PermissionIdCheckpoint[] storage checkpoints = permissionSupplyCheckpoints[permission];
          uint256 checkpointsLength = checkpoints.length;
          uint32 quantity = checkpointsLength > 0 ? checkpoints[checkpointsLength - 1].quantity : 0;
          checkpoints.push(PermissionIdCheckpoint(uint224(block.timestamp), quantity + 1));
        }
      }
      ++_totalSupply;
      policyIds.push(policyId);
      _mint(policyData.user, policyId);
    }
  }

  /// @notice revokes given permissions from a policy token
  /// @param policyData the policy data to revoke
  function _revokePolicy(PolicyRevokeData calldata policyData) internal {
    if (ownerOf(policyData.policyId) == address(0)) revert InvalidInput();
    unchecked {
      uint256 permissionsLength = policyData.permissionIds.length;
      for (uint256 i = 0; i < permissionsLength; ++i) {
        tokenPermissionCheckpoints[policyData.policyId][policyData.permissionIds[i]].push(
          PermissionIdCheckpoint(uint224(block.timestamp), 0)
        );
        PermissionIdCheckpoint[] storage supplyCheckpoint = permissionSupplyCheckpoints[policyData.permissionIds[i]];
        supplyCheckpoint.push(
          PermissionIdCheckpoint(uint224(block.timestamp), supplyCheckpoint[supplyCheckpoint.length - 1].quantity - 1)
        );
      }
      _totalSupply--;
      _burn(policyData.policyId);
    }
  }

  function _isPermissionExpired(uint256 _policyId, bytes8 _permissionId) internal view returns (bool) {
    uint256 _expiration = tokenToPermissionExpirationTimestamp[_policyId][_permissionId];
    return _expiration < block.timestamp && _expiration != 0;
  }

  /// @inheritdoc IVertexPolicy
  function revokeExpiredPermission(uint256 policyId, bytes8 permissionId) external override returns (bool expired) {
    expired = _isPermissionExpired(policyId, permissionId);
    if (expired) {
      tokenPermissionCheckpoints[policyId][permissionId].push(PermissionIdCheckpoint(uint224(block.timestamp), 0));
      PermissionIdCheckpoint[] storage supplyCheckpoint = permissionSupplyCheckpoints[permissionId];
      supplyCheckpoint.push(
        PermissionIdCheckpoint(uint224(block.timestamp), supplyCheckpoint[supplyCheckpoint.length - 1].quantity - 1)
      );
    }
  }

  /// @notice sets the base URI for the contract
  /// @param _baseURI the base URI string to set
  function setBaseURI(string calldata _baseURI) public override onlyVertex {
    baseURI = _baseURI;
  }

  /// @dev overriding transferFrom to disable transfers for SBTs
  /// @dev this is a temporary solution, we will need to conform to a Souldbound standard
  function transferFrom(address, /* from */ address, /* to */ uint256 /* policyId */ ) public pure override {
    revert SoulboundToken();
  }

  /// @inheritdoc IVertexPolicy
  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  /// @notice returns the location of the policy metadata
  /// @param tokenId the id of the policy token
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    string[11] memory parts;

    parts[0] =
      '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" />';

    parts[1] =
      '<path transform="translate(10,10)" d="M3.0543 18.4836C3.05685 18.2679 3.14276 18.0616 3.29402 17.908C3.44526 17.7544 3.65009 17.6653 3.86553 17.6596H14.6671C15.177 17.6606 15.682 17.5611 16.1534 17.3667C16.6248 17.1724 17.0533 16.8869 17.4143 16.5267C17.7754 16.1665 18.062 15.7386 18.2577 15.2674C18.4534 14.7963 18.5545 14.2912 18.555 13.781V0H15.4987V13.781C15.4961 13.9967 15.4102 14.2029 15.2589 14.3566C15.1077 14.5102 14.9029 14.5993 14.6874 14.605H3.87567C2.84811 14.6061 1.86294 15.0151 1.13634 15.7422C0.409745 16.4694 0.00107373 17.4553 0 18.4836V27.9963H3.0543V18.4836Z" fill="url(#paint0_linear_2141_86430)"/><path transform="translate(10,10)" d="M19.9061 2.62599H19.7701L19.8999 2.7559V5.59734H22.7109L24.0292 6.92876C23.1533 7.10776 22.3661 7.58374 21.8004 8.27633C21.2346 8.96892 20.9252 9.83566 20.924 10.7302V28H23.9662V10.7261C23.9694 10.5086 24.0571 10.3008 24.2108 10.1469C24.3646 9.99309 24.5723 9.90526 24.7896 9.90211H25.2581C27.0529 9.90211 27.6615 8.90152 27.8419 8.4814C28.0224 8.06126 28.3003 6.91455 27.0308 5.63994L24.0534 2.63615H23.1265" fill="url(#paint1_linear_2141_86430)"/><path transform="translate(10,10)" d="M11.828 26.4971C12.4952 26.4965 13.1559 26.6289 13.7715 26.8864C14.3871 27.1439 14.9453 27.5214 15.4137 27.9969H19.1109C18.4455 26.6309 17.4099 25.4796 16.1222 24.6742C14.8345 23.8688 13.3465 23.4418 11.828 23.4418C10.3095 23.4418 8.82159 23.8688 7.53388 24.6742C6.2462 25.4796 5.21058 26.6309 4.54515 27.9969H8.24237C8.71076 27.5214 9.269 27.1439 9.88461 26.8864C10.5002 26.6289 11.1608 26.4965 11.828 26.4971Z" fill="url(#paint2_linear_2141_86430)"/><path transform="translate(10,10)" d="M36.616 11.494V11.824L41.17 23H44.756L49.288 11.824V11.494H45.878L43.062 19.678H42.842L40.026 11.494H36.616ZM49.53 17.236C49.53 21.152 52.214 23.264 55.712 23.264C59.166 23.264 60.816 21.196 61.3 19.59V19.26H58.286C58.066 19.986 57.428 21.02 55.712 21.02C53.908 21.02 52.874 19.656 52.83 18.006H61.498V17.06C61.498 13.32 59.078 11.23 55.624 11.23C52.214 11.23 49.53 13.32 49.53 17.236ZM52.852 16.048C52.962 14.618 53.908 13.474 55.668 13.474C57.406 13.474 58.33 14.618 58.396 16.048H52.852ZM63.6437 11.494V23H66.8777V17.324C66.8777 14.97 67.9337 13.914 70.0237 13.914H72.1357V11.45H70.1117C68.3077 11.45 67.4057 12.22 66.9657 13.254H66.7457V11.494H63.6437ZM73.3455 11.494V13.65H76.7115V19.854C76.7115 21.9 77.9875 23 80.0775 23H83.9055V20.734H80.1215L79.9455 20.558V13.65H83.6855V11.494H79.9455V7.6H79.6155L76.7115 8.964V11.494H73.3455ZM85.2181 17.236C85.2181 21.152 87.9021 23.264 91.4001 23.264C94.8541 23.264 96.5041 21.196 96.9881 19.59V19.26H93.9741C93.7541 19.986 93.1161 21.02 91.4001 21.02C89.5961 21.02 88.5621 19.656 88.5181 18.006H97.1861V17.06C97.1861 13.32 94.7661 11.23 91.3121 11.23C87.9021 11.23 85.2181 13.32 85.2181 17.236ZM88.5401 16.048C88.6501 14.618 89.5961 13.474 91.3561 13.474C93.0941 13.474 94.0181 14.618 94.0841 16.048H88.5401ZM98.0558 11.494V11.824L101.994 17.082L97.5498 22.67V23H101.048L103.952 19.172H104.172L106.944 23H110.354V22.67L106.306 17.302L110.64 11.824V11.494H107.186L104.348 15.212H104.128L101.466 11.494H98.0558Z" fill="white"/><defs><linearGradient id="paint0_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient><linearGradient id="paint1_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient><linearGradient id="paint2_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient></defs>';

    parts[2] = '<text x="10" y="60" class="base">';

    parts[3] = string.concat("Policy Id: ", Strings.toString(tokenId));

    parts[5] = '</text><text x="10" y="80" class="base">';

    parts[6] = name;

    parts[8] = '</text><text x="10" y="100" class="base">';

    parts[9] = symbol;

    parts[10] = "</text></svg>";

    string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8], parts[9], parts[10]));

    console.log(output);

    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "Vertex Policy ID:',
            Strings.toString(tokenId),
            '", "description": "Vertex is a identity access system for privledged smart contract functions", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(output)),
            '"}'
          )
        )
      )
    );
    output = string(abi.encodePacked("data:application/json;base64,", json));

    return output;
  }

  function getTokenPermissionCheckpoints(uint256 policyId, bytes8 permissionId)
    external
    view
    returns (PermissionIdCheckpoint[] memory)
  {
    return tokenPermissionCheckpoints[policyId][permissionId];
  }

  function getTokenPermissionSupplyCheckpoints(bytes8 permissionId)
    external
    view
    returns (PermissionIdCheckpoint[] memory)
  {
    return permissionSupplyCheckpoints[permissionId];
  }
}
