export const FixedAssetReaderv300JPYm = {
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
    42220: "0x1B0faf03Dc64a419dEd27bE6899e35a843C6020f",
    11142220: "0x05904Ca3A6Ea82c8Cb4a553B691972f1B163B452",
  } as Partial<Record<number, `0x${string}`>>,
};
