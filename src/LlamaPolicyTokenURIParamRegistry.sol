// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaCore} from "src/LlamaCore.sol";

/// @title Llama Policy Token URI Parameter Registry
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Parameter Registry contract for onchain image formats.
contract LlamaPolicyTokenURIParamRegistry {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error OnlyLlama();

  modifier onlyLlama(LlamaCore llamaCore) {
    if ((msg.sender != address(ROOT_LLAMA)) && (msg.sender != address(llamaCore))) revert OnlyLlama();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  event ColorSet(LlamaCore indexed llamaCore, string color);
  event LogoSet(LlamaCore indexed llamaCore, string logo);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice The Root Llama Instance.
  LlamaCore public immutable ROOT_LLAMA;

  /// @notice Mapping of Llama Instance to color code for SVG.
  mapping(LlamaCore => string) public color;

  /// @notice Mapping of Llama Instance to logo for SVG.
  mapping(LlamaCore => string) public logo;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor(LlamaCore rootLlamaCore) {
    ROOT_LLAMA = rootLlamaCore;
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  function getMetadata(LlamaCore llamaCore) external view returns (string memory _color, string memory _logo) {
    _color = color[llamaCore];
    _logo = logo[llamaCore];
  }

  /// @notice Sets the color code for SVG of a Llama Instance.
  /// @param llamaCore The Llama Instance.
  /// @param _color The color code.
  function setColor(LlamaCore llamaCore, string memory _color) external onlyLlama(llamaCore) {
    color[llamaCore] = _color;
    emit ColorSet(llamaCore, _color);
  }

  /// @notice Sets the logo for SVG of a Llama Instance.
  /// @param llamaCore The Llama Instance.
  /// @param _logo The logo.
  function setLogo(LlamaCore llamaCore, string memory _logo) external onlyLlama(llamaCore) {
    logo[llamaCore] = _logo;
    emit LogoSet(llamaCore, _logo);
  }
}
