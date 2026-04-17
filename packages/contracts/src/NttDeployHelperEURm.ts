export const NttDeployHelperEURm = {
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
    143: '0x0e72e26E4e08779D08B2A52F59f41E6659a3547d',
    42220: '0x0e72e26E4e08779D08B2A52F59f41E6659a3547d',
  } as Partial<Record<number, `0x${string}`>>,
};
