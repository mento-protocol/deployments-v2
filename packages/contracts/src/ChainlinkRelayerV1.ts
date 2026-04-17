export const ChainlinkRelayerV1 = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "_rateFeedId",
          type: "address",
          internalType: "address",
        },
        {
          name: "_rateFeedDescription",
          type: "string",
          internalType: "string",
        },
        {
          name: "_sortedOracles",
          type: "address",
          internalType: "address",
        },
        {
          name: "_maxTimestampSpread",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "_aggregators",
          type: "tuple[]",
          internalType: "struct IChainlinkRelayer.ChainlinkAggregator[]",
          components: [
            {
              name: "aggregator",
              type: "address",
              internalType: "address",
            },
            {
              name: "invert",
              type: "bool",
              internalType: "bool",
            },
          ],
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "getAggregators",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "tuple[]",
          internalType: "struct IChainlinkRelayer.ChainlinkAggregator[]",
          components: [
            {
              name: "aggregator",
              type: "address",
              internalType: "address",
            },
            {
              name: "invert",
              type: "bool",
              internalType: "bool",
            },
          ],
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "maxTimestampSpread",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "rateFeedDescription",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "string",
          internalType: "string",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "rateFeedId",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "relay",
      inputs: [],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "sortedOracles",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "error",
      name: "ExpiredTimestamp",
      inputs: [],
    },
    {
      type: "error",
      name: "InvalidAggregator",
      inputs: [],
    },
    {
      type: "error",
      name: "InvalidMaxTimestampSpread",
      inputs: [],
    },
    {
      type: "error",
      name: "InvalidPrice",
      inputs: [],
    },
    {
      type: "error",
      name: "NoAggregators",
      inputs: [],
    },
    {
      type: "error",
      name: "PRBMath_MulDiv18_Overflow",
      inputs: [
        {
          name: "x",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "y",
          type: "uint256",
          internalType: "uint256",
        },
      ],
    },
    {
      type: "error",
      name: "TimestampNotNew",
      inputs: [],
    },
    {
      type: "error",
      name: "TimestampSpreadTooHigh",
      inputs: [],
    },
    {
      type: "error",
      name: "TooManyAggregators",
      inputs: [],
    },
    {
      type: "error",
      name: "TooManyExistingReports",
      inputs: [],
    },
  ] as const,
  instances: {
    AUDUSD: {
      11142220: "0x6F59935344432D758365E9bC0d48E1fF0b408db4",
    },
    AUSDUSD: {
      143: "0x2604F6daFed5b6204868e15E89ca41C2D5f6D9c2",
      10143: "0x73dF2f773cdEeBd33282107c5705E73321Ee0D4d",
    },
    BRLUSD: {
      11142220: "0x23aA272Ac1474D070a327FF6fcf65b78cBce6584",
    },
    CADUSD: {
      11142220: "0x7f13976279b3Da9f09b898FEECBcBA3C32AA93e0",
    },
    CELOAUD: {
      11142220: "0x8C901159B659c6d32Fd388ceF31177161D87ff68",
    },
    CELOBRL: {
      11142220: "0xEfa6f00469868b34B6d472f5E3E9715b694e2027",
    },
    CELOCAD: {
      11142220: "0xc4c3C5a01e962487F1a3f03E3287B6509DD66632",
    },
    CELOCHF: {
      11142220: "0x498A8f18ace887647f4cA436F47cB792A12E5469",
    },
    CELOCOP: {
      11142220: "0x904F3f318a31a72eBF4Dfe4ffdBa8edeAf106E21",
    },
    CELOETH: {
      11142220: "0x63F4d2aC940b4fD859F5A935Ed965d46C714eC6B",
    },
    CELOEUR: {
      11142220: "0x39d778811b3a821FeF7595D3917d7faAdb166adF",
    },
    CELOGBP: {
      11142220: "0x322058147899F064f353619a7dc0398039f4e501",
    },
    CELOGHS: {
      11142220: "0x234898e2E5F6933eaec7B3B7a40298195Bca4CC6",
    },
    CELOJPY: {
      11142220: "0x98d8FCcE5582283ad5bC7a6Bc781a7297d11A03D",
    },
    CELOKES: {
      11142220: "0x3d00E2FAB1Cd6988E8145EB84DC615ed2A414Bf0",
    },
    CELONGN: {
      11142220: "0x12ab3C0Fd87889E2EEeF38B5d80B03650c9D014a",
    },
    CELOPHP: {
      11142220: "0xEDD4141B665c90fbB47150aFAEf1893999Be1AE2",
    },
    CELOUSD: {
      11142220: "0x87335a896976A51d9c1D147AF32FB3536c31e85B",
    },
    CELOXOF: {
      11142220: "0x37e0be73052e1dE8fc07A2326Bb63D5c79CC5e2A",
    },
    CELOZAR: {
      11142220: "0x3385D9ec1668a11FE8C5851143F512880a4f716A",
    },
    CHFUSD: {
      11142220: "0xF7bCF416388aa2ec59da74ae1d8bc5C99c385884",
    },
    COPUSD: {
      11142220: "0xAd7AdcF65AB03857075ef1fa000eef7A3F40D6ce",
    },
    EUROCEUR: {
      11142220: "0xb3338B3bF86965444116E36AC22157bf4C1D4DF9",
    },
    EURUSD: {
      10143: "0x8220032E2d3541a9D3f88B2C7247301027f2Bc27",
      11142220: "0x0839CfefB470963Cabbed28dE81cFDe55A98bD69",
    },
    EURXOF: {
      11142220: "0x840653129B6eC9318bB4154Cb2Fd65Fc428fe089",
    },
    GBPUSD: {
      143: "0xDb8fc8c6DaaC8F73E21e9cC145440AB899d60e55",
      10143: "0xb8433a521881C17c7cf3F45684CdC9cc5918A736",
      11142220: "0x0D45E48a07c41defc88c7EEa0Fbab4aF5B5923D9",
    },
    GHSUSD: {
      11142220: "0x78069E0677f798e3BdA25b7dB54bd2f236B7d448",
    },
    JPYUSD: {
      11142220: "0x18fde6E5a2485D70b312FfC3a5138369c784a567",
    },
    KESUSD: {
      11142220: "0xb020926b1CE8Fa4118B43633d3c4c127c8f3dd8f",
    },
    NGNUSD: {
      11142220: "0xB42767062962B438C8f4c1d176E85D1B89B12618",
    },
    PHPUSD: {
      11142220: "0xd8dDe141DFe30DCeeF62bc295F8566dBfEB5F7e3",
    },
    USDCUSD: {
      143: "0xB1683dB4D2D74E951C54314f1BCA1e8FBB299fE2",
      10143: "0x34b8E391e26faf1af1c751aa4F6b5E19FBF9190B",
      11142220: "0x2026c1eA69E65dC370b46bfF9fDA1DCE256f188D",
    },
    USDTUSD: {
      10143: "0x10D98F3777Ce2a80fA2175C5641fBB2c15c00A98",
      11142220: "0x19ea130846452733ff2359974Cd58984A2e3963D",
    },
    XOFUSD: {
      11142220: "0xC22f388810A4183c61Cb8cdd4B20a5015f2398e6",
    },
    ZARUSD: {
      11142220: "0x757654C3B851110EEF9304e2297Bd592173Af1e6",
    },
  } as Record<string, Partial<Record<number, `0x${string}`>>>,
};
