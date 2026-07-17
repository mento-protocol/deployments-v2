export const AddressSortedLinkedListWithMedian = {
  abi: [
    {
      type: "function",
      name: "toAddress",
      inputs: [
        {
          name: "b",
          type: "bytes32",
          internalType: "bytes32",
        },
      ],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "toBytes",
      inputs: [
        {
          name: "a",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bytes32",
          internalType: "bytes32",
        },
      ],
      stateMutability: "pure",
    },
  ] as const,
  address: {
    137: "0x65052c55815F491094FD8F1D887d4B5C670abE3c",
    143: "0x65052c55815F491094FD8F1D887d4B5C670abE3c",
    10143: "0x8E1B1312EC92C9f8073296c4Cf1E60D31d228269",
    80002: "0xBb0217B412C979C15375524D491b3d18c5277B40",
    84532: "0xBb0217B412C979C15375524D491b3d18c5277B40",
    11142220: "0xf90B816Ea07eC3c6384656cd5B3249DA8fc3df6F",
  } as Partial<Record<number, `0x${string}`>>,
};
