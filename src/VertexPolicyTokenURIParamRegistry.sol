// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VertexCore} from "src/VertexCore.sol";

/// @title Vertex Policy Token URI Parameter Registry
/// @author Llama (vertex@llama.xyz)
/// @notice Parameter Registry contract for onchain image formats.
contract VertexPolicyTokenURIParamRegistry {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error OnlyVertex();

  modifier onlyVertex(VertexCore vertexCore) {
    if ((msg.sender != address(ROOT_VERTEX)) && (msg.sender != address(vertexCore))) revert OnlyVertex();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  event ColorSet(VertexCore indexed vertexCore, string color);
  event LogoSet(VertexCore indexed vertexCore, string logo);

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

  function getMetadata(VertexCore vertexCore) external view returns (string memory _color, string memory _logo) {
    _color = color[vertexCore];
    _logo = logo[vertexCore];
  }

  /// @notice Sets the color code for SVG of a Vertex Instance.
  /// @param vertexCore The Vertex Instance.
  /// @param _color The color code.
  function setColor(VertexCore vertexCore, string memory _color) external onlyVertex(vertexCore) {
    color[vertexCore] = _color;
    emit ColorSet(vertexCore, _color);
  }

  /// @notice Sets the logo for SVG of a Vertex Instance.
  /// @param vertexCore The Vertex Instance.
  /// @param _logo The logo.
  function setLogo(VertexCore vertexCore, string memory _logo) external onlyVertex(vertexCore) {
    logo[vertexCore] = _logo;
    emit LogoSet(vertexCore, _logo);
  }
}
