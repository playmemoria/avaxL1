import 'dotenv/config'
import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{
      version: '0.8.28',
    }],
    overrides: {
      'contracts/MemoriaAL.sol': {
        version: '0.8.27',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10_000,
          },
          evmVersion: 'paris',
        },
      },
      'contracts/AlbertMemorySpores.sol': {
        version: '0.8.26',
        settings: {
          optimizer: {
            enabled: false,
            // runs: 10_000,
          },
        },
      },
      'contracts/AMSUpgrader.sol': {
        version: '0.8.28',
        settings: {
          viaIR: true,
        },
      },
      'contracts/Albert.sol': {
        version: '0.8.20',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: 'shanghai',
        },
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      blockGasLimit: 30_000_000,
      throwOnCallFailures: true,
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic: process.env.MNEMONIC_PHRASE,
      },
    },
    sepolia: {
      url: 'https://rpc.sepolia.org',
      chainId: 11155111,
      accounts: {
        mnemonic: process.env.MNEMONIC_PHRASE,
      },
    },
    ethereum: {
      url: 'https://eth.llamarpc.com',
      chainId: 1,
      accounts: {
        mnemonic: process.env.MNEMONIC_PHRASE,
      },
    },
    avalanche: {
      url: 'https://api.avax.network/ext/bc/C/rpc',
      chainId: 43114,
      accounts: {
        mnemonic: process.env.MNEMONIC_PHRASE,
      },
    },
  },
}

export default config
