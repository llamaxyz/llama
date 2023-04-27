// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Base64} from "@openzeppelin/utils/Base64.sol";

import {LibString} from "@solady/utils/LibString.sol";

/// @title Llama Policy Metadata
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Utility contract to compute llama policy metadata.
contract LlamaPolicyMetadata {
  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Returns the token URI for a given llama policyholder.
  /// @param name The name of the llama instance.
  /// @param symbol The symbol of the llama instance.
  /// @param tokenId The token ID of the llama policyholder.
  /// @param color The color of the llama instance.
  /// @param logo The logo of the llama instance.
  function tokenURI(string memory name, string memory symbol, uint256 tokenId, string memory color, string memory logo)
    external
    pure
    returns (string memory)
  {
    string[13] memory parts;
    string memory policyholder = LibString.toHexString(tokenId);

    parts[0] =
      '<svg xmlns="http://www.w3.org/2000/svg" width="390" height="500" fill="none"><g clip-path="url(#a)"><rect width="390" height="500" fill="#0B101A" rx="13.393" /><mask id="b" width="364" height="305" x="4" y="30" maskUnits="userSpaceOnUse" style="mask-type:alpha"><ellipse cx="186.475" cy="182.744" fill="#8000FF" rx="196.994" ry="131.329" transform="rotate(-31.49 186.475 182.744)" /></mask><g mask="url(#b)"><g filter="url(#c)"><ellipse cx="237.625" cy="248.968" fill="#6A45EC" rx="140.048" ry="59.062" transform="rotate(-31.49 237.625 248.968)" /></g><g filter="url(#d)"><ellipse cx="286.655" cy="297.122" fill="';

    parts[1] = color;

    parts[2] =
      '" rx="140.048" ry="59.062" transform="rotate(-31.49 286.655 297.122)" /></g></g><g filter="url(#e)"><ellipse cx="237.625" cy="248.969" fill="';

    parts[3] = color;

    parts[4] =
      '" rx="140.048" ry="59.062" transform="rotate(-31.49 237.625 248.969)" /></g><circle cx="109.839" cy="147.893" r="22" fill="url(#f)" /><rect width="150" height="35.071" x="32" y="376.875" fill="';

    parts[5] = color;

    parts[6] =
      '" rx="17.536"/><text fill="#0B101A" font-family="ui-monospace,Cascadia Mono,Menlo,Monaco,Segoe UI Mono,Roboto Mono,Oxygen Mono,Ubuntu Monospace,Source Code Pro,Droid Sans Mono,Fira Mono,Courier,monospace" font-size="16"><tspan x="45.393" y="399.851">';

    parts[7] =
      string(abi.encodePacked(LibString.slice(policyholder, 0, 6), "...", LibString.slice(policyholder, 38, 42)));

    parts[8] =
      '</tspan></text><path fill="#fff" d="M341 127.067a11.433 11.433 0 0 0 8.066-8.067 11.436 11.436 0 0 0 8.067 8.067 11.433 11.433 0 0 0-8.067 8.066 11.43 11.43 0 0 0-8.066-8.066Z" /><path stroke="#fff" stroke-width="1.5" d="M349.036 248.018V140.875" /><circle cx="349.036" cy="259.178" r="4.018" fill="#fff" /><path stroke="#fff" stroke-width="1.5" d="M349.036 292.214v-21.429" /><path fill="#fff" d="M343.364 33.506a1.364 1.364 0 0 0-2.728 0V43.85l-7.314-7.314a1.364 1.364 0 0 0-1.929 1.928l7.315 7.315h-10.344a1.364 1.364 0 0 0 0 2.727h10.344l-7.315 7.315a1.365 1.365 0 0 0 1.929 1.928l7.314-7.314v10.344a1.364 1.364 0 0 0 2.728 0V50.435l7.314 7.314a1.364 1.364 0 0 0 1.929-1.928l-7.315-7.315h10.344a1.364 1.364 0 1 0 0-2.727h-10.344l7.315-7.315a1.365 1.365 0 0 0-1.929-1.928l-7.314 7.314V33.506ZM73.81 44.512h-4.616v1.932h1.777v10.045h-2.29v1.932h6.82V56.49h-1.69V44.512ZM82.469 44.512h-4.617v1.932h1.777v10.045h-2.29v1.932h6.82V56.49h-1.69V44.512ZM88.847 51.534c.097-.995.783-1.526 2.02-1.526 1.236 0 1.854.531 1.854 1.68v.28l-3.4.416c-2.02.251-3.603 1.13-3.603 3.11 0 1.971 1.497 3.101 3.767 3.101 1.903 0 2.743-.724 3.14-1.343h.192v1.17h2.647v-6.337c0-2.763-1.777-4.009-4.54-4.009-2.782 0-4.482 1.246-4.685 3.168v.29h2.608Zm-.338 3.835c0-.763.58-1.13 1.42-1.246l2.792-.367v.435c0 1.632-1.082 2.453-2.57 2.453-1.043 0-1.642-.502-1.642-1.275ZM97.614 58.42h2.608v-6.51c0-1.246.657-1.787 1.575-1.787.821 0 1.226.474 1.226 1.275v7.023h2.609v-6.51c0-1.247.656-1.788 1.564-1.788.831 0 1.227.474 1.227 1.275v7.023h2.618v-7.38c0-1.835-1.159-2.927-2.927-2.927-1.584 0-2.318.686-2.743 1.44h-.194c-.289-.657-1.004-1.44-2.472-1.44-1.44 0-2.067.6-2.415 1.208h-.193v-1.015h-2.483v10.114ZM115.654 51.534c.097-.995.782-1.526 2.019-1.526 1.236 0 1.854.531 1.854 1.68v.28l-3.4.416c-2.019.251-3.603 1.13-3.603 3.11 0 1.971 1.498 3.101 3.767 3.101 1.903 0 2.744-.724 3.14-1.343h.193v1.17h2.647v-6.337c0-2.763-1.778-4.009-4.54-4.009-2.782 0-4.482 1.246-4.685 3.168v.29h2.608Zm-.338 3.835c0-.763.58-1.13 1.42-1.246l2.791-.367v.435c0 1.632-1.081 2.453-2.569 2.453-1.043 0-1.642-.502-1.642-1.275ZM35.314 52.07a.906.906 0 0 1 .88-.895h11.72a4.205 4.205 0 0 0 3.896-2.597 4.22 4.22 0 0 0 .323-1.614V32h-3.316v14.964a.907.907 0 0 1-.88.894H36.205a4.206 4.206 0 0 0-2.972 1.235A4.219 4.219 0 0 0 32 52.07v10.329h3.314v-10.33ZM53.6 34.852h-.147l.141.14v3.086h3.05l1.43 1.446a4.211 4.211 0 0 0-3.369 4.127v18.752h3.301V43.647a.91.91 0 0 1 .894-.895h.508c1.947 0 2.608-1.086 2.803-1.543.196-.456.498-1.7-.88-3.085l-3.23-3.261h-1.006" /><path fill="#fff" d="M44.834 60.77a5.45 5.45 0 0 1 3.89 1.629h4.012a8.8 8.8 0 0 0-3.243-3.608 8.781 8.781 0 0 0-12.562 3.608h4.012a5.457 5.457 0 0 1 3.89-1.629Z" />';

    parts[9] = logo;

    parts[10] =
      '</g><defs><filter id="c" width="514.606" height="445.5" x="-19.678" y="26.218" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"><feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_236_2" stdDeviation="66.964" /></filter><filter id="d" width="514.606" height="445.5" x="29.352" y="74.373" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"><feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_236_2" stdDeviation="66.964" /></filter><filter id="e" width="514.606" height="445.5" x="-19.678" y="26.219" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"><feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_236_2" stdDeviation="66.964" /></filter><radialGradient id="f" cx="0" cy="0" r="1" gradientTransform="matrix(23.59563 32 -33.15047 24.44394 98.506 137.893)" gradientUnits="userSpaceOnUse"><stop stop-color="#0B101A" /><stop offset=".609" stop-color="';

    parts[11] = color;

    parts[12] =
      '" /><stop offset="1" stop-color="#fff" /></radialGradient><clipPath id="a"><rect width="390" height="500" fill="#fff" rx="13.393" /></clipPath></defs></svg>';

    string memory output1 =
      string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));
    string memory output2 = string(abi.encodePacked(parts[9], parts[10], parts[11], parts[12]));
    string memory output = LibString.concat(output1, output2);

    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "Llama Policy ID: ',
            LibString.toString(tokenId),
            " - ",
            symbol,
            '", "description": "This policy represents membership in the Llama organization: ',
            name,
            '. Visit https://app.llama.xyz to learn more.", "external_url": "https://app.llama.xyz", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(output)),
            '"}'
          )
        )
      )
    );
    output = string(abi.encodePacked("data:application/json;base64,", json));

    return output;
  }

  function contractURI(string memory name) public pure returns (string memory) {
    string[5] memory parts;
    parts[0] = '{ "name": "Llama Policies: ';
    parts[1] = name;
    parts[2] = '", "description": "This collection represents memberships in the Llama organization: ';
    parts[3] = name;
    parts[4] =
      '. Visit https://app.llama.xyz to learn more.", "image":"https://app.llama.xyz/policy-nft/policy.png", "external_link": "https://app.llama.xyz", "banner":"https://app.llama.xyz/policy-nft/banner.png" }';
    string memory json =
      Base64.encode(bytes(string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4]))));
    return string(abi.encodePacked("data:application/json;base64,", json));
  }
}
