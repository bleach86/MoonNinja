const { expect } = require("chai");
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy the logic contract for MoonNinjaToken (no constructor arguments here)
  const MoonNinjaToken = await ethers.getContractFactory("MoonNinjaToken");
  const moonNinjaToken = await MoonNinjaToken.deploy();

  const wethAddress = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"; // Mainnet WETH address

  await moonNinjaToken.waitForDeployment();
  console.log("MoonNinjaToken logic deployed to:", moonNinjaToken.target);

  const MNLiquidityManager = await ethers.getContractFactory(
    "MNLiquidityManager"
  );
  const mnLiquidityManager = await MNLiquidityManager.deploy();

  // Deploy the MoonNinja factory contract
  const MoonNinja = await ethers.getContractFactory("MoonNinja");
  const moonNinja = await MoonNinja.deploy(
    moonNinjaToken.target,
    wethAddress,
    mnLiquidityManager.target
  );
  console.log("MoonNinja factory deployed to:", moonNinja.target);
}

// Start the deployment process
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
