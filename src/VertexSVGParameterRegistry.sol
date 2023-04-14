// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VertexCore} from "src/VertexCore.sol";

/// @title Vertex SVG Parameter Registry
/// @author Llama (vertex@llama.xyz)
/// @notice Paramter Registry contract for Onchain SVGs.
contract VertexSVGParameterRegistry {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error OnlyVertex();

  modifier onlyRootVertex() {
    if (msg.sender != address(ROOT_VERTEX)) revert OnlyVertex();
    _;
  }

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice The Root Vertex Instance.
  VertexCore public immutable ROOT_VERTEX;

  /// @notice Mapping of Vertex Instance to color code for SVG.
  mapping(VertexCore => string) public color;

  /// @notice Mapping of Vertex Instance to logo for SVG.
  mapping(VertexCore => string) public logo;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor(VertexCore rootVertexCore) {
    ROOT_VERTEX = rootVertexCore;
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Sets the color code for SVG of a Vertex Instance.
  /// @param vertexCore The Vertex Instance.
  /// @param _color The color code.
  function setColor(VertexCore vertexCore, string memory _color) external onlyRootVertex {
    color[vertexCore] = _color;
  }

  /// @notice Sets the logo for SVG of a Vertex Instance.
  /// @param vertexCore The Vertex Instance.
  /// @param _logo The logo.
  function setLogo(VertexCore vertexCore, string memory _logo) external onlyRootVertex {
    logo[vertexCore] = _logo;
  }
}
