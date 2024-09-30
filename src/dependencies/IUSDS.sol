// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

interface IUSDS {
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  function PERMIT_TYPEHASH() external view returns (bytes32);

  function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

  function allowance(
    address owner,
    address spender
  ) external view returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);

  function asset() external view returns (address);

  function balanceOf(address account) external view returns (uint256);

  function chi() external view returns (uint192);

  function convertToAssets(uint256 shares) external view returns (uint256);

  function convertToShares(uint256 assets) external view returns (uint256);

  function decimals() external view returns (uint8);

  function deny(address usr) external;

  function deposit(uint256 assets, address receiver) external returns (uint256);

  function deposit(
    uint256 assets,
    address receiver,
    uint16 referral
  ) external returns (uint256);

  function drip() external returns (uint256);

  function file(bytes32 what, uint256 data) external;

  function getImplementation() external view returns (address);

  function initialize() external;

  function maxDeposit(address account) external view returns (uint256);

  function maxMint(address account) external view returns (uint256);

  function maxRedeem(address owner) external view returns (uint256);

  function maxWithdraw(address owner) external view returns (uint256);

  function mint(
    uint256 shares,
    address receiver,
    uint16 referral
  ) external returns (uint256);

  function mint(uint256 shares, address receiver) external returns (uint256);

  function name() external view returns (string memory);

  function nonces(address account) external view returns (uint256);

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    bytes memory signature
  ) external;

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function previewDeposit(uint256 assets) external view returns (uint256);

  function previewMint(uint256 shares) external view returns (uint256);

  function previewRedeem(uint256 shares) external view returns (uint256);

  function previewWithdraw(uint256 assets) external view returns (uint256);

  function proxiableUUID() external view returns (bytes32);

  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) external returns (uint256);

  function rely(address usr) external;

  function rho() external view returns (uint64);

  function ssr() external view returns (uint256);

  function symbol() external view returns (string memory);

  function totalAssets() external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function transfer(address to, uint256 value) external returns (bool);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool);

  function upgradeToAndCall(
    address newImplementation,
    bytes memory data
  ) external payable;

  function usds() external view returns (address);

  function usdsJoin() external view returns (address);

  function vat() external view returns (address);

  function version() external view returns (string memory);

  function vow() external view returns (address);

  function wards(address account) external view returns (uint256);

  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) external returns (uint256);
}
