import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
require('dotenv').config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    etherlink: {
      url: "https://node.ghostnet.etherlink.com",
      accounts: [process.env.PRIVATE_KEY || ""],
      gasPrice: 1000000000,
      gas: 5000000
    },
    amoy: {
      url: process.env.POLYGON_AMOY_RPC_URL || "https://rpc-amoy.polygon.technology",
      accounts: [process.env.PRIVATE_KEY || ""],
      gasPrice: 30000000000,
      gas: 5000000
    },
    base: {
      url: process.env.BASE_RPC_URL || "https://base-sepolia-rpc.publicnode.com",
      accounts: [process.env.PRIVATE_KEY || ""],
      gasPrice: 30000000000,
      gas: 5000000
    },
    bsctest: {
      url: process.env.BSC_TESTNET_RPC_URL || "https://bsc-testnet.infura.io/v3/6d95ac3a75e24981b5092eb6f1aeb566",
      accounts: [process.env.PRIVATE_KEY || ""],
      gasPrice: 30000000000,
      gas: 5000000
    }
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.BSC_TESTNET_API_KEY || "J2JVVNNM7F195I15QMEG5572V5D7GH8SY4"
    }
  }
};

export default config;
