export const NttDeployHelper = {
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
  instances: {
    CHFm: {
      143: "0x6862ecB81abE08311C2978E518D083bDa5C00Bdf",
      42220: "0x6862ecB81abE08311C2978E518D083bDa5C00Bdf",
    },
    EURm: {
      143: "0x0e72e26E4e08779D08B2A52F59f41E6659a3547d",
      42220: "0x0e72e26E4e08779D08B2A52F59f41E6659a3547d",
    },
    GBPm: {
      143: "0xF3797E9D818A47A3a604bF2346E4ff50b56ad5c4",
      42220: "0xF3797E9D818A47A3a604bF2346E4ff50b56ad5c4",
    },
    JPYm: {
      143: "0x05c73B2507EebfF0C0c6e95f335D0910A227Dbc9",
      42220: "0x05c73B2507EebfF0C0c6e95f335D0910A227Dbc9",
    },
    USDm: {
      143: "0x37316334108C816f9862baB52347A0aab7551127",
      42220: "0x37316334108C816f9862baB52347A0aab7551127",
    },
  } as Record<string, Partial<Record<number, `0x${string}`>>>,
};
