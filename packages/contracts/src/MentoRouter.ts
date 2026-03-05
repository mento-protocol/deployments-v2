export const MentoRouter = { abi: [
    {
      "type": "constructor",
      "inputs": [
        {
          "name": "_broker",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_mentoReserveMultisig",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "drain",
      "inputs": [
        {
          "name": "asset",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "getAmountIn",
      "inputs": [
        {
          "name": "amountOut",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "path",
          "type": "tuple[]",
          "internalType": "struct IMentoRouter.Step[]",
          "components": [
            {
              "name": "exchangeProvider",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "exchangeId",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "assetIn",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "assetOut",
              "type": "address",
              "internalType": "address"
            }
          ]
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
          "name": "amountIn",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "path",
          "type": "tuple[]",
          "internalType": "struct IMentoRouter.Step[]",
          "components": [
            {
              "name": "exchangeProvider",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "exchangeId",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "assetIn",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "assetOut",
              "type": "address",
              "internalType": "address"
            }
          ]
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
      "name": "swapExactTokensForTokens",
      "inputs": [
        {
          "name": "amountIn",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountOutMin",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "path",
          "type": "tuple[]",
          "internalType": "struct IMentoRouter.Step[]",
          "components": [
            {
              "name": "exchangeProvider",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "exchangeId",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "assetIn",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "assetOut",
              "type": "address",
              "internalType": "address"
            }
          ]
        }
      ],
      "outputs": [
        {
          "name": "amounts",
          "type": "uint256[]",
          "internalType": "uint256[]"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "swapTokensForExactTokens",
      "inputs": [
        {
          "name": "amountOut",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountInMax",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "path",
          "type": "tuple[]",
          "internalType": "struct IMentoRouter.Step[]",
          "components": [
            {
              "name": "exchangeProvider",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "exchangeId",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "assetIn",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "assetOut",
              "type": "address",
              "internalType": "address"
            }
          ]
        }
      ],
      "outputs": [
        {
          "name": "amounts",
          "type": "uint256[]",
          "internalType": "uint256[]"
        }
      ],
      "stateMutability": "nonpayable"
    }
  ] as const };
