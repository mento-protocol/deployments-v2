export const ConstantSumPricingModulev265 = {
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
          "name": "amountIn",
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
          "name": "amountOut",
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
    8453: '0x2722BbaaC5b16A06CbA4591a392A70e5A9274947',
    42220: '0x2722BbaaC5b16A06CbA4591a392A70e5A9274947',
  } as Partial<Record<number, `0x${string}`>>,
};
