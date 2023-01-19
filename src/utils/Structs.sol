// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

///@dev Struct to define a permission
struct Permission {
    address target;
    bytes4 signature;
    address executor;
}
