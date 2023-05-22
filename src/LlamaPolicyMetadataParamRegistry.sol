// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaExecutor} from "src/LlamaExecutor.sol";

/// @title Llama Policy Token Metadata Parameter Registry
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Parameter Registry contract for onchain SVG colors and logos.
contract LlamaPolicyMetadataParamRegistry {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error OnlyLlamaRootOrFactory();

  modifier onlyLlamaRootOrFactory(LlamaExecutor llamaExecutor) {
    if (
      msg.sender != address(ROOT_LLAMA_EXECUTOR) && msg.sender != address(llamaExecutor) && msg.sender != LLAMA_FACTORY
    ) revert OnlyLlamaRootOrFactory();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  event ColorSet(LlamaExecutor indexed llamaExecutor, string color);
  event LogoSet(LlamaExecutor indexed llamaExecutor, string logo);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice The Root Llama Instance.
  LlamaExecutor public immutable ROOT_LLAMA_EXECUTOR;

  /// @notice The Root Llama Instance.
  address public immutable LLAMA_FACTORY;

  /// @notice Mapping of Llama Instance to color code for SVG.
  mapping(LlamaExecutor => string) public color;

  /// @notice Mapping of Llama Instance to logo for SVG.
  mapping(LlamaExecutor => string) public logo;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor(LlamaExecutor rootLlamaExecutor) {
    ROOT_LLAMA_EXECUTOR = rootLlamaExecutor;
    LLAMA_FACTORY = msg.sender;
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  function getMetadata(LlamaExecutor llamaExecutor) external view returns (string memory _color, string memory _logo) {
    _color = color[llamaExecutor];
    _logo = logo[llamaExecutor];
  }

  /// @notice Sets the color code for SVG of a Llama Instance.
  /// @param llamaExecutor The Llama Instance.
  /// @param _color The color code as a hex value (eg. #00FF00)
  function setColor(LlamaExecutor llamaExecutor, string memory _color) external onlyLlamaRootOrFactory(llamaExecutor) {
    color[llamaExecutor] = _color;
    emit ColorSet(llamaExecutor, _color);
  }

  /// @notice Sets the logo for SVG of a Llama Instance.
  /// @param llamaExecutor The Llama Instance.
  /// @param _logo The logo.
  function setLogo(LlamaExecutor llamaExecutor, string memory _logo) external onlyLlamaRootOrFactory(llamaExecutor) {
    logo[llamaExecutor] = _logo;
    emit LogoSet(llamaExecutor, _logo);
  }
}
