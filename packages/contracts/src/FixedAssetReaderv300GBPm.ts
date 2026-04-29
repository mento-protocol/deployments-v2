export const FixedAssetReaderv300GBPm = {
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
    42220: "0xb62825c011D2ae3fc89bc4e095e43B51D06545b5",
    11142220: "0x8C5F8176deD6569Db1b2E14b089439aB68c6FB56",
  } as Partial<Record<number, `0x${string}`>>,
};
