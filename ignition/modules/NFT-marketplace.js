// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("AssetsModule", (m) => {
  // Fetch the parameters needed for the contract deployment
  const tokenAddress = m.getParameter("token", "");
  const wethAddress = m.getParameter("weth", "");

  // Deploy the Assets contract with the required parameters (ERC20 token and WETH contract addresses)
  const assets = m.contract("Assets", [tokenAddress, wethAddress]);

  return { assets };
});