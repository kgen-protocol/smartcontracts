import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'

const contractName = 'KgenOFT'

const LZ_ENDPOINT_V2 = '0x1a44076050125825900e736c501f859c50fE728c'
// Deploy with no initial trusted forwarder; add via addTrustedForwarder() once the real
const TRUSTED_FORWARDER = '0x0000000000000000000000000000000000000000'
const TOKEN_NAME = 'KGEN'
const TOKEN_SYMBOL = 'KGEN'

const isTruthyEnv = (value: string | undefined): boolean => value === '1' || value?.toLowerCase() === 'true'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    const pendingNonce = await hre.ethers.provider.getTransactionCount(deployer, 'pending')
    const predictedCreateAddress = hre.ethers.utils.getContractAddress({ from: deployer, nonce: pendingNonce })
    const expectedAddress = process.env.KGEN_OFT_EXPECTED_ADDRESS

    console.log(`Pending deployer nonce: ${pendingNonce}`)
    console.log(`Next CREATE address: ${predictedCreateAddress}`)
    console.log(`Constructor args:`)
    console.log(`  name:              ${TOKEN_NAME}`)
    console.log(`  symbol:            ${TOKEN_SYMBOL}`)
    console.log(`  lzEndpoint:        ${LZ_ENDPOINT_V2}`)
    console.log(`  delegate/owner:    ${deployer}`)
    console.log(`  trustedForwarder:  ${TRUSTED_FORWARDER}`)

    if (expectedAddress != null && expectedAddress.trim() !== '') {
        const normalizedExpectedAddress = hre.ethers.utils.getAddress(expectedAddress)
        const normalizedPredictedAddress = hre.ethers.utils.getAddress(predictedCreateAddress)

        assert(
            normalizedPredictedAddress === normalizedExpectedAddress,
            `Predicted KgenOFT address ${normalizedPredictedAddress} does not match expected ${normalizedExpectedAddress}`
        )
    }

    if (isTruthyEnv(process.env.KGEN_OFT_DRY_RUN)) {
        console.log('KGEN_OFT_DRY_RUN=true; skipping deployment broadcast.')
        return
    }

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [TOKEN_NAME, TOKEN_SYMBOL, LZ_ENDPOINT_V2, deployer, TRUSTED_FORWARDER],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)
}

deploy.tags = [contractName]

export default deploy
