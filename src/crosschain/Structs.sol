// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

struct Action {
  address target;
  bytes data;
  bytes4 selector;
}
