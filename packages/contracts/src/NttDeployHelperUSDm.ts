export const NttDeployHelperUSDm = {
  abi: [
    {
      "type": "constructor",
      "inputs": [
        {
          "name": "token",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "mode",
          "type": "uint8",
          "internalType": "enum IManagerBase.Mode"
        },
        {
          "name": "wormholeChainId",
          "type": "uint16",
          "internalType": "uint16"
        },
        {
          "name": "wormholeCoreBridge",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "consistencyLevel",
          "type": "uint8",
          "internalType": "uint8"
        },
        {
          "name": "initialOwner",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "nttManagerImpl",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "nttManagerProxy",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "transceiverImpl",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "transceiverProxy",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    }
  ] as const,
  address: {
    143: '0x37316334108C816f9862baB52347A0aab7551127',
    42220: '0x37316334108C816f9862baB52347A0aab7551127',
  } as Partial<Record<number, `0x${string}`>>,
};
