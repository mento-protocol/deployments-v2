export const ConstantProductPricingModule = {
  abi: [
    {
      "type": "function",
      "name": "getAmountIn",
      "inputs": [
        {
          "name": "tokenInBucketSize",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "tokenOutBucketSize",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "spread",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountOut",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getAmountOut",
      "inputs": [
        {
          "name": "tokenInBucketSize",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "tokenOutBucketSize",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "spread",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountIn",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "name",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "string",
          "internalType": "string"
        }
      ],
      "stateMutability": "view"
    }
  ] as const,
  address: {
    42220: '0x0c07126d0CB30E66eF7553Cc7C37143B4f06DddB',
    11142220: '0x2584a5835e3aE7E901e6462E1de06920c2C68028',
  } as Partial<Record<number, `0x${string}`>>,
};
