// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {Solarray} from "@solarray/Solarray.sol";

import {SolarrayLlama} from "test/utils/SolarrayLlama.sol";
import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {Action, RoleHolderData, RolePermissionData, PermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaPolicyMetadata} from "src/LlamaPolicyMetadata.sol";

contract LlamaFactoryTest is LlamaTestSetup {
  uint128 constant DEFAULT_QUANTITY = 1;
  string color = "#FF0420";
  string logo =
    '<g fill="#FF0420"><path d="M44.876 462c-3.783 0-6.883-.881-9.3-2.645-2.384-1.794-3.576-4.344-3.576-7.65 0-.692.08-1.542.238-2.55.414-2.266 1.002-4.989 1.765-8.169C36.165 432.329 41.744 428 50.742 428c2.448 0 4.641.409 6.58 1.228 1.94.787 3.466 1.983 4.579 3.589 1.112 1.574 1.669 3.463 1.669 5.666 0 .661-.08 1.496-.239 2.503a106.077 106.077 0 0 1-1.716 8.169c-1.113 4.314-3.037 7.54-5.77 9.681-2.735 2.109-6.39 3.164-10.97 3.164Zm.668-6.8c1.78 0 3.29-.52 4.53-1.558 1.272-1.039 2.178-2.629 2.718-4.77.731-2.959 1.288-5.541 1.67-7.744.127-.661.19-1.338.19-2.031 0-2.865-1.51-4.297-4.53-4.297-1.78 0-3.307.519-4.578 1.558-1.24 1.039-2.13 2.629-2.671 4.77-.572 2.109-1.145 4.691-1.717 7.744-.127.63-.19 1.291-.19 1.983 0 2.897 1.526 4.345 4.578 4.345ZM68.409 461.528c-.35 0-.62-.11-.81-.331a1.12 1.12 0 0 1-.144-.85l6.581-30.694c.064-.347.239-.63.525-.85.286-.221.588-.331.906-.331h12.685c3.529 0 6.358.724 8.489 2.172 2.161 1.449 3.242 3.542 3.242 6.281 0 .787-.095 1.605-.286 2.455-.795 3.621-2.4 6.297-4.816 8.028-2.385 1.732-5.66 2.597-9.824 2.597h-6.438l-2.194 10.342a1.35 1.35 0 0 1-.524.85c-.287.221-.588.331-.907.331H68.41Zm16.882-18.039c1.335 0 2.495-.362 3.48-1.086 1.018-.724 1.686-1.763 2.004-3.117a8.185 8.185 0 0 0 .143-1.417c0-.913-.27-1.605-.81-2.077-.541-.504-1.463-.756-2.767-.756H81.62l-1.813 8.453h5.485ZM110.628 461.528c-.349 0-.62-.11-.81-.331-.191-.252-.255-.535-.191-.85l5.293-24.461h-8.488c-.35 0-.62-.11-.811-.33a1.12 1.12 0 0 1-.143-.851l1.097-5.052c.063-.347.238-.63.524-.85.286-.221.588-.331.906-.331h25.657c.35 0 .62.11.811.331.127.189.19.378.19.566a.909.909 0 0 1-.047.284l-1.097 5.052c-.064.347-.239.63-.525.851-.254.22-.556.33-.906.33h-8.441l-5.293 24.461c-.064.346-.239.63-.525.85-.286.221-.588.331-.906.331h-6.295ZM135.88 461.528c-.35 0-.62-.11-.811-.331a1.016 1.016 0 0 1-.191-.85l6.629-30.694a1.35 1.35 0 0 1 .525-.85c.286-.221.588-.331.906-.331h6.438c.349 0 .62.11.81.331.128.189.191.378.191.566a.882.882 0 0 1-.048.284l-6.581 30.694c-.063.346-.238.63-.524.85-.286.221-.588.331-.906.331h-6.438ZM154.038 461.528c-.349 0-.62-.11-.81-.331-.191-.22-.255-.504-.191-.85l6.581-30.694c.064-.347.238-.63.524-.85.287-.221.605-.331.954-.331h5.151c.763 0 1.255.346 1.478 1.039l5.198 14.875 11.588-14.875c.159-.252.382-.488.668-.708.318-.221.7-.331 1.145-.331h5.198c.349 0 .62.11.81.331.127.189.191.378.191.566a.882.882 0 0 1-.048.284l-6.581 30.694c-.063.346-.238.63-.524.85-.286.221-.588.331-.906.331h-5.771c-.349 0-.62-.11-.81-.331a1.118 1.118 0 0 1-.143-.85l3.719-17.425-7.296 9.586c-.318.347-.62.614-.906.803-.286.189-.62.283-1.002.283h-2.479c-.668 0-1.129-.362-1.383-1.086l-3.386-10.011-3.815 17.85c-.064.346-.239.63-.525.85-.286.221-.588.331-.906.331h-5.723ZM196.132 461.528c-.35 0-.62-.11-.81-.331-.191-.252-.255-.535-.191-.85l6.628-30.694a1.35 1.35 0 0 1 .525-.85c.285-.221.588-.331.906-.331h6.438c.35 0 .62.11.811.331.127.189.19.378.19.566a.88.88 0 0 1-.047.284l-6.581 30.694c-.063.346-.238.63-.525.85a1.46 1.46 0 0 1-.907.331h-6.437ZM226.07 462c-2.798 0-5.198-.378-7.201-1.133-1.972-.756-3.466-1.763-4.483-3.022-.986-1.26-1.479-2.661-1.479-4.203 0-.252.033-.63.095-1.134.065-.283.193-.519.383-.708.223-.189.476-.283.763-.283h6.103c.383 0 .668.063.859.188.222.126.445.347.668.662.223.818.731 1.495 1.526 2.03.827.535 1.955.803 3.385.803 1.812 0 3.276-.283 4.388-.85 1.113-.567 1.781-1.338 2.002-2.314a2.42 2.42 0 0 0 .048-.566c0-.788-.491-1.401-1.477-1.842-.986-.473-2.798-1.023-5.437-1.653-3.084-.661-5.421-1.653-7.011-2.975-1.589-1.354-2.383-3.117-2.383-5.289 0-.755.095-1.527.286-2.314.635-2.928 2.21-5.226 4.72-6.894 2.544-1.669 5.818-2.503 9.825-2.503 2.415 0 4.563.425 6.438 1.275 1.875.85 3.321 1.936 4.34 3.258 1.049 1.291 1.572 2.582 1.572 3.873 0 .377-.015.645-.047.802-.063.284-.206.52-.429.709a.975.975 0 0 1-.715.283h-6.391c-.698 0-1.176-.268-1.429-.803-.033-.724-.415-1.338-1.146-1.841-.731-.504-1.685-.756-2.861-.756-1.399 0-2.559.252-3.482.756-.889.503-1.447 1.243-1.668 2.219a3.172 3.172 0 0 0-.049.614c0 .755.445 1.385 1.336 1.889.922.472 2.528.96 4.816 1.464 3.562.692 6.153 1.684 7.774 2.975 1.653 1.29 2.479 3.006 2.479 5.147 0 .724-.095 1.511-.286 2.361-.698 3.211-2.4 5.651-5.103 7.32-2.669 1.636-6.246 2.455-10.729 2.455ZM248.515 461.528c-.35 0-.62-.11-.81-.331-.191-.22-.255-.504-.191-.85l6.581-30.694c.063-.347.238-.63.525-.85.286-.221.604-.331.954-.331h5.149c.763 0 1.256.346 1.479 1.039l5.199 14.875 11.587-14.875c.16-.252.382-.488.668-.708.318-.221.699-.331 1.144-.331h5.199c.35 0 .62.11.811.331.127.189.19.378.19.566a.856.856 0 0 1-.048.284l-6.58 30.694c-.065.346-.24.63-.526.85a1.456 1.456 0 0 1-.906.331h-5.769c-.351 0-.621-.11-.811-.331a1.109 1.109 0 0 1-.143-.85l3.719-17.425-7.296 9.586c-.318.347-.62.614-.906.803a1.776 1.776 0 0 1-1.001.283h-2.481c-.668 0-1.128-.362-1.382-1.086l-3.386-10.011-3.815 17.85a1.36 1.36 0 0 1-.525.85c-.286.221-.588.331-.906.331h-5.723Z"/></g>';

  event LlamaInstanceCreated(
    uint256 indexed id,
    string indexed name,
    address llamaCore,
    address llamaExecutor,
    address llamaPolicy,
    uint256 chainId
  );
  event StrategyLogicAuthorized(ILlamaStrategy indexed relativeQuorumLogic);
  event AccountLogicAuthorized(ILlamaAccount indexed accountLogic);
  event PolicyMetadataSet(LlamaPolicyMetadata indexed llamaPolicyMetadata);
}

contract Constructor is LlamaFactoryTest {
  function deployLlamaFactory() internal returns (LlamaFactory) {
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();

    RoleDescription[] memory roleDescriptionStrings = SolarrayLlama.roleDescription(
      "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
    );
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);
    return new LlamaFactory(
      coreLogic,
      relativeQuorumLogic,
      accountLogic,
      policyLogic,
      policyMetadata,
      "Root Llama",
      strategyConfigs,
      accounts,
      roleDescriptionStrings,
      roleHolders,
      new RolePermissionData[](0)
    );
  }

  function test_SetsLlamaCoreLogicAddress() public {
    assertEq(address(factory.LLAMA_CORE_LOGIC()), address(coreLogic));
  }

  function test_SetsLlamaPolicyLogicAddress() public {
    assertEq(address(factory.LLAMA_POLICY_LOGIC()), address(policyLogic));
  }

  function test_SetsLlamaPolicyMetadataAddress() public {
    assertEq(address(factory.llamaPolicyMetadata()), address(policyMetadata));
  }

  function test_EmitsPolicyTokenURIUpdatedEvent() public {
    vm.expectEmit();
    emit PolicyMetadataSet(policyMetadata);
    deployLlamaFactory();
  }

  function test_SetsLlamaStrategyLogicAddress() public {
    assertTrue(factory.authorizedStrategyLogics(relativeQuorumLogic));
  }

  function test_EmitsStrategyLogicAuthorizedEvent() public {
    vm.expectEmit();
    emit StrategyLogicAuthorized(relativeQuorumLogic);
    deployLlamaFactory();
  }

  function test_SetsLlamaAccountLogicAddress() public {
    assertTrue(factory.authorizedAccountLogics(accountLogic));
  }

  function test_EmitsAccountLogicAuthorizedEvent() public {
    vm.expectEmit();
    emit AccountLogicAuthorized(accountLogic);
    deployLlamaFactory();
  }

  function test_SetsRootLlamaCore() public {
    assertEq(address(factory.ROOT_LLAMA_CORE()), address(rootCore));
  }

  function test_SetsRootLlamaExecutor() public {
    assertEq(address(factory.ROOT_LLAMA_EXECUTOR()), address(rootExecutor));
  }

  function test_DeploysRootLlamaViaInternalDeployMethod() public {
    // The internal `_deploy` method is tested in the `Deploy` contract, so here we just check
    // one side effect of that method as a sanity check it was called. If it was called, the
    // llama count should no longer be zero.
    assertEq(factory.llamaCount(), 2);
  }
}

contract Deploy is LlamaFactoryTest {
  function deployLlama() internal returns (LlamaExecutor, LlamaCore) {
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    RoleDescription[] memory roleDescriptionStrings = SolarrayLlama.roleDescription(
      "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
    );
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);

    vm.prank(address(rootExecutor));
    return factory.deploy(
      "NewProject",
      relativeQuorumLogic,
      accountLogic,
      strategyConfigs,
      accounts,
      roleDescriptionStrings,
      roleHolders,
      new RolePermissionData[](0),
      color,
      logo
    );
  }

  function test_RevertIf_CallerIsNotRootLlama(address caller) public {
    vm.assume(caller != address(rootCore));
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);

    vm.prank(address(caller));
    vm.expectRevert(LlamaFactory.OnlyRootLlama.selector);
    factory.deploy(
      "NewProject",
      relativeQuorumLogic,
      accountLogic,
      strategyConfigs,
      accounts,
      new RoleDescription[](0),
      roleHolders,
      new RolePermissionData[](0),
      color,
      logo
    );
  }

  function test_RevertIf_InstanceDeployedWithSameName(string memory name) public {
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    RoleDescription[] memory roleDescriptionStrings = SolarrayLlama.roleDescription(
      "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
    );
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);

    vm.prank(address(rootExecutor));
    factory.deploy(
      name,
      relativeQuorumLogic,
      accountLogic,
      strategyConfigs,
      accounts,
      roleDescriptionStrings,
      roleHolders,
      new RolePermissionData[](0),
      color,
      logo
    );

    vm.expectRevert();
    factory.deploy(
      name,
      relativeQuorumLogic,
      accountLogic,
      strategyConfigs,
      accounts,
      new RoleDescription[](0),
      roleHolders,
      new RolePermissionData[](0),
      color,
      logo
    );
  }

  function test_RevertIf_RoleId1IsNotFirst() public {
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);
    vm.startPrank(address(rootExecutor));

    // Overwrite role ID at index 1 to ensure it does not have role 1.
    roleHolders[0].role = 2;
    vm.expectRevert(LlamaFactory.InvalidDeployConfiguration.selector);
    factory.deploy(
      "NewProject",
      relativeQuorumLogic,
      accountLogic,
      strategyConfigs,
      accounts,
      new RoleDescription[](0),
      roleHolders,
      new RolePermissionData[](0),
      color,
      logo
    );

    // Pass an empty array of role holders.
    vm.expectRevert(LlamaFactory.InvalidDeployConfiguration.selector);
    factory.deploy(
      "NewProject",
      relativeQuorumLogic,
      accountLogic,
      strategyConfigs,
      accounts,
      new RoleDescription[](0),
      new RoleHolderData[](0),
      new RolePermissionData[](0),
      color,
      logo
    );
  }

  function test_RevertIf_RoleId1IsFirstWithBadExpiration() public {
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);
    vm.startPrank(address(rootExecutor));

    // Overwrite role ID at index 1 to have expiration just below `type(uint64).max`
    roleHolders[0].expiration = type(uint64).max - 1;
    vm.expectRevert(LlamaFactory.InvalidDeployConfiguration.selector);
    factory.deploy(
      "NewProject",
      relativeQuorumLogic,
      accountLogic,
      strategyConfigs,
      accounts,
      new RoleDescription[](0),
      roleHolders,
      new RolePermissionData[](0),
      color,
      logo
    );

    // Overwrite role ID at index 1 to have expiration of `block.timestamp`
    roleHolders[0].expiration = toUint64(block.timestamp);
    vm.expectRevert(LlamaFactory.InvalidDeployConfiguration.selector);
    factory.deploy(
      "NewProject",
      relativeQuorumLogic,
      accountLogic,
      strategyConfigs,
      accounts,
      new RoleDescription[](0),
      roleHolders,
      new RolePermissionData[](0),
      color,
      logo
    );

    // Overwrite role ID at index 1 to have expiration of 0
    roleHolders[0].expiration = 0;
    vm.expectRevert(LlamaFactory.InvalidDeployConfiguration.selector);
    factory.deploy(
      "NewProject",
      relativeQuorumLogic,
      accountLogic,
      strategyConfigs,
      accounts,
      new RoleDescription[](0),
      roleHolders,
      new RolePermissionData[](0),
      color,
      logo
    );
  }

  function test_IncrementsLlamaCountByOne() public {
    uint256 initialLlamaCount = factory.llamaCount();
    deployLlama();
    assertEq(factory.llamaCount(), initialLlamaCount + 1);
  }

  function test_DeploysPolicy() public {
    LlamaPolicy _policy = lens.computeLlamaPolicyAddress("NewProject");
    assertEq(address(_policy).code.length, 0);
    deployLlama();
    assertGt(address(_policy).code.length, 0);
  }

  function test_InitializesLlamaPolicy() public {
    LlamaPolicy _policy = lens.computeLlamaPolicyAddress("NewProject");

    assertEq(address(_policy).code.length, 0);
    deployLlama();
    assertGt(address(_policy).code.length, 0);

    vm.expectRevert("Initializable: contract is already initialized");
    _policy.initialize("Test", new RoleDescription[](0), new RoleHolderData[](0), new RolePermissionData[](0));
  }

  function test_DeploysLlamaCore() public {
    LlamaCore _llama = lens.computeLlamaCoreAddress("NewProject");
    assertEq(address(_llama).code.length, 0);
    deployLlama();
    assertGt(address(_llama).code.length, 0);
    assertGt(address(_llama.policy()).code.length, 0);
    LlamaCore(address(_llama)).name(); // Sanity check that this doesn't revert.
    LlamaCore(address(_llama.policy())).name(); // Sanity check that this doesn't revert.
  }

  function test_InitializesLlamaCore() public {
    (, LlamaCore _llama) = deployLlama();
    assertEq(_llama.name(), "NewProject");

    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();

    LlamaPolicy _policy = _llama.policy();
    vm.expectRevert("Initializable: contract is already initialized");
    _llama.initialize("NewProject", _policy, relativeQuorumLogic, accountLogic, strategyConfigs, accounts);
  }

  function test_SetsLlamaExecutorOnThePolicy() public {
    (, LlamaCore _llama) = deployLlama();
    LlamaPolicy _policy = _llama.policy();
    LlamaCore _llamaFromPolicy = LlamaCore(_policy.llamaExecutor());
    assertEq(address(_llamaFromPolicy), address(_llama.executor()));
  }

  function test_SetsPolicyAddressOnLlamaCore() public {
    LlamaPolicy computedPolicy = lens.computeLlamaPolicyAddress("NewProject");
    (, LlamaCore _llama) = deployLlama();
    assertEq(address(_llama.policy()), address(computedPolicy));
  }

  function test_EmitsLlamaInstanceCreatedEvent() public {
    vm.expectEmit();
    LlamaCore computedLlama = lens.computeLlamaCoreAddress("NewProject");
    LlamaPolicy computedPolicy = lens.computeLlamaPolicyAddress("NewProject");
    LlamaExecutor computedExecutor = lens.computeLlamaExecutorAddress(address(computedLlama));
    emit LlamaInstanceCreated(
      2, "NewProject", address(computedLlama), address(computedExecutor), address(computedPolicy), block.chainid
    );
    deployLlama();
  }

  function test_ReturnsAddressOfTheNewLlamaCoreContract() public {
    LlamaCore computedLlama = lens.computeLlamaCoreAddress("NewProject");
    (, LlamaCore newLlama) = deployLlama();
    assertEq(address(newLlama), address(computedLlama));
  }

  function test_ReturnsAddressOfTheNewLlamaExecutorContract() public {
    LlamaCore computedLlama = lens.computeLlamaCoreAddress("NewProject");
    LlamaExecutor computedExecutor = lens.computeLlamaExecutorAddress(address(computedLlama));
    (LlamaExecutor newLlamaExecutor,) = deployLlama();
    assertEq(address(newLlamaExecutor), address(computedExecutor));
    assertEq(address(computedExecutor), LlamaPolicy(computedLlama.policy()).llamaExecutor());
  }

  function test_SetsColorAndLogoForMpExecutor() public {
    (LlamaExecutor llamaExecutor,) = deployLlama();
    (string memory setColor, string memory setLogo) =
      factory.LLAMA_POLICY_METADATA_PARAM_REGISTRY().getMetadata(llamaExecutor);
    assertEq(setColor, color);
    assertEq(setLogo, logo);
  }
}

contract AuthorizeStrategyLogic is LlamaFactoryTest {
  function testFuzz_RevertIf_CallerIsNotRootLlama(address _caller) public {
    vm.assume(_caller != address(rootExecutor));
    vm.expectRevert(LlamaFactory.OnlyRootLlama.selector);
    vm.prank(_caller);
    factory.authorizeStrategyLogic(ILlamaStrategy(randomLogicAddress));
  }

  function test_SetsValueInStorageMappingToTrue() public {
    assertEq(factory.authorizedStrategyLogics(ILlamaStrategy(randomLogicAddress)), false);
    vm.prank(address(rootExecutor));
    factory.authorizeStrategyLogic(ILlamaStrategy(randomLogicAddress));
    assertEq(factory.authorizedStrategyLogics(ILlamaStrategy(randomLogicAddress)), true);
  }

  function test_EmitsStrategyLogicAuthorizedEvent() public {
    vm.prank(address(rootExecutor));
    vm.expectEmit();
    emit StrategyLogicAuthorized(ILlamaStrategy(randomLogicAddress));
    factory.authorizeStrategyLogic(ILlamaStrategy(randomLogicAddress));
  }
}

contract AuthorizeAccountLogic is LlamaFactoryTest {
  function testFuzz_RevertIf_CallerIsNotRootLlama(address _caller) public {
    vm.assume(_caller != address(rootExecutor));
    vm.expectRevert(LlamaFactory.OnlyRootLlama.selector);
    vm.prank(_caller);
    factory.authorizeAccountLogic(ILlamaAccount(randomLogicAddress));
  }

  function test_SetsValueInStorageMappingToTrue() public {
    assertEq(factory.authorizedAccountLogics(ILlamaAccount(randomLogicAddress)), false);
    vm.prank(address(rootExecutor));
    factory.authorizeAccountLogic(ILlamaAccount(randomLogicAddress));
    assertEq(factory.authorizedAccountLogics(ILlamaAccount(randomLogicAddress)), true);
  }

  function test_EmitsAccountLogicAuthorizedEvent() public {
    vm.prank(address(rootExecutor));
    vm.expectEmit();
    emit AccountLogicAuthorized(ILlamaAccount(randomLogicAddress));
    factory.authorizeAccountLogic(ILlamaAccount(randomLogicAddress));
  }
}

contract SetPolicyTokenMetadata is LlamaFactoryTest {
  function testFuzz_RevertIf_CallerIsNotRootLlama(address _caller, address _policyMetadata) public {
    vm.assume(_caller != address(rootExecutor));
    vm.prank(address(_caller));
    vm.expectRevert(LlamaFactory.OnlyRootLlama.selector);
    factory.setPolicyMetadata(LlamaPolicyMetadata(_policyMetadata));
  }

  function testFuzz_WritesMetadataAddressToStorage(address _policyMetadata) public {
    vm.prank(address(rootExecutor));
    vm.expectEmit();
    emit PolicyMetadataSet(LlamaPolicyMetadata(_policyMetadata));
    factory.setPolicyMetadata(LlamaPolicyMetadata(_policyMetadata));
    assertEq(address(factory.llamaPolicyMetadata()), _policyMetadata);
  }
}

contract TokenURI is LlamaFactoryTest {
  function setTokenURIMetadata() internal {
    string memory color = "#FF0000";
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.startPrank(address(rootExecutor));
    policyMetadataParamRegistry.setColor(mpExecutor, color);
    policyMetadataParamRegistry.setLogo(mpExecutor, logo);
    vm.stopPrank();
  }

  function testFuzz_ProxiesToMetadataContract(uint256 _tokenId) public {
    setTokenURIMetadata();

    (string memory _color, string memory _logo) = policyMetadataParamRegistry.getMetadata(mpExecutor);
    assertEq(
      factory.tokenURI(mpExecutor, mpPolicy.name(), _tokenId),
      policyMetadata.tokenURI(mpPolicy.name(), _tokenId, _color, _logo)
    );
  }
}
