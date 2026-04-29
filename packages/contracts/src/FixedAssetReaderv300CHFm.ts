export const FixedAssetReaderv300CHFm = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "_pointer",
          type: "address",
          internalType: "address",
        },
        {
          name: "_sigs",
          type: "bytes4[]",
          internalType: "bytes4[]",
        },
        {
          name: "_assets",
          type: "tuple[]",
          internalType: "struct FixedAssetReader.Asset[]",
          components: [
            {
              name: "start",
              type: "uint128",
              internalType: "uint128",
            },
            {
              name: "end",
              type: "uint128",
              internalType: "uint128",
            },
          ],
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "assets",
      inputs: [
        {
          name: "",
          type: "bytes4",
          internalType: "bytes4",
        },
      ],
      outputs: [
        {
          name: "start",
          type: "uint128",
          internalType: "uint128",
        },
        {
          name: "end",
          type: "uint128",
          internalType: "uint128",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "pointer",
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
      name: "readAsset",
      inputs: [
        {
          name: "_sig",
          type: "bytes4",
          internalType: "bytes4",
        },
      ],
      outputs: [
        {
          name: "",
          type: "string",
          internalType: "string",
        },
      ],
      stateMutability: "view",
    },
  ] as const,
  address: {
    42220: "0x769E0795C11b5a37Cf7Ab053e8610f73265067A0",
    11142220: "0x55A7947E6d51657B90f2470d8dc5084fC4E829F4",
  } as Partial<Record<number, `0x${string}`>>,
};
