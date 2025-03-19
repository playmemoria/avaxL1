import { expect } from 'chai'
import hre from 'hardhat'
import { time } from '@nomicfoundation/hardhat-toolbox/network-helpers'

describe('Albert', function () {
  it('Owner should be signers[0]', async function () {
    const signers = await hre.ethers.getSigners()
    const owner = signers[0]
    const albert = await hre.ethers.deployContract('Albert', [
      hre.ethers.parseEther(String(1_000_000_000)),
      'ALBERT',
      'ALBERT',
      owner.address,
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

    // assert that the owner is correct
    expect(await albert.owner()).to.equal(owner.address)
  })
})
