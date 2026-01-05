require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    polygon: {
      url: "https://polygon-rpc.com/",
      accounts: []
    }
  }
};
