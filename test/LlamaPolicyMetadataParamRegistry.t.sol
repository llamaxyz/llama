// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicyMetadataParamRegistry} from "src/LlamaPolicyMetadataParamRegistry.sol";

contract LlamaPolicyMetadataParamRegistryTest is LlamaTestSetup {
  event ColorSet(LlamaExecutor indexed llamaExecutor, string color);
  event LogoSet(LlamaExecutor indexed llamaExecutor, string logo);
}

contract Constructor is LlamaPolicyMetadataParamRegistryTest {
  function test_SetRootLlama() public {
    assertEq(address(policyMetadataParamRegistry.ROOT_LLAMA_EXECUTOR()), address(rootExecutor));
  }

  function test_SetLlamaFactory() public {
    assertEq(address(policyMetadataParamRegistry.LLAMA_FACTORY()), address(factory));
  }

  function test_SetRootColor() public {
    string memory llamaPurple = "#6A45EC";
    assertEq(policyMetadataParamRegistry.color(policyMetadataParamRegistry.ROOT_LLAMA_EXECUTOR()), llamaPurple);
  }

  function test_SetRootLogo() public {
    string memory llamaLogo =
      '<g><path fill="#fff" d="M91.749 446.038H85.15v2.785h2.54v14.483h-3.272v2.785h9.746v-2.785h-2.416v-17.268ZM104.122 446.038h-6.598v2.785h2.54v14.483h-3.271v2.785h9.745v-2.785h-2.416v-17.268ZM113.237 456.162c.138-1.435 1.118-2.2 2.885-2.2 1.767 0 2.651.765 2.651 2.423v.403l-4.859.599c-2.885.362-5.149 1.63-5.149 4.484 0 2.841 2.14 4.47 5.383 4.47 2.72 0 3.921-1.044 4.487-1.935h.276v1.685h3.782v-9.135c0-3.983-2.54-5.78-6.488-5.78-3.975 0-6.404 1.797-6.694 4.568v.418h3.726Zm-.483 5.528c0-1.1.829-1.629 2.03-1.796l3.989-.529v.626c0 2.354-1.546 3.537-3.672 3.537-1.491 0-2.347-.724-2.347-1.838ZM125.765 466.091h3.727v-9.386c0-1.796.938-2.576 2.25-2.576 1.173 0 1.753.682 1.753 1.838v10.124h3.727v-9.386c0-1.796.939-2.576 2.236-2.576 1.187 0 1.753.682 1.753 1.838v10.124h3.741v-10.639c0-2.646-1.657-4.22-4.183-4.22-2.264 0-3.312.989-3.92 2.075h-.276c-.414-.947-1.436-2.075-3.534-2.075-2.056 0-2.954.864-3.45 1.741h-.277v-1.462h-3.547v14.58ZM151.545 456.162c.138-1.435 1.118-2.2 2.885-2.2 1.767 0 2.65.765 2.65 2.423v.403l-4.859.599c-2.885.362-5.149 1.63-5.149 4.484 0 2.841 2.14 4.47 5.384 4.47 2.719 0 3.92-1.044 4.486-1.935h.276v1.685H161v-9.135c0-3.983-2.54-5.78-6.488-5.78-3.975 0-6.404 1.797-6.694 4.568v.418h3.727Zm-.484 5.528c0-1.1.829-1.629 2.03-1.796l3.989-.529v.626c0 2.354-1.546 3.537-3.672 3.537-1.491 0-2.347-.724-2.347-1.838Z"/><g fill="#6A45EC"><path d="M36.736 456.934c.004-.338.137-.661.372-.901.234-.241.552-.38.886-.389h16.748a5.961 5.961 0 0 0 2.305-.458 6.036 6.036 0 0 0 3.263-3.287c.303-.737.46-1.528.46-2.326V428h-4.738v21.573c-.004.337-.137.66-.372.901-.234.24-.552.379-.886.388H38.01a5.984 5.984 0 0 0-4.248 1.781A6.108 6.108 0 0 0 32 456.934v14.891h4.736v-14.891ZM62.868 432.111h-.21l.2.204v4.448h4.36l2.043 2.084a6.008 6.008 0 0 0-3.456 2.109 6.12 6.12 0 0 0-1.358 3.841v27.034h4.717v-27.04c.005-.341.14-.666.38-.907.237-.24.56-.378.897-.383h.726c2.783 0 3.727-1.566 4.006-2.224.28-.658.711-2.453-1.257-4.448l-4.617-4.702h-1.437M50.34 469.477a7.728 7.728 0 0 1 3.013.61c.955.403 1.82.994 2.547 1.738h5.732a12.645 12.645 0 0 0-4.634-5.201 12.467 12.467 0 0 0-6.658-1.93c-2.355 0-4.662.669-6.659 1.93a12.644 12.644 0 0 0-4.634 5.201h5.733a7.799 7.799 0 0 1 2.546-1.738 7.728 7.728 0 0 1 3.014-.61Z"/></g></g>';

    assertEq(policyMetadataParamRegistry.logo(policyMetadataParamRegistry.ROOT_LLAMA_EXECUTOR()), llamaLogo);
  }
}

contract GetMetadata is LlamaPolicyMetadataParamRegistryTest {
  function test_ReturnsColorAndLogo() public {
    string memory color = "#FF0000";
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.startPrank(address(rootExecutor));
    policyMetadataParamRegistry.setColor(mpExecutor, color);
    policyMetadataParamRegistry.setLogo(mpExecutor, logo);
    vm.stopPrank();
    (string memory _color, string memory _logo) = policyMetadataParamRegistry.getMetadata(mpExecutor);
    assertEq(_color, color);
    assertEq(_logo, logo);
  }
}

contract SetColor is LlamaPolicyMetadataParamRegistryTest {
  function test_SetsColor_CallerIsRootLlama() public {
    string memory color = "#FF0000";
    vm.prank(address(rootExecutor));
    vm.expectEmit();
    emit ColorSet(mpExecutor, color);
    policyMetadataParamRegistry.setColor(mpExecutor, color);
    assertEq(policyMetadataParamRegistry.color(mpExecutor), color);
  }

  function test_SetsColor_CallerIsMpLlama() public {
    string memory color = "#FF0000";
    vm.prank(address(mpExecutor));
    vm.expectEmit();
    emit ColorSet(mpExecutor, color);
    policyMetadataParamRegistry.setColor(mpExecutor, color);
    assertEq(policyMetadataParamRegistry.color(mpExecutor), color);
  }

  function test_SetsColor_CallerIsLlamaFactory() public {
    string memory color = "#FF0000";
    vm.prank(address(factory));
    vm.expectEmit();
    emit ColorSet(mpExecutor, color);
    policyMetadataParamRegistry.setColor(mpExecutor, color);
    assertEq(policyMetadataParamRegistry.color(mpExecutor), color);
  }

  function testFuzz_RevertIf_CallerIsUnauthorized(address caller, LlamaExecutor llamaExecutor, string memory color)
    public
  {
    vm.assume(caller != address(rootExecutor) && caller != address(llamaExecutor) && caller != address(factory));
    vm.expectRevert(LlamaPolicyMetadataParamRegistry.UnauthorizedCaller.selector);
    vm.prank(caller);
    policyMetadataParamRegistry.setColor(llamaExecutor, color);
  }
}

contract SetLogo is LlamaPolicyMetadataParamRegistryTest {
  function test_SetsLogo_CallerIsRootLlama() public {
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.prank(address(rootExecutor));
    vm.expectEmit();
    emit LogoSet(mpExecutor, logo);
    policyMetadataParamRegistry.setLogo(mpExecutor, logo);
    assertEq(policyMetadataParamRegistry.logo(mpExecutor), logo);
  }

  function test_SetsLogo_CallerIsMpLlama() public {
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.prank(address(mpExecutor));
    vm.expectEmit();
    emit LogoSet(mpExecutor, logo);
    policyMetadataParamRegistry.setLogo(mpExecutor, logo);
    assertEq(policyMetadataParamRegistry.logo(mpExecutor), logo);
  }

  function test_SetsLogo_CallerIsLlamaFactory() public {
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.prank(address(factory));
    vm.expectEmit();
    emit LogoSet(mpExecutor, logo);
    policyMetadataParamRegistry.setLogo(mpExecutor, logo);
    assertEq(policyMetadataParamRegistry.logo(mpExecutor), logo);
  }

  function testFuzz_RevertIf_CallerIsNotLlama(address caller, LlamaExecutor llamaExecutor, string memory logo) public {
    vm.assume(caller != address(rootExecutor) && caller != address(llamaExecutor) && caller != address(factory));
    vm.expectRevert(LlamaPolicyMetadataParamRegistry.UnauthorizedCaller.selector);
    vm.prank(caller);
    policyMetadataParamRegistry.setLogo(llamaExecutor, logo);
  }
}
