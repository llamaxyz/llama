// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Base64} from "@openzeppelin/utils/Base64.sol";

import {LibString} from "@solady/utils/LibString.sol";

/// @title Vertex Policy Metadata
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Utility contract to compute Vertex Policy metadata.
contract VertexPolicyTokenURI {
  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Returns the token URI for a given Vertex Policy Holder.
  /// @param name The name of the Vertex system.
  /// @param symbol The symbol of the Vertex system.
  /// @param tokenId The token ID of the Vertex Policy Holder.
  /// @param color The color of the Vertex system
  /// @param logo The logo of the Vertex system
  function tokenURI(string memory name, string memory symbol, uint256 tokenId, string memory color, string memory logo)
    external
    pure
    returns (string memory)
  {
    string[17] memory parts;
    string memory policyholder = LibString.toHexString(tokenId);

    parts[0] =
      '<svg xmlns="http://www.w3.org/2000/svg" width="390" height="500" fill="none"><g clip-path="url(#a)"><rect width="390" height="500" fill="#0B101A" rx="13.393" /><mask id="b" width="364" height="305" x="4" y="30" maskUnits="userSpaceOnUse" style="mask-type:alpha"><ellipse cx="186.475" cy="182.744" fill="#8000FF" rx="196.994" ry="131.329" transform="rotate(-31.49 186.475 182.744)" /></mask><g mask="url(#b)"><g filter="url(#c)"><ellipse cx="237.625" cy="248.968" fill="#6A45EC" rx="140.048" ry="59.062" transform="rotate(-31.49 237.625 248.968)" /></g><g filter="url(#d)"><ellipse cx="286.654" cy="297.122" fill="';

    parts[1] = color;

    parts[2] =
      '" rx="140.048" ry="59.062" transform="rotate(-31.49 286.654 297.122)" /></g> </g> <g filter="url(#e)"> <ellipse cx="237.625" cy="248.968" fill="';

    parts[3] = color;

    parts[4] =
      '" rx="140.048" ry="59.062" transform="rotate(-31.49 237.625 248.968)" /></g><circle cx="109.839" cy="147.893" r="22" fill="url(#f)" /><path fill="#fff" d="M342.455 33.597a1.455 1.455 0 0 0-2.91 0v11.034l-7.802-7.802a1.454 1.454 0 1 0-2.057 2.057l7.802 7.802h-11.033a1.454 1.454 0 1 0 0 2.91h11.033l-7.802 7.802a1.455 1.455 0 0 0 2.057 2.057l7.802-7.803v11.034a1.455 1.455 0 0 0 2.91 0V51.654l7.802 7.803a1.455 1.455 0 0 0 2.057-2.057l-7.802-7.803h11.033a1.454 1.454 0 1 0 0-2.909h-11.033l7.802-7.802a1.455 1.455 0 0 0-2.057-2.057l-7.802 7.802V33.597Z"/><text fill="#fff" font-family="\'Courier New\', monospace" font-size="38"><tspan x="32" y="459.581">';

    parts[5] = name;

    parts[6] = "</tspan></text>";

    parts[7] = logo;

    parts[8] = '<rect width="150" height="35.071" x="32" y="376.875" fill="';

    parts[9] = color;

    parts[10] =
      '" rx="17.536"/><text fill="#0B101A" font-family="\'Courier New\', monospace" font-size="16"><tspan x="45.393" y="399.851">';

    parts[11] =
      string(abi.encodePacked(LibString.slice(policyholder, 0, 6), "...", LibString.slice(policyholder, 38, 42)));

    parts[12] = '</tspan></text><path fill="';

    parts[13] = color;

    parts[14] =
      '" d="M36.08 53.84h1.696l3.52-10.88h-1.632l-2.704 9.087h-.064l-2.704-9.088H32.56l3.52 10.88Zm7.891 0h7.216v-1.36h-5.696v-3.505h4.96v-1.36h-4.96V44.32h5.696v-1.36h-7.216v10.88Zm13.609-4.593 2.544 4.592h1.744L59.18 49.2c.848-.096 1.392-.4 1.808-.816.56-.56.784-1.344.784-2.304 0-1.008-.24-1.808-.816-2.336-.576-.528-1.472-.784-2.592-.784h-4.096v10.88h1.52v-4.592h1.792Zm-1.792-1.296V44.32h3.136c.768 0 1.248.448 1.248 1.184v1.2c0 .672-.448 1.248-1.248 1.248h-3.136Zm7.78-3.632h3.249v9.52h1.52v-9.52h3.248v-1.36h-8.016v1.36Zm10.464 9.52h7.216v-1.36h-5.696v-3.504h4.96v-1.36h-4.96V44.32h5.696v-1.36h-7.216v10.88Zm9.192 0h1.68l2.592-4.256 2.56 4.256h1.696l-3.44-5.584 3.312-5.296H89.96l-2.464 4.016-2.416-4.016h-1.664l3.28 5.296-3.472 5.584Z"/><path fill="#fff" d="M341 127.067a11.433 11.433 0 0 0 8.066-8.067 11.436 11.436 0 0 0 8.067 8.067 11.433 11.433 0 0 0-8.067 8.066 11.43 11.43 0 0 0-8.066-8.066Z" /><path stroke="#fff" stroke-width="1.5" d="M349.036 248.018V140.875" /><circle cx="349.036" cy="259.178" r="4.018" fill="#fff" /><path stroke="#fff" stroke-width="1.5" d="M349.036 292.214v-21.429" /></g><filter id="c" width="514.606" height="445.5" x="-19.678" y="26.218" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"> <feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_123_5" stdDeviation="66.964" /></filter><filter id="d" width="514.606" height="445.5" x="29.352" y="74.373" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"> <feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_123_5" stdDeviation="66.964" /></filter><filter id="e" width="514.606" height="445.5" x="-19.678" y="26.219" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"> <feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_123_5" stdDeviation="66.964" /></filter><radialGradient id="f" cx="0" cy="0" r="1" gradientTransform="matrix(23.59563 32 -33.15047 24.44394 98.506 137.893)" gradientUnits="userSpaceOnUse"> <stop stop-color="#0B101A" /><stop offset=".609" stop-color="';

    parts[15] = color;

    parts[16] =
      '" /><stop offset="1" stop-color="#fff" /></radialGradient><clipPath id="a"><rect width="390" height="500" fill="#fff" rx="13.393" /></clipPath></svg>';

    string memory output1 =
      string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));
    string memory output2 =
      string(abi.encodePacked(parts[9], parts[10], parts[11], parts[12], parts[13], parts[14], parts[15], parts[16]));
    string memory output = LibString.concat(output1, output2);

    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "Vertex Policy ID: ',
            LibString.toString(tokenId),
            " - ",
            symbol,
            '", "description": "Vertex is a framework for onchain organizations.", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(output)),
            '"}'
          )
        )
      )
    );
    output = string(abi.encodePacked("data:application/json;base64,", json));

    return output;
  }
}
