import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "dotenv/config";

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";

if (!PRIVATE_KEY) {
  console.warn(
    "Could not find PRIVATE_KEY environment variable. It will not be possible to execute transactions."
  );
}

const config: HardhatUserConfig = {
  paths: {
    sources: "./contracts",
  },
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    bsctest: {
      url:
        process.env.BSC_TESTNET_RPC_URL ||
        "https://bsc-testnet-rpc.publicnode.com",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      gasPrice: 30000000000,
      gas: 5000000,
    },
    amoy: {
      url:
        process.env.POLYGON_AMOY_RPC_URL ||
        "https://rpc-amoy.polygon.technology",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      gasPrice: 30000000000,
      gas: 5000000,
    },
    mainnet: {
      url: process.env.BSC_MAINNET_RPC_URL || "https://bsc-rpc.publicnode.com",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      gasPrice: 5000000000,
      gas: 5000000,
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.BSC_TESTNET_API_KEY || "",
      polygonAmoy: process.env.POLYGON_API_KEY || "",
      bsc: process.env.BSC_API_KEY || "",
    },
  },
};

export default config;
