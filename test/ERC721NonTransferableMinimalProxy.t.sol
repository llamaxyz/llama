// SPDX-License-Identifier: AGPL-3.0-only
// forgefmt: disable-start
// slightly modified version of solmate's ERC721.t.sol test file
// https://github.com/transmissions11/solmate/blob/d155ee8d58f96426f57c015b34dee8a410c1eacc/src/test/ERC721.t.sol
// refactored one invariant test to a fuzz to test the name and symbol are initialized correctly
pragma solidity ^0.8.19;

import {DSTestPlus} from "lib/solmate/src/test/utils/DSTestPlus.sol";
import {DSInvariantTest} from "lib/solmate/src/test/utils/DSInvariantTest.sol";

import {MockERC721} from "./mock/MockERC721MinimalProxy.sol";

import {ERC721TokenReceiver} from "lib/solmate/src/tokens/ERC721.sol";

import {Clones} from "@openzeppelin/proxy/Clones.sol";
contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        revert(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

contract ERC721Test is DSTestPlus {
    MockERC721 token;
    MockERC721 tokenLogic;

  function setUp() public {
    tokenLogic = new MockERC721();
    token = MockERC721(Clones.cloneDeterministic(address(tokenLogic), keccak256(abi.encode("Token"))));
    token.initialize("Token", "TKN");
  }

  function initializesWithCorrectNameAndSymbol(string memory name, string memory symbol) public {
    tokenLogic = new MockERC721();
    token = MockERC721(Clones.cloneDeterministic(address(tokenLogic), keccak256(abi.encode(name))));
    token.initialize("Token", "TKN");
    assertEq(token.name(), name);
    assertEq(token.symbol(), symbol);
  }

    function test__Mint() public {
        token.mint(address(0xBEEF), 1337);

        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(1337), address(0xBEEF));
    }

    function test__Burn() public {
        token.mint(address(0xBEEF), 1337);
        token.burn(1337);

        assertEq(token.balanceOf(address(0xBEEF)), 0);

        hevm.expectRevert("NOT_MINTED");
        token.ownerOf(1337);
    }

    function test_Approve() public {
        token.mint(address(this), 1337);

        token.approve(address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0xBEEF));
    }

    function test_ApproveBurn() public {
        token.mint(address(this), 1337);

        token.approve(address(0xBEEF), 1337);

        token.burn(1337);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.getApproved(1337), address(0));

        hevm.expectRevert("NOT_MINTED");
        token.ownerOf(1337);
    }

    function test_ApproveAll() public {
        token.setApprovalForAll(address(0xBEEF), true);

        assertTrue(token.isApprovedForAll(address(this), address(0xBEEF)));
    }

    function test_TransferFrom() public {
        address from = address(0xABCD);

        token.mint(from, 1337);

        hevm.prank(from);
        token.approve(address(this), 1337);

        token.transferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function test_TransferFromSelf() public {
        token.mint(address(this), 1337);

        token.transferFrom(address(this), address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_TransferFromApproveAll() public {
        address from = address(0xABCD);

        token.mint(from, 1337);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.transferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function test_SafeTransferFromToEOA() public {
        address from = address(0xABCD);

        token.mint(from, 1337);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function test_SafeTransferFromToERC721Recipient() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, 1337);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), 1337);
        assertBytesEq(recipient.data(), "");
    }

    function test_SafeTransferFromToERC721RecipientWithData() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, 1337);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), 1337, "testing 123");

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), 1337);
        assertBytesEq(recipient.data(), "testing 123");
    }

    function test_SafeMintToEOA() public {
        token.safeMint(address(0xBEEF), 1337);

        assertEq(token.ownerOf(1337), address(address(0xBEEF)));
        assertEq(token.balanceOf(address(address(0xBEEF))), 1);
    }

    function test_SafeMintToERC721Recipient() public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), 1337);

        assertEq(token.ownerOf(1337), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertBytesEq(to.data(), "");
    }

    function test_SafeMintToERC721RecipientWithData() public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), 1337, "testing 123");

        assertEq(token.ownerOf(1337), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertBytesEq(to.data(), "testing 123");
    }

    function test_FailMintToZero() public {
        token.mint(address(0), 1337);
    }

    function test_FailDoubleMint() public {
        token.mint(address(0xBEEF), 1337);
        token.mint(address(0xBEEF), 1337);
    }

    function test_FailBurnUnMinted() public {
        token.burn(1337);
    }

    function test_FailDoubleBurn() public {
        token.mint(address(0xBEEF), 1337);

        token.burn(1337);
        token.burn(1337);
    }

    function test_FailApproveUnMinted() public {
        token.approve(address(0xBEEF), 1337);
    }

    function test_FailApproveUnAuthorized() public {
        token.mint(address(0xCAFE), 1337);

        token.approve(address(0xBEEF), 1337);
    }

    function test_FailTransferFromUnOwned() public {
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function test_FailTransferFromWrongFrom() public {
        token.mint(address(0xCAFE), 1337);

        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function test_FailTransferFromToZero() public {
        token.mint(address(this), 1337);

        token.transferFrom(address(this), address(0), 1337);
    }

    function test_FailTransferFromNotOwner() public {
        token.mint(address(0xFEED), 1337);

        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function test_FailSafeTransferFromToNonERC721Recipient() public {
        token.mint(address(this), 1337);

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), 1337);
    }

    function test_FailSafeTransferFromToNonERC721RecipientWithData() public {
        token.mint(address(this), 1337);

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), 1337, "testing 123");
    }

    function test_FailSafeTransferFromToRevertingERC721Recipient() public {
        token.mint(address(this), 1337);

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 1337);
    }

    function test_FailSafeTransferFromToRevertingERC721RecipientWithData() public {
        token.mint(address(this), 1337);

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 1337, "testing 123");
    }

    function test_FailSafeTransferFromToERC721RecipientWithWrongReturnData() public {
        token.mint(address(this), 1337);

        token.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), 1337);
    }

    function test_FailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData() public {
        token.mint(address(this), 1337);

        token.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), 1337, "testing 123");
    }

    function test_FailSafeMintToNonERC721Recipient() public {
        token.safeMint(address(new NonERC721Recipient()), 1337);
    }

    function test_FailSafeMintToNonERC721RecipientWithData() public {
        token.safeMint(address(new NonERC721Recipient()), 1337, "testing 123");
    }

    function test_FailSafeMintToRevertingERC721Recipient() public {
        token.safeMint(address(new RevertingERC721Recipient()), 1337);
    }

    function test_FailSafeMintToRevertingERC721RecipientWithData() public {
        token.safeMint(address(new RevertingERC721Recipient()), 1337, "testing 123");
    }

    function test_FailSafeMintToERC721RecipientWithWrongReturnData() public {
        token.safeMint(address(new WrongReturnDataERC721Recipient()), 1337);
    }

    function test_FailSafeMintToERC721RecipientWithWrongReturnDataWithData() public {
        token.safeMint(address(new WrongReturnDataERC721Recipient()), 1337, "testing 123");
    }

    function test_FailBalanceOfZeroAddress() public view {
        token.balanceOf(address(0));
    }

    function test_FailOwnerOfUnminted() public view {
        token.ownerOf(1337);
    }

    function test_Metadata(string memory name, string memory symbol) public {
        MockERC721 tkn = new MockERC721();
        tkn.initialize(name, symbol);

        assertEq(tkn.name(), name);
        assertEq(tkn.symbol(), symbol);
    }

    function test_Mint(address to, uint256 id) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to, id);

        assertEq(token.balanceOf(to), 1);
        assertEq(token.ownerOf(id), to);
    }

    function test_Burn(address to, uint256 id) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to, id);
        token.burn(id);

        assertEq(token.balanceOf(to), 0);

        hevm.expectRevert("NOT_MINTED");
        token.ownerOf(id);
    }

    function test_Approve(address to, uint256 id) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(address(this), id);

        token.approve(to, id);

        assertEq(token.getApproved(id), to);
    }

    function test_ApproveBurn(address to, uint256 id) public {
        token.mint(address(this), id);

        token.approve(address(to), id);

        token.burn(id);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.getApproved(id), address(0));

        hevm.expectRevert("NOT_MINTED");
        token.ownerOf(id);
    }

    function test_ApproveAll(address to, bool approved) public {
        token.setApprovalForAll(to, approved);

        assertBoolEq(token.isApprovedForAll(address(this), to), approved);
    }

    function test_TransferFrom(uint256 id, address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        token.mint(from, id);

        hevm.prank(from);
        token.approve(address(this), id);

        token.transferFrom(from, to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function test_TransferFromSelf(uint256 id, address to) public {
        if (to == address(0) || to == address(this)) to = address(0xBEEF);

        token.mint(address(this), id);

        token.transferFrom(address(this), to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_TransferFromApproveAll(uint256 id, address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        token.mint(from, id);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.transferFrom(from, to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function test_SafeTransferFromToEOA(uint256 id, address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.mint(from, id);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function test_SafeTransferFromToERC721Recipient(uint256 id) public {
        address from = address(0xABCD);

        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, id);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), id);
        assertBytesEq(recipient.data(), "");
    }

    function test_SafeTransferFromToERC721RecipientWithData(uint256 id, bytes calldata data) public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, id);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), id, data);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), id);
        assertBytesEq(recipient.data(), data);
    }

    function test_SafeMintToEOA(uint256 id, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.safeMint(to, id);

        assertEq(token.ownerOf(id), address(to));
        assertEq(token.balanceOf(address(to)), 1);
    }

    function test_SafeMintToERC721Recipient(uint256 id) public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), id);

        assertEq(token.ownerOf(id), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertBytesEq(to.data(), "");
    }

    function test_SafeMintToERC721RecipientWithData(uint256 id, bytes calldata data) public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), id, data);

        assertEq(token.ownerOf(id), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertBytesEq(to.data(), data);
    }

    function test_FailMintToZero(uint256 id) public {
        token.mint(address(0), id);
    }

    function test_FailDoubleMint(uint256 id, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to, id);
        token.mint(to, id);
    }

    function test_FailBurnUnMinted(uint256 id) public {
        token.burn(id);
    }

    function test_FailDoubleBurn(uint256 id, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to, id);

        token.burn(id);
        token.burn(id);
    }

    function test_FailApproveUnMinted(uint256 id, address to) public {
        token.approve(to, id);
    }

    function test_FailApproveUnAuthorized(
        address owner,
        uint256 id,
        address to
    ) public {
        if (owner == address(0) || owner == address(this)) owner = address(0xBEEF);

        token.mint(owner, id);

        token.approve(to, id);
    }

    function test_FailTransferFromUnOwned(
        address from,
        address to,
        uint256 id
    ) public {
        token.transferFrom(from, to, id);
    }

    function test_FailTransferFromWrongFrom(
        address owner,
        address from,
        address to,
        uint256 id
    ) public {
        if (owner == address(0)) to = address(0xBEEF);
        if (from == owner) revert();

        token.mint(owner, id);

        token.transferFrom(from, to, id);
    }

    function test_FailTransferFromToZero(uint256 id) public {
        token.mint(address(this), id);

        token.transferFrom(address(this), address(0), id);
    }

    function test_FailTransferFromNotOwner(
        address from,
        address to,
        uint256 id
    ) public {
        if (from == address(this)) from = address(0xBEEF);

        token.mint(from, id);

        token.transferFrom(from, to, id);
    }

    function test_FailSafeTransferFromToNonERC721Recipient(uint256 id) public {
        token.mint(address(this), id);

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), id);
    }

    function test_FailSafeTransferFromToNonERC721RecipientWithData(uint256 id, bytes calldata data) public {
        token.mint(address(this), id);

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), id, data);
    }

    function test_FailSafeTransferFromToRevertingERC721Recipient(uint256 id) public {
        token.mint(address(this), id);

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), id);
    }

    function test_FailSafeTransferFromToRevertingERC721RecipientWithData(uint256 id, bytes calldata data) public {
        token.mint(address(this), id);

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), id, data);
    }

    function test_FailSafeTransferFromToERC721RecipientWithWrongReturnData(uint256 id) public {
        token.mint(address(this), id);

        token.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), id);
    }

    function test_FailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData(uint256 id, bytes calldata data)
        public
    {
        token.mint(address(this), id);

        token.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), id, data);
    }

    function test_FailSafeMintToNonERC721Recipient(uint256 id) public {
        token.safeMint(address(new NonERC721Recipient()), id);
    }

    function test_FailSafeMintToNonERC721RecipientWithData(uint256 id, bytes calldata data) public {
        token.safeMint(address(new NonERC721Recipient()), id, data);
    }

    function test_FailSafeMintToRevertingERC721Recipient(uint256 id) public {
        token.safeMint(address(new RevertingERC721Recipient()), id);
    }

    function test_FailSafeMintToRevertingERC721RecipientWithData(uint256 id, bytes calldata data) public {
        token.safeMint(address(new RevertingERC721Recipient()), id, data);
    }

    function test_FailSafeMintToERC721RecipientWithWrongReturnData(uint256 id) public {
        token.safeMint(address(new WrongReturnDataERC721Recipient()), id);
    }

    function test_FailSafeMintToERC721RecipientWithWrongReturnDataWithData(uint256 id, bytes calldata data) public {
        token.safeMint(address(new WrongReturnDataERC721Recipient()), id, data);
    }

    function test_FailOwnerOfUnminted(uint256 id) public view {
        token.ownerOf(id);
    }
}
