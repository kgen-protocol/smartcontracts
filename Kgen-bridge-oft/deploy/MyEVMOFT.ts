import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'

const contractName = 'KgenOFT'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    // This is an external deployment pulled in from @layerzerolabs/lz-evm-sdk-v2
    //
    // @layerzerolabs/toolbox-hardhat takes care of plugging in the external deployments
    // from @layerzerolabs packages based on the configuration in your hardhat config
    //
    // For this to work correctly, your network config must define an eid property
    // set to `EndpointId` as defined in @layerzerolabs/lz-definitions
    //
    // For example:
    //
    // networks: {
    //   fuji: {
    //     ...
    //     eid: EndpointId.AVALANCHE_V2_TESTNET
    //   }
    // }
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')
console.log(`Using EndpointV2 deployment: ${endpointV2Deployment.address}`)
    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            'KGEN', // name
            'KGEN', // symbol
            '0x6EDCE65403992e310A62460808c4b910D972f10f', // LayerZero's EndpointV2 address
            deployer, // owner\
            '0xBD4568bC939F1f2eBC29b36963c6240822212183',
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)
}

deploy.tags = [contractName]

export default deploy
