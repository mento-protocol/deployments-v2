export const ConstantProductPricingModulev265 = {
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
    8453: '0xD46FFe35B7DDA71218910d081A6333cb642c910C',
    42220: '0xD46FFe35B7DDA71218910d081A6333cb642c910C',
  } as Partial<Record<number, `0x${string}`>>,
};
