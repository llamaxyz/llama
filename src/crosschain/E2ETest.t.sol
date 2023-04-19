// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {IInterchainSecurityModule} from "./interfaces/IInterchainSecurityModule.sol";
import {IMailbox} from "./interfaces/IMailbox.sol";
import {MockTarget} from "./MockTarget.sol";
import {VertexCrosschainExecutor} from "./VertexCrosschainExecutor.sol";
import {VertexCrosschainRelayer} from "./VertexCrosschainRelayer.sol";
import {Action} from "./Structs.sol";

contract VertexUnchainedE2ETest is Test {
  address private constant HYPERLANE_MAILBOX = 0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70;
  address private constant POLYGON_RELAYER = 0xE305B5a136bDFfaC05E7F461eeb42A7041F485b3;
  address private constant MAINNNET_ISM = 0xec48E52D960E54a179f70907bF28b105813877ee;

  IMailbox private constant mailbox = IMailbox(HYPERLANE_MAILBOX);
  IInterchainSecurityModule private constant ism = IInterchainSecurityModule(MAINNNET_ISM);

  uint32 MAINNET = 1;
  uint256 mainnetFork;
  uint256 polygonFork;

  function setUp() public {
    mainnetFork = vm.createFork(vm.rpcUrl("mainnet"), 17_076_708);
    polygonFork = vm.createFork(vm.rpcUrl("polygon"), 41_688_510);
  }

  function test_e2e() public {
    vm.selectFork(mainnetFork);
    MockTarget target = new MockTarget();
    VertexCrosschainExecutor executor = new VertexCrosschainExecutor();

    vm.selectFork(polygonFork);
    VertexCrosschainRelayer relayer = new VertexCrosschainRelayer();

    Action[] memory actions = new Action[](1);
    actions[0].target = address(target);
    actions[0].data = abi.encode("my super string");
    actions[0].selector = MockTarget.receiveMessage.selector;
    console2.logBytes32(bytes32(actions[0].selector));

    deal(address(this), 100 ether);
    relayer.relayCalls{value: 100e18}(actions, MAINNET, address(executor));

    bytes memory message =
      hex"000000127000000089000000000000000000000000f62849f9a0b5bf2913b396098f7c7019b51a820a000000010000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b00000000000000000000000000000000000000000000000000000000000000010000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e14960000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f0000000000000000000000000000000000000000000000000000000000000060f953cec70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000f6d7920737570657220737472696e670000000000000000000000000000000000";

    vm.selectFork(mainnetFork);
    vm.startPrank(POLYGON_RELAYER);
    vm.mockCall(
      MAINNNET_ISM, abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, "", message), abi.encode(true)
    );
    mailbox.process("", message);
  }

  fallback() external payable {}

  receive() external payable {}
}
