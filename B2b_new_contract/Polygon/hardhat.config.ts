import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
import "hardhat-tracer";
import "hardhat-deploy";
// import "@nomiclabs/hardhat-etherscan";
import "hardhat-storage-layout";
import "hardhat-storage-layout-changes";
import { HttpNetworkUserConfig } from "hardhat/types";
dotenv.config({ path:".env" });

const DEFAULT_MNEMONIC: string = process.env.MNEMONIC || "";

const sharedNetworkConfig: HttpNetworkUserConfig = {
  live: true,
  saveDeployments: true,
  timeout: 8000000,
  gasPrice: "auto",
};
if (process.env.PRIVATE_KEY && process.env.PRIVATE_KEY_2) {
  sharedNetworkConfig.accounts = [process.env.PRIVATE_KEY,process.env.PRIVATE_KEY_2];
} else {
  sharedNetworkConfig.accounts = {
    mnemonic: process.env.MNEMONIC || DEFAULT_MNEMONIC,
  };
}

export default {
  namedAccounts: {
    deployer: 1,
  },
  paths: {
    tests: "./test",
    cache: "./cache",
    deploy: "./src/deploy",
    sources: "./contracts",
    deployments: "./deployments",
    artifacts: "./artifacts",
    storageLayouts: ".storage-layouts",
  },

  storageLayoutConfig: {
    contracts: ["KgenStaking"],
    fullPath: false
  },

  solidity: {
    compilers: [
      {
        version: "0.8.22",
        settings: {
          optimizer: {
            runs: 200,
            enabled: true,
          },
          "outputSelection": {
            "*": {
              "*": [
                "metadata", "evm.bytecode" // Enable the metadata and bytecode outputs of every single contract.
                , "evm.bytecode.sourceMap", // Enable the source map output of every single contract.
                "storageLayout"
              ],
              "": [
                "ast" // Enable the AST output of every single file.
              ]
            },
          },
        },
      },
    ],
    // compile file with give version
    // overrides: {
    //   "contracts/gnosis-safe/safe.sol": {
    //     version: "0.7.6",
    //     settings: {
    //       "outputSelection": {
    //         "*": {
    //           "*": [
    //             "metadata", "evm.bytecode" // Enable the metadata and bytecode outputs of every single contract.
    //             , "evm.bytecode.sourceMap", // Enable the source map output of every single contract.
    //             "storageLayout"
    //           ],
    //           "": [
    //             "ast" // Enable the AST output of every single file.
    //           ]
    //         },
    //       },
    //     },
    //   },
    // },
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      accounts: {
        accountsBalance: "100000000000000000000000000000000000000000",
        mnemonic: process.env.MNEMONIC || DEFAULT_MNEMONIC,
      },
    },
    bsctestnet:{
      ...sharedNetworkConfig,
      url: `https://bsc-testnet.infura.io/v3/${process.env.INFURA_KEY}`,
    },
    goerli: {
      ...sharedNetworkConfig,
      url: `https://goerli.infura.io/v3/${process.env.INFURA_KEY}`,
      //  chainId: 5,
    },
    arbitrum_goerli: {
      ...sharedNetworkConfig,
      url: `https://arbitrum-goerli.infura.io/v3/${process.env.INFURA_KEY}`,
    },
    arbitrum: {
      ...sharedNetworkConfig,
      url: `https://arbitrum-mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
    },
    avalanche_fuji: {
      ...sharedNetworkConfig,
      url: `https://avalanche-fuji.infura.io/v3/${process.env.INFURA_KEY}`,
    },
    shardeum_sphinx: {
      ...sharedNetworkConfig,
      url: `https://sphinx.shardeum.org/`,
    },
    polygon_mumbai: {
      ...sharedNetworkConfig,
      url: `https://polygon-amoy.infura.io/v3/${process.env.INFURA_KEY}`,
    },
    polygon: {
      ...sharedNetworkConfig,
      url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
    },
  },
  etherscan: {
    apiKey: "2258DEMSUPXFZ5HAUHP7HQ2DGY74GQ6T5K",
  },
  watcher: {
    /* run npx hardhat watch compilation */
    compilation: {
      tasks: ["compile"],
      verbose: true,
    },
  },
  mocha: {
    timeout: 8000000,
  },
  /* run npx hardhat watch test */
  test: {
    tasks: [
      {
        command: "test",
        params: {
          logs: true,
          noCompile: false,
          testFiles: ["./test/KgenStaking.ts"],
        },
      },
    ],
    files: ["./test/*"],
    verbose: true,
  },
  /* run npx hardhat watch ci */
  ci: {
    tasks: [
      "clean",
      { command: "compile", params: { quiet: true } },
      {
        command: "test",
        params: {
          noCompile: true,
          testFiles: ["./test/KgenStaking.ts"],
        },
      },
    ],
  },
  //  shows gas in tables
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 10,
  },

};