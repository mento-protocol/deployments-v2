export const ChainlinkRelayerV1CELOETH = {
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
  address: {
    11142220: "0x63F4d2aC940b4fD859F5A935Ed965d46C714eC6B",
  } as Partial<Record<number, `0x${string}`>>,
};
