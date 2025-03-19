import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { parseEther } from 'ethers'

export default buildModule('Albert', m => {
  const albert = m.contract('Albert', [
    parseEther(String(1_000_000_000)),
    'ALBERT',
    'ALBERT',
    '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    {
      // antiSnipeDuration: 15n,
      // antiWhaleDuration: 30n,
      // earlyBuyLimit: 1500000000000000000000000n,
      // whaleBuyLimit: 2500000000000000000000000n,
      // maxGasPrice: 3046996254n,
      antiSnipeDuration: 0,
      antiWhaleDuration: 0,
      earlyBuyLimit: 1500000000000000000000000n,
      whaleBuyLimit: 2500000000000000000000000n,
      maxGasPrice: 3046996254n,
    },
  ])

  return { albert }
})