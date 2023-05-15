// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicyMetadataParamRegistry} from "src/LlamaPolicyMetadataParamRegistry.sol";

contract LlamaPolicyMetadataParamRegistryTest is LlamaTestSetup {
  event ColorSet(LlamaCore indexed llamaCore, string color);
  event LogoSet(LlamaCore indexed llamaCore, string logo);
}

contract Constructor is LlamaPolicyMetadataParamRegistryTest {
  function test_SetRootLlama() public {
    assertEq(address(policyMetadataParamRegistry.ROOT_LLAMA()), address(rootCore));
  }
}

contract GetMetadata is LlamaPolicyMetadataParamRegistryTest {
  function test_ReturnsColorAndLogo() public {
    string memory color = "#FF0000";
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.startPrank(address(rootCore));
    policyMetadataParamRegistry.setColor(mpCore, color);
    policyMetadataParamRegistry.setLogo(mpCore, logo);
    vm.stopPrank();
    (string memory _color, string memory _logo) = policyMetadataParamRegistry.getMetadata(mpCore);
    assertEq(_color, color);
    assertEq(_logo, logo);
  }
}

contract SetColor is LlamaPolicyMetadataParamRegistryTest {
  function test_SetsColor_CallerIsRootLlama() public {
    string memory color = "#FF0000";
    vm.prank(address(rootCore));
    vm.expectEmit();
    emit ColorSet(mpCore, color);
    policyMetadataParamRegistry.setColor(mpCore, color);
    assertEq(policyMetadataParamRegistry.color(mpCore), color);
  }

  function test_SetsColor_CallerIsMpLlama() public {
    string memory color = "#FF0000";
    vm.prank(address(mpCore));
    vm.expectEmit();
    emit ColorSet(mpCore, color);
    policyMetadataParamRegistry.setColor(mpCore, color);
    assertEq(policyMetadataParamRegistry.color(mpCore), color);
  }

  /// forge-config: default.fuzz.runs = 100
  /// forge-config: ci.fuzz.runs = 1
  function testFuzz_RevertIf_CallerIsNotLlama(address caller, LlamaCore llamaCore, string memory color) public {
    vm.assume(caller != address(rootCore) && caller != address(llamaCore));
    vm.expectRevert(LlamaPolicyMetadataParamRegistry.OnlyLlamaOrRootLlama.selector);
    vm.prank(caller);
    policyMetadataParamRegistry.setColor(llamaCore, color);
  }
}

contract SetLogo is LlamaPolicyMetadataParamRegistryTest {
  function test_SetsLogo_CallerIsRootLlama() public {
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.prank(address(rootCore));
    vm.expectEmit();
    emit LogoSet(mpCore, logo);
    policyMetadataParamRegistry.setLogo(mpCore, logo);
    assertEq(policyMetadataParamRegistry.logo(mpCore), logo);
  }

  function test_SetsLogo_CallerIsMpLlama() public {
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.prank(address(mpCore));
    vm.expectEmit();
    emit LogoSet(mpCore, logo);
    policyMetadataParamRegistry.setLogo(mpCore, logo);
    assertEq(policyMetadataParamRegistry.logo(mpCore), logo);
  }
  /// forge-config: default.fuzz.runs = 100
  /// forge-config: ci.fuzz.runs = 1

  function testFuzz_RevertIf_CallerIsNotLlama(address caller, LlamaCore llamaCore, string memory logo) public {
    vm.assume(caller != address(rootCore) && caller != address(llamaCore));
    vm.expectRevert(LlamaPolicyMetadataParamRegistry.OnlyLlamaOrRootLlama.selector);
    vm.prank(caller);
    policyMetadataParamRegistry.setLogo(llamaCore, logo);
  }
}
