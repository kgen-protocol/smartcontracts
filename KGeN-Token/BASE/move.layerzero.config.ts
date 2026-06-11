import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

enum MsgType {
    SEND = 1,
    SEND_AND_CALL = 2,
}

const bscContract: OmniPointHardhat = {
    eid: EndpointId.BSC_V2_MAINNET,
    contractName: 'KgenOFT',
}

const baseContract: OmniPointHardhat = {
    eid: EndpointId.BASE_V2_MAINNET,
    contractName: 'KgenOFT',
}

const aptosContract: OmniPointHardhat = {
    eid: EndpointId.APTOS_V2_MAINNET,
    contractName: 'MyOFT',
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: bscContract,
            config: {
                owner: '0xF0E5D87C65483D11973CEaAA1f5353919aC1B0D0',
                delegate: '0xF0E5D87C65483D11973CEaAA1f5353919aC1B0D0',
            },
        },
        {
            contract: baseContract,
            config: {
                owner: '0xF0E5D87C65483D11973CEaAA1f5353919aC1B0D0',
                delegate: '0xF0E5D87C65483D11973CEaAA1f5353919aC1B0D0',
            },
        },
        {
            contract: aptosContract,
            config: {
                delegate: '0x64d52e91b3b23a285866f51ce86075a56c65532052bbb9bc4d1735b71e932e0e',
                owner: '0x64d52e91b3b23a285866f51ce86075a56c65532052bbb9bc4d1735b71e932e0e',
            },
        },
    ],
    connections: [
        {
            from: aptosContract,
            to: bscContract,
            config: {
                enforcedOptions: [
                    {
                        msgType: MsgType.SEND,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 120_000, // gas limit in wei for EndpointV2.lzReceive
                        value: 0, // msg.value in wei for EndpointV2.lzReceive
                    },
                    {
                        msgType: MsgType.SEND_AND_CALL,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 120_000, // gas limit in wei for EndpointV2.lzReceive
                        value: 0, // msg.value in wei for EndpointV2.lzReceive
                    },
                ],
                sendLibrary: '0xc33752e0220faf79e45385dd73fb28d681dcd9f1569a1480725507c1f3c3aba9',
                receiveLibraryConfig: {
                    receiveLibrary: '0xc33752e0220faf79e45385dd73fb28d681dcd9f1569a1480725507c1f3c3aba9',
                    gracePeriod: BigInt(0),
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10_000,
                        executor: '0x15a5bbf1eb7998a22c9f23810d424abe40bd59ddd8e6ab7e59529853ebed41c4',
                    },
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0xf3f0a412626edba5ddd3613d91109b241893873ac5479ade231cf0b3130572b5'  //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x9880ed7ade7e7f8f8eb070ce72c51b231921e29e65b3d51fa3810814bba32c00', // Horizen DVN
                            '0xb3e501ffd9d101f9eb400aa4a6373b9be227273b6ddd54b73c426b8523ab05e3', // Deutsche Telekom DVN
                            '0xcb2ab3c2fb799c6578b9950f9db7ff555a2d4967ef15437230346f56599801ae', // P2P DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0xf3f0a412626edba5ddd3613d91109b241893873ac5479ade231cf0b3130572b5'  //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x9880ed7ade7e7f8f8eb070ce72c51b231921e29e65b3d51fa3810814bba32c00', // Horizen DVN
                            '0xb3e501ffd9d101f9eb400aa4a6373b9be227273b6ddd54b73c426b8523ab05e3', // Deutsche Telekom DVN
                            '0xcb2ab3c2fb799c6578b9950f9db7ff555a2d4967ef15437230346f56599801ae', // P2P DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
            },
        },
        {
            from: bscContract,
            to: aptosContract,
            config: {
                enforcedOptions: [
                    {
                        msgType: MsgType.SEND,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 20_000, // gas limit in wei for EndpointV2.lzReceive
                        value: 0, // msg.value in wei for EndpointV2.lzReceive
                    },
                    {
                        msgType: MsgType.SEND_AND_CALL,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 20_000, // gas limit in wei for EndpointV2.lzCompose
                        value: 0, // msg.value in wei for EndpointV2.lzCompose
                    },
                ],
                sendLibrary: '0x9F8C645f2D0b2159767Bd6E0839DE4BE49e823DE', // BSC send library
                receiveLibraryConfig: {
                    receiveLibrary: '0xB217266c3A98C8B2709Ee26836C98cf12f6cCEC1', // BSC receive library
                    gracePeriod: BigInt(0),
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10_000,
                        executor: '0x3ebD570ed38B1b3b4BC886999fcF507e9D584859', // BSC executor
                    },
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0xfd6865c841c2d64565562fcc7e05e619a30615f0' //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x247624e2143504730aec22912ed41f092498bef2', // Horizen DVN
                            '0x439264fb87581a70bb6d7befd16b636521b0ad2d', // P2P DVN
                            '0xf0a5c5306adbfd4e3dfd5d4b148b451c411d3878', // Deutsche Telekom DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0xfd6865c841c2d64565562fcc7e05e619a30615f0' //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x247624e2143504730aec22912ed41f092498bef2', // Horizen DVN
                            '0x439264fb87581a70bb6d7befd16b636521b0ad2d', // P2P DVN
                            '0xf0a5c5306adbfd4e3dfd5d4b148b451c411d3878', // Deutsche Telekom DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
            },
        },
        {
            from: aptosContract,
            to: baseContract,
            config: {
                enforcedOptions: [
                    {
                        msgType: MsgType.SEND,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 120_000, // gas limit in wei for EndpointV2.lzReceive
                        value: 0, // msg.value in wei for EndpointV2.lzReceive
                    },
                    {
                        msgType: MsgType.SEND_AND_CALL,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 120_000, // gas limit in wei for EndpointV2.lzReceive
                        value: 0, // msg.value in wei for EndpointV2.lzReceive
                    },
                ],
                sendLibrary: '0xc33752e0220faf79e45385dd73fb28d681dcd9f1569a1480725507c1f3c3aba9',
                receiveLibraryConfig: {
                    receiveLibrary: '0xc33752e0220faf79e45385dd73fb28d681dcd9f1569a1480725507c1f3c3aba9',
                    gracePeriod: BigInt(0),
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10_000,
                        executor: '0x15a5bbf1eb7998a22c9f23810d424abe40bd59ddd8e6ab7e59529853ebed41c4',
                    },
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0xf3f0a412626edba5ddd3613d91109b241893873ac5479ade231cf0b3130572b5'  //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x9880ed7ade7e7f8f8eb070ce72c51b231921e29e65b3d51fa3810814bba32c00', // Horizen DVN
                            '0xb3e501ffd9d101f9eb400aa4a6373b9be227273b6ddd54b73c426b8523ab05e3', // Deutsche Telekom DVN
                            '0xcb2ab3c2fb799c6578b9950f9db7ff555a2d4967ef15437230346f56599801ae', // P2P DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0xf3f0a412626edba5ddd3613d91109b241893873ac5479ade231cf0b3130572b5'  //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x9880ed7ade7e7f8f8eb070ce72c51b231921e29e65b3d51fa3810814bba32c00', // Horizen DVN
                            '0xb3e501ffd9d101f9eb400aa4a6373b9be227273b6ddd54b73c426b8523ab05e3', // Deutsche Telekom DVN
                            '0xcb2ab3c2fb799c6578b9950f9db7ff555a2d4967ef15437230346f56599801ae', // P2P DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
            },
        },
        {
            from: baseContract,
            to: aptosContract,
            config: {
                enforcedOptions: [
                    {
                        msgType: MsgType.SEND,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 20_000, // gas limit in wei for EndpointV2.lzReceive
                        value: 0, // msg.value in wei for EndpointV2.lzReceive
                    },
                    {
                        msgType: MsgType.SEND_AND_CALL,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 20_000, // gas limit in wei for EndpointV2.lzCompose
                        value: 0, // msg.value in wei for EndpointV2.lzCompose
                    },
                ],
                sendLibrary: '0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2', // base send library
                receiveLibraryConfig: {
                    receiveLibrary: '0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf', // base receive library
                    gracePeriod: BigInt(0),
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10_000,
                        executor: '0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4', // base executor
                    },
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0x9e059a54699a285714207b43b055483e78faac25' //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x5b6735c66d97479ccd18294fc96b3084ecb2fa3f', // P2P DVN
                            '0xa7b5189bca84cd304d8553977c7c614329750d99', // Horizen DVN
                            '0xc2a0c36f5939a14966705c7cec813163faeea1f0', // Deutsche Telekom DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0x9e059a54699a285714207b43b055483e78faac25' //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x5b6735c66d97479ccd18294fc96b3084ecb2fa3f', // P2P DVN
                            '0xa7b5189bca84cd304d8553977c7c614329750d99', // Horizen DVN
                            '0xc2a0c36f5939a14966705c7cec813163faeea1f0', // Deutsche Telekom DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
            },
        },
        {
            from: bscContract,
            to: baseContract,
            config: {
                enforcedOptions: [
                    {
                        msgType: MsgType.SEND,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 120_000, // gas limit in wei for EndpointV2.lzReceive
                        value: 0, // msg.value in wei for EndpointV2.lzReceive
                    },
                    {
                        msgType: MsgType.SEND_AND_CALL,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 120_000, // gas limit in wei for EndpointV2.lzCompose
                        value: 0, // msg.value in wei for EndpointV2.lzCompose
                    },
                ],
                sendLibrary: '0x9F8C645f2D0b2159767Bd6E0839DE4BE49e823DE', // BSC send library
                receiveLibraryConfig: {
                    receiveLibrary: '0xB217266c3A98C8B2709Ee26836C98cf12f6cCEC1', // BSC receive library
                    gracePeriod: BigInt(0),
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10_000,
                        executor: '0x3ebD570ed38B1b3b4BC886999fcF507e9D584859', // BSC executor
                    },
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0xfd6865c841c2d64565562fcc7e05e619a30615f0' //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x247624e2143504730aec22912ed41f092498bef2', // Horizen DVN
                            '0x439264fb87581a70bb6d7befd16b636521b0ad2d', // P2P DVN
                            '0xf0a5c5306adbfd4e3dfd5d4b148b451c411d3878', // Deutsche Telekom DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0xfd6865c841c2d64565562fcc7e05e619a30615f0' //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x247624e2143504730aec22912ed41f092498bef2', // Horizen DVN
                            '0x439264fb87581a70bb6d7befd16b636521b0ad2d', // P2P DVN
                            '0xf0a5c5306adbfd4e3dfd5d4b148b451c411d3878', // Deutsche Telekom DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
            },
        },
        {
            from: baseContract,
            to: bscContract,
            config: {
                enforcedOptions: [
                    {
                        msgType: MsgType.SEND,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 120_000, // gas limit in wei for EndpointV2.lzReceive
                        value: 0, // msg.value in wei for EndpointV2.lzReceive
                    },
                    {
                        msgType: MsgType.SEND_AND_CALL,
                        optionType: ExecutorOptionType.LZ_RECEIVE,
                        gas: 120_000, // gas limit in wei for EndpointV2.lzCompose
                        value: 0, // msg.value in wei for EndpointV2.lzCompose
                    },
                ],
                sendLibrary: '0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2', // Base send library
                receiveLibraryConfig: {
                    receiveLibrary: '0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf', // Base receive library
                    gracePeriod: BigInt(0),
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10_000,
                        executor: '0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4', // Base executor
                    },
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0x9e059a54699a285714207b43b055483e78faac25' //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x5b6735c66d97479ccd18294fc96b3084ecb2fa3f', // P2P DVN
                            '0xa7b5189bca84cd304d8553977c7c614329750d99', // Horizen DVN
                            '0xc2a0c36f5939a14966705c7cec813163faeea1f0', // Deutsche Telekom DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: BigInt(5),
                        requiredDVNs: [
                            '0x9e059a54699a285714207b43b055483e78faac25' //LayerZero DVN
                        ],
                        optionalDVNs: [
                            '0x5b6735c66d97479ccd18294fc96b3084ecb2fa3f', // P2P DVN
                            '0xa7b5189bca84cd304d8553977c7c614329750d99', // Horizen DVN
                            '0xc2a0c36f5939a14966705c7cec813163faeea1f0', // Deutsche Telekom DVN
                        ],
                        optionalDVNThreshold: 2,
                    },
                },
            },
        },
    ],
}

export default config
