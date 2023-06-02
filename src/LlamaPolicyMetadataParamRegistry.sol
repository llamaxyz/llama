// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaExecutor} from "src/LlamaExecutor.sol";

/// @title Llama Policy Metadata Parameter Registry
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Parameter Registry contract for onchain SVG colors and logos.
contract LlamaPolicyMetadataParamRegistry {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  /// @dev Only callable by a Llama instance's executor, the root Llama instance's executor or the Llama factory.
  error UnauthorizedCaller();

  /// @dev Only the Llama instance, the root Llama instance, or the Llama factory can update an instance's color and
  /// logo.
  modifier onlyAuthorized(LlamaExecutor llamaExecutor) {
    if (
      msg.sender != address(llamaExecutor) && msg.sender != address(ROOT_LLAMA_EXECUTOR) && msg.sender != LLAMA_FACTORY
    ) revert UnauthorizedCaller();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  /// @dev Emitted when the color code for SVG of a Llama instance is set.
  event ColorSet(LlamaExecutor indexed llamaExecutor, string color);

  /// @dev Emitted when the logo for SVG of a Llama instance is set.
  event LogoSet(LlamaExecutor indexed llamaExecutor, string logo);

  // ==================================================
  // ======== Immutables and Storage Variables ========
  // ==================================================

  /// @notice The Root Llama instance's executor.
  LlamaExecutor public immutable ROOT_LLAMA_EXECUTOR;

  /// @notice The Llama factory.
  address public immutable LLAMA_FACTORY;

  /// @notice Mapping of Llama instance to color code for SVG.
  mapping(LlamaExecutor => string) public color;

  /// @notice Mapping of Llama instance to logo for SVG.
  mapping(LlamaExecutor => string) public logo;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  /// @notice This contract is deployed in the Llama factory's constructor.
  constructor(LlamaExecutor rootLlamaExecutor) {
    ROOT_LLAMA_EXECUTOR = rootLlamaExecutor;
    LLAMA_FACTORY = msg.sender;

    string memory rootColor = "#6A45EC";
    string memory rootLogo =
      '<g><path fill="#fff" d="M91.749 446.038H85.15v2.785h2.54v14.483h-3.272v2.785h9.746v-2.785h-2.416v-17.268ZM104.122 446.038h-6.598v2.785h2.54v14.483h-3.271v2.785h9.745v-2.785h-2.416v-17.268ZM113.237 456.162c.138-1.435 1.118-2.2 2.885-2.2 1.767 0 2.651.765 2.651 2.423v.403l-4.859.599c-2.885.362-5.149 1.63-5.149 4.484 0 2.841 2.14 4.47 5.383 4.47 2.72 0 3.921-1.044 4.487-1.935h.276v1.685h3.782v-9.135c0-3.983-2.54-5.78-6.488-5.78-3.975 0-6.404 1.797-6.694 4.568v.418h3.726Zm-.483 5.528c0-1.1.829-1.629 2.03-1.796l3.989-.529v.626c0 2.354-1.546 3.537-3.672 3.537-1.491 0-2.347-.724-2.347-1.838ZM125.765 466.091h3.727v-9.386c0-1.796.938-2.576 2.25-2.576 1.173 0 1.753.682 1.753 1.838v10.124h3.727v-9.386c0-1.796.939-2.576 2.236-2.576 1.187 0 1.753.682 1.753 1.838v10.124h3.741v-10.639c0-2.646-1.657-4.22-4.183-4.22-2.264 0-3.312.989-3.92 2.075h-.276c-.414-.947-1.436-2.075-3.534-2.075-2.056 0-2.954.864-3.45 1.741h-.277v-1.462h-3.547v14.58ZM151.545 456.162c.138-1.435 1.118-2.2 2.885-2.2 1.767 0 2.65.765 2.65 2.423v.403l-4.859.599c-2.885.362-5.149 1.63-5.149 4.484 0 2.841 2.14 4.47 5.384 4.47 2.719 0 3.92-1.044 4.486-1.935h.276v1.685H161v-9.135c0-3.983-2.54-5.78-6.488-5.78-3.975 0-6.404 1.797-6.694 4.568v.418h3.727Zm-.484 5.528c0-1.1.829-1.629 2.03-1.796l3.989-.529v.626c0 2.354-1.546 3.537-3.672 3.537-1.491 0-2.347-.724-2.347-1.838Z"/><g fill="#6A45EC"><path d="M36.736 456.934c.004-.338.137-.661.372-.901.234-.241.552-.38.886-.389h16.748a5.961 5.961 0 0 0 2.305-.458 6.036 6.036 0 0 0 3.263-3.287c.303-.737.46-1.528.46-2.326V428h-4.738v21.573c-.004.337-.137.66-.372.901-.234.24-.552.379-.886.388H38.01a5.984 5.984 0 0 0-4.248 1.781A6.108 6.108 0 0 0 32 456.934v14.891h4.736v-14.891ZM62.868 432.111h-.21l.2.204v4.448h4.36l2.043 2.084a6.008 6.008 0 0 0-3.456 2.109 6.12 6.12 0 0 0-1.358 3.841v27.034h4.717v-27.04c.005-.341.14-.666.38-.907.237-.24.56-.378.897-.383h.726c2.783 0 3.727-1.566 4.006-2.224.28-.658.711-2.453-1.257-4.448l-4.617-4.702h-1.437M50.34 469.477a7.728 7.728 0 0 1 3.013.61c.955.403 1.82.994 2.547 1.738h5.732a12.645 12.645 0 0 0-4.634-5.201 12.467 12.467 0 0 0-6.658-1.93c-2.355 0-4.662.669-6.659 1.93a12.644 12.644 0 0 0-4.634 5.201h5.733a7.799 7.799 0 0 1 2.546-1.738 7.728 7.728 0 0 1 3.014-.61Z"/></g></g>';
    setColor(ROOT_LLAMA_EXECUTOR, rootColor);
    setLogo(ROOT_LLAMA_EXECUTOR, rootLogo);
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Gets the color code and logo for SVG of a Llama instance.
  /// @param llamaExecutor The Llama instance's executor.
  function getMetadata(LlamaExecutor llamaExecutor) external view returns (string memory _color, string memory _logo) {
    _color = color[llamaExecutor];
    _logo = logo[llamaExecutor];
  }

  /// @notice Sets the color code for SVG of a Llama instance.
  /// @param llamaExecutor The Llama instance's executor.
  /// @param _color The color code as a hex value (eg. #00FF00)
  function setColor(LlamaExecutor llamaExecutor, string memory _color) public onlyAuthorized(llamaExecutor) {
    color[llamaExecutor] = _color;
    emit ColorSet(llamaExecutor, _color);
  }

  /// @notice Sets the logo for SVG of a Llama instance.
  /// @param llamaExecutor The Llama instance's executor.
  /// @param _logo The logo.
  function setLogo(LlamaExecutor llamaExecutor, string memory _logo) public onlyAuthorized(llamaExecutor) {
    logo[llamaExecutor] = _logo;
    emit LogoSet(llamaExecutor, _logo);
  }
}
