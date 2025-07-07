import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import 'dotenv/config';

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
      accounts: [process.env.PRIVATE_KEY || "a055dd959152716a90107de178bff22c6f9f8948e2ffa8bcf0b3429ac8cfc613"],
      gasPrice: 1000000000,
      gas: 5000000
    },
    amoy: {
      url: process.env.POLYGON_AMOY_RPC_URL || "https://rpc-amoy.polygon.technology",
      accounts: [process.env.PRIVATE_KEY || "6bc71cc78ebd49a3d6ec116cd695935088d5caed61b1b012b05b8e52dca898bc"],
      gasPrice: 30000000000,
      gas: 5000000
    },
    base: {
      url: process.env.BASE_RPC_URL || "https://base-sepolia-rpc.publicnode.com",
      accounts: [process.env.PRIVATE_KEY || "6bc71cc78ebd49a3d6ec116cd695935088d5caed61b1b012b05b8e52dca898bc"],
      gasPrice: 30000000000,
      gas: 5000000
    },
    bsctest: {
      url: process.env.BSC_TESTNET_RPC_URL || "https://bsc-testnet.infura.io/v3/6d95ac3a75e24981b5092eb6f1aeb566",
      accounts: [process.env.PRIVATE_KEY || "3e0a8ed8f93e4ea251e952439947d7761283b59c4e645a7953c63166a0807b39"],
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
