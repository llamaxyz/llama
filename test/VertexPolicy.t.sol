// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "lib/forge-std/src/console.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {IVertexCore} from "src/interfaces/IVertexCore.sol";
import {IVertexPolicy} from "src/interfaces/IVertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {
  PermissionData, PolicyUpdateData, PermissionMetadata, PolicyGrantData, PolicyRevokeData
} from "src/lib/Structs.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {Base64} from "@solady/utils/Base64.sol";
import {console} from "lib/forge-std/src/console.sol";
import {VertexTestSetup} from "test/utils/VertexTestSetup.sol";

// TODO Need to uncomment and update tests.
contract VertexPolicyTest is VertexTestSetup {
  event PolicyAdded(PolicyGrantData grantData);
  event PermissionUpdated(PolicyUpdateData updateData);
  event PolicyRevoked(PolicyRevokeData revokeData);

  function _buildPermissionMetadata() internal pure returns (PermissionMetadata[] memory permissionMetadata) {
    PermissionData memory _permission = PermissionData(
      // TODO These values should be function inputs so they can fuzzed over.
      address(0xdeadbeef),
      bytes4(0x08080808),
      VertexStrategy(address(0xdeadbeefdeadbeef))
    );
    permissionMetadata = new PermissionMetadata[](1);
    permissionMetadata[0] =
      PermissionMetadata({permissionId: bytes8(keccak256(abi.encode(_permission))), expirationTimestamp: 0});
  }

  function _buildBatchGrantData(address _user) internal pure returns (PolicyGrantData[] memory _batchGrantData) {
    _batchGrantData = new PolicyGrantData[](1);
    _batchGrantData[0] = PolicyGrantData(_user, _buildPermissionMetadata());
  }
}

contract Initialize is VertexPolicyTest {
  function test_SetsNameAndSymbol() public {
    assertEq(policy.name(), "Root Vertex");
    assertEq(policy.symbol(), "V_Roo");
  }

  function test_RevertsIf_InitializeIsCalledTwice() public {
    PolicyGrantData[] memory policies = getDefaultPolicies();
    vm.expectRevert("Initializable: contract is already initialized");
    policy.initialize("Test", policies);
  }
}

contract HolderWeightAt is VertexPolicyTest {
  function test_ReturnsCorrectValue() public {
    // TODO
    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.number), 1);
    // assertEq(policy.holderWeightAt(policyHolderPam, permissionId1, block.number), 0);

    // vm.warp(block.timestamp + 100);

    // PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(0xdeadbeef));
    // policy.batchGrantPolicies(initialBatchGrantData);
    // policy.batchRevokePolicies(policyRevokeData);

    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.timestamp), 0);
    // assertEq(policy.holderWeightAt(address(0xdeadbeef), permissionId1, block.timestamp), 1);
    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.timestamp - 99), 1);
    // assertEq(policy.holderWeightAt(address(0xdeadbeef), permissionId1, block.timestamp - 99), 0);
  }
}

contract TotalSupplyAt is VertexPolicyTest {
// TODO Add tests.
}

contract BatchGrantPolicies is VertexPolicyTest {
  function test_CorrectlyGrantsPermission() public {
    // PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(policyHolderPam);
    // vm.expectEmit(true, true, true, true);
    // emit PolicyAdded(initialBatchGrantData[0]);
    // policy.batchGrantPolicies(initialBatchGrantData);
    // assertEq(policy.balanceOf(address(0xdeadbeef)), 1);
    // assertEq(policy.ownerOf(DEADBEEF_TOKEN_ID), address(0xdeadbeef));
  }

  function test_RevertIfPolicyAlreadyGranted() public {
    // PolicyGrantData[] memory policies;
    // vm.expectRevert(IVertexPolicy.OnlyOnePolicyPerHolder.selector);
    // policy.batchGrantPolicies(policies);
  }
}

contract BatchUpdatePermissions is VertexPolicyTest {
  function test_UpdatesPermissionsCorrectly() public {
    // bytes32 oldPermissionSignature = permissionId1;
    // assertEq(policy.hasPermission(policyIds[0], oldPermissionSignature), true);
    // permissionsToRevoke = permissionIds;

    // permission = PermissionData(
    //   address(0xdeadbeefdeadbeef), bytes4(0x09090909), VertexStrategy(address(0xdeadbeefdeadbeefdeafbeef))
    // );
    // permissions[0] = permission;
    // permissionsArray[0] = permissions;
    // permissionId1 = lens.computePermissionId(permission);
    // permissionIds[0] = permissionId;

    // PermissionMetadata[] memory toAdd = new PermissionMetadata[](1);
    // PermissionMetadata[] memory toRemove = new PermissionMetadata[](1);

    // toAdd[0] = PermissionMetadata(permissionId1, 0);
    // toRemove[0] = PermissionMetadata(permissionId2, 0);

    // PolicyUpdateData[] memory updateData = new PolicyUpdateData[](1);
    // updateData[0] = PolicyUpdateData(policyIds[0], toAdd, toRemove);

    // vm.warp(block.timestamp + 100);

    // vm.expectEmit(true, true, true, true);
    // emit PermissionUpdated(updateData[0]);

    // policy.batchUpdatePermissions(updateData);

    // assertEq(policy.hasPermission(policyIds[0], oldPermissionSignature), false);
    // assertEq(policy.hasPermission(policyIds[0], permissionId1), true);
    // assertEq(policy.holderWeightAt(address(this), oldPermissionSignature, block.timestamp - 100), 1);
    // assertEq(policy.holderWeightAt(address(this), oldPermissionSignature, block.timestamp), 0);
    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.timestamp - 100), 0);
    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.timestamp), 1);
  }

  function test_updatesTimeStamp() public {
    // bytes32 _permissionId = lens.computePermissionId(
    //   PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)))
    // ); // same permission as in setup

    // PermissionMetadata[] memory permissionsToAdd = new PermissionMetadata[](1);
    // permissionsToAdd[0] = PermissionMetadata(_permissionId, block.timestamp + 1 days);

    // PolicyUpdateData memory updateData = PolicyUpdateData(SELF_TOKEN_ID, permissionsToAdd, new
    // PermissionMetadata[](0));
    // PolicyUpdateData[] memory updateDataArray = new PolicyUpdateData[](1);
    // updateDataArray[0] = updateData;
    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, permissionId1), 0);
    // policy.batchUpdatePermissions(updateDataArray);
    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, permissionId1), block.timestamp + 1 days);
  }

  function test_CanSetPermissionWithExpirationDateToInfiniteExpiration() public {
    // TODO after matt's PR merges
  }
}

contract BatchRevokePolicies is VertexPolicyTest {
  function test_CorrectlyRevokesPolicy() public {
    // vm.expectEmit(true, true, true, true);
    // emit PolicyRevoked(policyRevokeData[0]);
    // policy.batchRevokePolicies(policyRevokeData);
    // assertEq(policy.balanceOf(address(this)), 0);
  }

  function test_RevertIf_PolicyNotGranted() public {
    // uint256 mockPolicyId = uint256(uint160(address(0xdeadbeef)));
    // policyIds[0] = mockPolicyId;
    // policyRevokeData[0] = PolicyRevokeData(mockPolicyId, permissionId);
    // vm.expectRevert("NOT_MINTED");
    // policy.batchRevokePolicies(policyRevokeData);
  }
}

contract HasPermission is VertexPolicyTest {
// TODO Add tests.
}

contract TransferFrom is VertexPolicyTest {
  function test_transferFrom_RevertIfTransferFrom() public {
    vm.expectRevert(IVertexPolicy.NonTransferableToken.selector);
    policy.transferFrom(address(this), address(0xdeadbeef), SELF_TOKEN_ID);
  }
}

contract Approve is VertexPolicyTest {
  function test_RevertIf_Called() public {
    vm.expectRevert(IVertexPolicy.NonTransferableToken.selector);
    policy.approve(address(0xdeadbeef), SELF_TOKEN_ID);
  }
}

contract SetApprovalForAll is VertexPolicyTest {
  function test_RevertIf_Called() public {
    vm.expectRevert(IVertexPolicy.NonTransferableToken.selector);
    policy.setApprovalForAll(address(0xdeadbeef), true);
  }
}

contract TokenURI is VertexPolicyTest {

    // The token's JSON metadata.
  // The `image` field is the *decoded* SVG image, but in the contract it's base64-encoded.
  struct Metadata {
    string name;
    string description;
    string image; // Decoded SVG.
  }
  
  function parseMetadata(string memory uri) internal returns (Metadata memory) {
    string[] memory inputs = new string[](3);
    inputs[0] = "node";
    inputs[1] = "test/lib/metadata.js";
    inputs[2] = uri;
    return abi.decode(vm.ffi(inputs), (Metadata));
  }
  
  // function assertEq(Metadata memory a, Metadata memory b) internal {
  //   assertEq(a.name, b.name, "name");
  //   assertEq(a.description, b.description, "description");
  //   assertEq(a.basefee, b.basefee, "basefee");
  //   assertEq(a.frequency, b.frequency, "frequency");
  //   assertEq(a.external_url, b.external_url, "external_url");
  //   assertEq(a.image, b.image, "image");
  // }
  
  function test_ReturnsCorrectTokenURI() public {
    string memory uri = policy.tokenURI(uint256(uint160(address(this))));
    Metadata memory metadata = parseMetadata(uri);
    assertEq(metadata.name, LibString.concat("Vertex Policy ID: ",LibString.toString(uint256(uint160(address(this))))));
    assertEq(metadata.description, "Vertex is a identity access system for privledged smart contract functions");

     string[11] memory parts;

    parts[0] =
      '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" />';

    parts[1] =
      '<path transform="translate(10,10)" d="M3.0543 18.4836C3.05685 18.2679 3.14276 18.0616 3.29402 17.908C3.44526 17.7544 3.65009 17.6653 3.86553 17.6596H14.6671C15.177 17.6606 15.682 17.5611 16.1534 17.3667C16.6248 17.1724 17.0533 16.8869 17.4143 16.5267C17.7754 16.1665 18.062 15.7386 18.2577 15.2674C18.4534 14.7963 18.5545 14.2912 18.555 13.781V0H15.4987V13.781C15.4961 13.9967 15.4102 14.2029 15.2589 14.3566C15.1077 14.5102 14.9029 14.5993 14.6874 14.605H3.87567C2.84811 14.6061 1.86294 15.0151 1.13634 15.7422C0.409745 16.4694 0.00107373 17.4553 0 18.4836V27.9963H3.0543V18.4836Z" fill="url(#paint0_linear_2141_86430)"/><path transform="translate(10,10)" d="M19.9061 2.62599H19.7701L19.8999 2.7559V5.59734H22.7109L24.0292 6.92876C23.1533 7.10776 22.3661 7.58374 21.8004 8.27633C21.2346 8.96892 20.9252 9.83566 20.924 10.7302V28H23.9662V10.7261C23.9694 10.5086 24.0571 10.3008 24.2108 10.1469C24.3646 9.99309 24.5723 9.90526 24.7896 9.90211H25.2581C27.0529 9.90211 27.6615 8.90152 27.8419 8.4814C28.0224 8.06126 28.3003 6.91455 27.0308 5.63994L24.0534 2.63615H23.1265" fill="url(#paint1_linear_2141_86430)"/><path transform="translate(10,10)" d="M11.828 26.4971C12.4952 26.4965 13.1559 26.6289 13.7715 26.8864C14.3871 27.1439 14.9453 27.5214 15.4137 27.9969H19.1109C18.4455 26.6309 17.4099 25.4796 16.1222 24.6742C14.8345 23.8688 13.3465 23.4418 11.828 23.4418C10.3095 23.4418 8.82159 23.8688 7.53388 24.6742C6.2462 25.4796 5.21058 26.6309 4.54515 27.9969H8.24237C8.71076 27.5214 9.269 27.1439 9.88461 26.8864C10.5002 26.6289 11.1608 26.4965 11.828 26.4971Z" fill="url(#paint2_linear_2141_86430)"/><path transform="translate(10,10)" d="M36.616 11.494V11.824L41.17 23H44.756L49.288 11.824V11.494H45.878L43.062 19.678H42.842L40.026 11.494H36.616ZM49.53 17.236C49.53 21.152 52.214 23.264 55.712 23.264C59.166 23.264 60.816 21.196 61.3 19.59V19.26H58.286C58.066 19.986 57.428 21.02 55.712 21.02C53.908 21.02 52.874 19.656 52.83 18.006H61.498V17.06C61.498 13.32 59.078 11.23 55.624 11.23C52.214 11.23 49.53 13.32 49.53 17.236ZM52.852 16.048C52.962 14.618 53.908 13.474 55.668 13.474C57.406 13.474 58.33 14.618 58.396 16.048H52.852ZM63.6437 11.494V23H66.8777V17.324C66.8777 14.97 67.9337 13.914 70.0237 13.914H72.1357V11.45H70.1117C68.3077 11.45 67.4057 12.22 66.9657 13.254H66.7457V11.494H63.6437ZM73.3455 11.494V13.65H76.7115V19.854C76.7115 21.9 77.9875 23 80.0775 23H83.9055V20.734H80.1215L79.9455 20.558V13.65H83.6855V11.494H79.9455V7.6H79.6155L76.7115 8.964V11.494H73.3455ZM85.2181 17.236C85.2181 21.152 87.9021 23.264 91.4001 23.264C94.8541 23.264 96.5041 21.196 96.9881 19.59V19.26H93.9741C93.7541 19.986 93.1161 21.02 91.4001 21.02C89.5961 21.02 88.5621 19.656 88.5181 18.006H97.1861V17.06C97.1861 13.32 94.7661 11.23 91.3121 11.23C87.9021 11.23 85.2181 13.32 85.2181 17.236ZM88.5401 16.048C88.6501 14.618 89.5961 13.474 91.3561 13.474C93.0941 13.474 94.0181 14.618 94.0841 16.048H88.5401ZM98.0558 11.494V11.824L101.994 17.082L97.5498 22.67V23H101.048L103.952 19.172H104.172L106.944 23H110.354V22.67L106.306 17.302L110.64 11.824V11.494H107.186L104.348 15.212H104.128L101.466 11.494H98.0558Z" fill="white"/><defs><linearGradient id="paint0_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient><linearGradient id="paint1_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient><linearGradient id="paint2_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient></defs>';

    parts[2] = '<text x="10" y="60" class="base">';

    parts[3] = string.concat("Policy Id: ", LibString.toString(uint256(uint160(address(this)))));

    parts[5] = '</text><text x="10" y="80" class="base">';

    parts[6] = policy.name();

    parts[8] = '</text><text x="10" y="100" class="base">';

    parts[9] = policy.symbol();

    parts[10] = "</text></svg>";

    string memory svg = string(
      abi.encodePacked(
        parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8], parts[9], parts[10]
      )
    );

    assertEq(metadata.image, svg);
  }

}

contract TotalSupply is VertexPolicyTest {
  function test_ReturnsCorrectTotalSupply() public {
    // assertEq(policy.totalSupply(), 1);
    // addresses[0] = address(0xdeadbeef);
    // policy.batchGrantPolicies(_buildBatchGrantData(addresses[0]));
    // assertEq(policy.totalSupply(), 2);
    // policy.batchRevokePolicies(policyRevokeData);
    // assertEq(policy.totalSupply(), 1);
  }
}

contract SetBaseURI is VertexPolicyTest {
  function test_RevertIf_CallerIsNotVertex() public {
    string memory baseURI = "https://vertex.link/policy/";
    vm.prank(address(0xdeadbeef));
    vm.expectRevert(IVertexPolicy.OnlyVertex.selector);
    policy.setBaseURI(baseURI);
  }

  function test_SetsBaseURIInStorage() public {
    string memory baseURI = "https://vertex.link/policy/";
    vm.prank(address(core));
    policy.setBaseURI(baseURI);
    assertEq(policy.baseURI(), baseURI);
  }
}

contract ExpirationTests is VertexPolicyTest {
  // TODO Refactor these so they are in the correct method contracts
  function test_expirationTimestamp_DoesNotHavePermissionIfExpired() public {
    // bytes32 _permissionId = lens.computePermissionId(
    //   PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)))
    // ); // same permission as in setup

    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, _permissionId), 0);
    // assertEq(policy.hasPermission(SELF_TOKEN_ID, _permissionId), true);

    // uint256 newExpirationTimestamp = block.timestamp + 1 days;

    // PermissionMetadata[] memory permissionsToAdd = new PermissionMetadata[](1);
    // permissionsToAdd[0] = PermissionMetadata(_permissionId, newExpirationTimestamp);

    // PolicyUpdateData memory updateData = PolicyUpdateData(SELF_TOKEN_ID, permissionsToAdd, new
    // PermissionMetadata[](0));
    // PolicyUpdateData[] memory updateDataArray = new PolicyUpdateData[](1);
    // updateDataArray[0] = updateData;

    // policy.batchUpdatePermissions(updateDataArray);

    // vm.warp(block.timestamp + 2 days);

    // assertEq(newExpirationTimestamp < block.timestamp, true);
    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, _permissionId), newExpirationTimestamp);
    // assertEq(policy.hasPermission(SELF_TOKEN_ID, _permissionId), false);
  }

  function test_grantPermissions_GrantsTokenWithExpiration() public {
    // uint256 _newExpirationTimestamp = block.timestamp + 1 days;
    // address _newAddress = address(0xdeadbeef);

    // PermissionMetadata[] memory _changes = new PermissionMetadata[](1);
    // _changes[0] = PermissionMetadata(permissionId1, _newExpirationTimestamp);

    // PolicyGrantData[] memory initialBatchGrantData = new PolicyGrantData[](1);
    // initialBatchGrantData[0] = PolicyGrantData(_newAddress, _changes);
    // policy.batchGrantPolicies(initialBatchGrantData);

    // assertEq(
    //   policy.tokenToPermissionExpirationTimestamp(uint256(uint160(_newAddress)), permissionId1),
    // _newExpirationTimestamp
    // );
  }

  function test_expirationTimestamp_RevertIfTimestampIsExpired() public {
    // vm.warp(block.timestamp + 1 days);

    // bytes32 _permissionId = lens.computePermissionId(
    //   PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)))
    // ); // same permission as in setup

    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, _permissionId), 0);
    // assertEq(policy.hasPermission(SELF_TOKEN_ID, _permissionId), true);

    // uint256 newExpirationTimestamp = block.timestamp - 1 days;

    // PermissionMetadata[] memory permissionsToAdd = new PermissionMetadata[](1);
    // permissionsToAdd[0] = PermissionMetadata(_permissionId, newExpirationTimestamp);

    // PolicyUpdateData memory updateData = PolicyUpdateData(SELF_TOKEN_ID, permissionsToAdd, new
    // PermissionMetadata[](0));
    // PolicyUpdateData[] memory updateDataArray = new PolicyUpdateData[](1);
    // updateDataArray[0] = updateData;

    // PolicyGrantData[] memory grantData = new PolicyGrantData[](1);
    // grantData[0] = PolicyGrantData(address(0x1), permissionsToAdd);

    // vm.expectRevert(IVertexPolicy.Expired.selector);
    // policy.batchGrantPolicies(grantData);
    // assertEq(block.timestamp > newExpirationTimestamp, true);
    // vm.expectRevert(IVertexPolicy.Expired.selector);
    // policy.batchUpdatePermissions(updateDataArray);
  }
}
