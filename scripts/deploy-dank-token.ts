import { ethers, run, network } from "hardhat";
import { DANK_TOKEN_CONFIG } from "../deploy/config";

async function main() {
  try {
    console.log(`Deploying DankToken to ${network.name}...`);
    
    // Get the Ledger signer
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying with Ledger account: ${deployer.address}`);

    // Deploy the contract
    const DankToken = await ethers.getContractFactory("DankToken");
    const dankToken = await DankToken.deploy(
      DANK_TOKEN_CONFIG.name,
      DANK_TOKEN_CONFIG.symbol,
      deployer.address, // initial holder
      DANK_TOKEN_CONFIG.maxSupply
    );

    await dankToken.waitForDeployment();
    const dankTokenAddress = await dankToken.getAddress();
    
    console.log(`DankToken deployed to: ${dankTokenAddress}`);

    // Verify contract if not on localhost
    if (network.name !== "localhost" && network.name !== "hardhat") {
      console.log("Waiting for block confirmations...");
      await dankToken.deploymentTransaction()?.wait(6);

      console.log("Verifying contract...");
      await run("verify:verify", {
        address: dankTokenAddress,
        constructorArguments: [
          DANK_TOKEN_CONFIG.name,
          DANK_TOKEN_CONFIG.symbol,
          deployer.address,
          DANK_TOKEN_CONFIG.maxSupply,
        ],
      });
    }

    console.log("Deployment completed successfully");
  } catch (error) {
    console.error("Deployment failed:", error);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 