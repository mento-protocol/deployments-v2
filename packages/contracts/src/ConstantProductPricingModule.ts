export const ConstantProductPricingModule = { abi: [
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
  ] as const };
