export const NttDeployHelperGBPm = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "token",
          type: "address",
          internalType: "address",
        },
        {
          name: "mode",
          type: "uint8",
          internalType: "enum IManagerBase.Mode",
        },
        {
          name: "wormholeChainId",
          type: "uint16",
          internalType: "uint16",
        },
        {
          name: "wormholeCoreBridge",
          type: "address",
          internalType: "address",
        },
        {
          name: "consistencyLevel",
          type: "uint8",
          internalType: "uint8",
        },
        {
          name: "initialOwner",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "nttManagerImpl",
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
      name: "nttManagerProxy",
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
      name: "transceiverImpl",
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
      name: "transceiverProxy",
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
  ] as const,
  address: {
    143: "0xF3797E9D818A47A3a604bF2346E4ff50b56ad5c4",
    42220: "0xF3797E9D818A47A3a604bF2346E4ff50b56ad5c4",
  } as Partial<Record<number, `0x${string}`>>,
};
