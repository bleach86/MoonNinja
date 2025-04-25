require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: `0.8.26`,
        settings: {
          optimizer: {
            enabled: true,
            runs: 1500,
          },
          evmVersion: `cancun`,
        },
      },
    ],
  },
};
