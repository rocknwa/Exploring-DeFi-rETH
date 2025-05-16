// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Change theses parameters
address constant PROXY = 0xC5aCD8c4604476FEFfd4bEb164a22f70ed56884D;
address constant FLASH_LEV = 0xDcc6Dc8D59626E4E851c6b76df178Ab0C390bAF8;
uint256 constant RETH_AMOUNT = 0.1 * 1e18;
uint256 constant DAI_AMOUNT = 100 * 1e18;
// MAX_LEV = leverage + 1
// 10000 = 1
uint256 constant MAX_LEV = 1 * 10000;
// Minimum health factor
uint256 constant MIN_HF = 1.1 * 1e18;
