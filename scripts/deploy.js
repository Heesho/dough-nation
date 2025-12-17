const { ethers } = require("hardhat");
const hre = require("hardhat");

// Constants
const sleep = (delay) => new Promise((resolve) => setTimeout(resolve, delay));
const convert = (amount, decimals = 18) => ethers.utils.parseUnits(amount.toString(), decimals);
const divDec = (amount, decimals = 18) => amount / 10 ** decimals;

// =============================================================================
// CONFIGURATION - UPDATE THESE FOR YOUR DEPLOYMENT
// =============================================================================

// Base Mainnet addresses
const WETH_ADDRESS = "0x4200000000000000000000000000000000000006"; // WETH on Base

// Payment token (set this to your chosen ERC-20: USDC, WETH, DAI, etc.)
// USDC on Base: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
// WETH on Base: 0x4200000000000000000000000000000000000006
const PAYMENT_TOKEN_ADDRESS = ""; // TODO: Set payment token address

// Fund recipients
const TREASURY_ADDRESS = ""; // TODO: Set treasury wallet address
const TEAM_ADDRESS = ""; // TODO: Set team wallet address

// Charities to whitelist (add addresses after deployment)
const CHARITIES_TO_WHITELIST = []; // TODO: Add charity addresses to whitelist

// Deployed Contract Addresses (paste after deployment)
let UNIT_TOKEN = "";
let RIG = "";

// Contract Variables
let unitToken, rig;

// =============================================================================
// GET CONTRACTS
// =============================================================================

async function getContracts() {
  if (UNIT_TOKEN) {
    unitToken = await ethers.getContractAt(
      "contracts/Unit.sol:Unit",
      UNIT_TOKEN
    );
    console.log("Unit retrieved:", unitToken.address);
  }

  if (RIG) {
    rig = await ethers.getContractAt(
      "contracts/Rig.sol:Rig",
      RIG
    );
    console.log("Rig retrieved:", rig.address);
  }
}

// =============================================================================
// DEPLOY FUNCTIONS
// =============================================================================

async function deployUnit() {
  console.log("Starting Unit Deployment");
  const artifact = await ethers.getContractFactory("Unit");
  const contract = await artifact.deploy({ gasPrice: ethers.gasPrice });
  unitToken = await contract.deployed();
  await sleep(5000);
  console.log("Unit Deployed at:", unitToken.address);
  UNIT_TOKEN = unitToken.address;
}

async function deployRig() {
  console.log("Starting Rig Deployment");

  if (!PAYMENT_TOKEN_ADDRESS) {
    throw new Error("PAYMENT_TOKEN_ADDRESS must be set before deployment");
  }
  if (!unitToken && !UNIT_TOKEN) {
    throw new Error("Unit must be deployed first");
  }
  if (!TREASURY_ADDRESS) {
    throw new Error("TREASURY_ADDRESS must be set before deployment");
  }
  if (!TEAM_ADDRESS) {
    throw new Error("TEAM_ADDRESS must be set before deployment");
  }

  const artifact = await ethers.getContractFactory("Rig");
  const contract = await artifact.deploy(
    PAYMENT_TOKEN_ADDRESS,
    unitToken?.address || UNIT_TOKEN,
    TREASURY_ADDRESS,
    TEAM_ADDRESS,
    { gasPrice: ethers.gasPrice }
  );
  rig = await contract.deployed();
  await sleep(5000);
  console.log("Rig Deployed at:", rig.address);
  RIG = rig.address;
}

async function whitelistCharities() {
  console.log("Whitelisting charities...");
  const rigContract = rig || await ethers.getContractAt("Rig", RIG);

  for (const charity of CHARITIES_TO_WHITELIST) {
    console.log("Adding charity:", charity);
    const tx = await rigContract.addCharity(charity);
    await tx.wait();
    console.log("Charity added:", charity);
  }
  console.log("All charities whitelisted");
}

async function transferMintingRights() {
  console.log("Transferring minting rights to Rig");

  if (!unitToken && !UNIT_TOKEN) {
    throw new Error("Unit address not available");
  }
  if (!rig && !RIG) {
    throw new Error("Rig address not available");
  }

  const token = unitToken || await ethers.getContractAt("Unit", UNIT_TOKEN);
  const rigAddress = rig?.address || RIG;

  const tx = await token.setRig(rigAddress);
  await tx.wait();
  console.log("Minting rights transferred to:", rigAddress);
}

// =============================================================================
// VERIFY FUNCTIONS
// =============================================================================

async function verifyUnit() {
  console.log("Starting Unit Verification");
  await hre.run("verify:verify", {
    address: unitToken?.address || UNIT_TOKEN,
    contract: "contracts/Unit.sol:Unit",
    constructorArguments: [],
  });
  console.log("Unit Verified");
}

async function verifyRig() {
  console.log("Starting Rig Verification");
  await hre.run("verify:verify", {
    address: rig?.address || RIG,
    contract: "contracts/Rig.sol:Rig",
    constructorArguments: [
      PAYMENT_TOKEN_ADDRESS,
      unitToken?.address || UNIT_TOKEN,
      TREASURY_ADDRESS,
      TEAM_ADDRESS,
    ],
  });
  console.log("Rig Verified");
}

// =============================================================================
// CONFIGURATION FUNCTIONS
// =============================================================================

async function addCharity(charityAddress) {
  console.log("Adding charity to whitelist:", charityAddress);
  const rigContract = rig || await ethers.getContractAt("Rig", RIG);
  const tx = await rigContract.addCharity(charityAddress);
  await tx.wait();
  console.log("Charity added to whitelist");
}

async function removeCharity(charityAddress) {
  console.log("Removing charity from whitelist:", charityAddress);
  const rigContract = rig || await ethers.getContractAt("Rig", RIG);
  const tx = await rigContract.removeCharity(charityAddress);
  await tx.wait();
  console.log("Charity removed from whitelist");
}

async function setTreasuryAddress(newAddress) {
  console.log("Setting Treasury Address to:", newAddress);
  const rigContract = rig || await ethers.getContractAt("Rig", RIG);
  const tx = await rigContract.setTreasuryAddress(newAddress);
  await tx.wait();
  console.log("Treasury Address updated");
}

async function setTeamAddress(newAddress) {
  console.log("Setting Team Address to:", newAddress);
  const rigContract = rig || await ethers.getContractAt("Rig", RIG);
  const tx = await rigContract.setTeamAddress(newAddress);
  await tx.wait();
  console.log("Team Address updated");
}

async function transferRigOwnership(newOwner) {
  console.log("Transferring Rig ownership to:", newOwner);
  const rigContract = rig || await ethers.getContractAt("Rig", RIG);
  const tx = await rigContract.transferOwnership(newOwner);
  await tx.wait();
  console.log("Rig ownership transferred");
}

// =============================================================================
// PRINT FUNCTIONS
// =============================================================================

async function printDeployment() {
  console.log("\n==================== DOUGHNATION DEPLOYMENT ====================\n");

  console.log("--- Configuration ---");
  console.log("Payment Token:    ", PAYMENT_TOKEN_ADDRESS || "NOT SET");
  console.log("Treasury Address: ", TREASURY_ADDRESS || "NOT SET");
  console.log("Team Address:     ", TEAM_ADDRESS || "NOT SET");

  console.log("\n--- Deployed Contracts ---");
  console.log(
    "Unit:             ",
    unitToken?.address || UNIT_TOKEN || "NOT DEPLOYED"
  );
  console.log(
    "Rig:              ",
    rig?.address || RIG || "NOT DEPLOYED"
  );

  if (unitToken || UNIT_TOKEN) {
    const token = unitToken || await ethers.getContractAt("Unit", UNIT_TOKEN);
    console.log("\n--- Unit State ---");
    console.log("Name:             ", await token.name());
    console.log("Symbol:           ", await token.symbol());
    console.log("Rig:              ", await token.rig());
    console.log("Total Supply:     ", divDec(await token.totalSupply()));
  }

  if (rig || RIG) {
    const rigContract = rig || await ethers.getContractAt("Rig", RIG);
    console.log("\n--- Rig State ---");
    console.log("Owner:            ", await rigContract.owner());
    console.log("Payment Token:    ", await rigContract.paymentToken());
    console.log("Unit:             ", await rigContract.unit());
    console.log("Treasury Address: ", await rigContract.treasuryAddress());
    console.log("Team Address:     ", await rigContract.teamAddress());
    console.log("Current Day:      ", (await rigContract.currentDay()).toString());
    console.log("Initial Emission: ", divDec(await rigContract.INITIAL_EMISSION()), "DOUGH/day");
    console.log("Min Emission:     ", divDec(await rigContract.MIN_EMISSION()), "DOUGH/day");
  }

  console.log("\n================================================================\n");
}

async function printEmissionSchedule() {
  console.log("\n--- Emission Schedule ---");
  const rigContract = rig || await ethers.getContractAt("Rig", RIG);

  const days = [0, 29, 30, 59, 60, 89, 90, 120, 150, 180, 210, 240, 270, 300];
  for (const day of days) {
    const emission = await rigContract.getDayEmission(day);
    console.log(`Day ${day.toString().padStart(3)}: ${divDec(emission).toLocaleString()} DOUGH`);
  }
  console.log("");
}

// =============================================================================
// MAIN
// =============================================================================

async function main() {
  const [wallet] = await ethers.getSigners();
  console.log("Using wallet:", wallet.address);
  console.log(
    "Account balance:",
    ethers.utils.formatEther(await wallet.getBalance()),
    "ETH"
  );
  console.log("");

  await getContracts();

  //===================================================================
  // 1. Deploy System
  //===================================================================

  // console.log("Starting Deployment...");
  // await deployUnit();
  // await deployRig();
  // await transferMintingRights();
  // await whitelistCharities(); // Whitelist charities from CHARITIES_TO_WHITELIST array

  //===================================================================
  // 2. Verify Contracts
  //===================================================================

  // console.log("Starting Verification...");
  // await verifyUnit();
  // await sleep(5000);
  // await verifyRig();

  //===================================================================
  // 3. Configuration (optional)
  //===================================================================

  // await addCharity("0xCHARITY_ADDRESS");
  // await removeCharity("0xCHARITY_ADDRESS");
  // await setTreasuryAddress("0xNEW_TREASURY_ADDRESS");
  // await setTeamAddress("0xNEW_TEAM_ADDRESS");

  //===================================================================
  // 4. Transfer Ownership (optional)
  //===================================================================

  // await transferRigOwnership("0xMULTISIG_ADDRESS");

  //===================================================================
  // Print Deployment
  //===================================================================

  await printDeployment();
  // await printEmissionSchedule();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
