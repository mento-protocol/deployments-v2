export const Routerv300 = {
  abi: [
    {
      "type": "constructor",
      "inputs": [
        {
          "name": "_forwarder",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_factoryRegistry",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_factory",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "addLiquidity",
      "inputs": [
        {
          "name": "tokenA",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenB",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "amountADesired",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountBDesired",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountAMin",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountBMin",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "to",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "deadline",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "amountA",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountB",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "liquidity",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "defaultFactory",
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
      "name": "factoryRegistry",
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
      "name": "generateZapInParams",
      "inputs": [
        {
          "name": "tokenA",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenB",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_factory",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "amountInA",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountInB",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "routesA",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            }
          ]
        },
        {
          "name": "routesB",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            }
          ]
        }
      ],
      "outputs": [
        {
          "name": "amountOutMinA",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountOutMinB",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountAMin",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountBMin",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "generateZapOutParams",
      "inputs": [
        {
          "name": "tokenA",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenB",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_factory",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "liquidity",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "routesA",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            }
          ]
        },
        {
          "name": "routesB",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            }
          ]
        }
      ],
      "outputs": [
        {
          "name": "amountOutMinA",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountOutMinB",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountAMin",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountBMin",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getAmountsOut",
      "inputs": [
        {
          "name": "amountIn",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "routes",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
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
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getReserves",
      "inputs": [
        {
          "name": "tokenA",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenB",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_factory",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "reserveA",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "reserveB",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "isTrustedForwarder",
      "inputs": [
        {
          "name": "forwarder",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "poolFor",
      "inputs": [
        {
          "name": "tokenA",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenB",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_factory",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "pool",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "quoteAddLiquidity",
      "inputs": [
        {
          "name": "tokenA",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenB",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_factory",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "amountADesired",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountBDesired",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "amountA",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountB",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "liquidity",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "quoteRemoveLiquidity",
      "inputs": [
        {
          "name": "tokenA",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenB",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_factory",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "liquidity",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "amountA",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountB",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "removeLiquidity",
      "inputs": [
        {
          "name": "tokenA",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenB",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "liquidity",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountAMin",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountBMin",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "to",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "deadline",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "amountA",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountB",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "sortTokens",
      "inputs": [
        {
          "name": "tokenA",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenB",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "token0",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "token1",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "pure"
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
          "name": "routes",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            }
          ]
        },
        {
          "name": "to",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "deadline",
          "type": "uint256",
          "internalType": "uint256"
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
      "name": "zapIn",
      "inputs": [
        {
          "name": "tokenIn",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "amountInA",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "amountInB",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "zapInPool",
          "type": "tuple",
          "internalType": "struct IRouter.Zap",
          "components": [
            {
              "name": "tokenA",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "tokenB",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "amountOutMinA",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "amountOutMinB",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "amountAMin",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "amountBMin",
              "type": "uint256",
              "internalType": "uint256"
            }
          ]
        },
        {
          "name": "routesA",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            }
          ]
        },
        {
          "name": "routesB",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            }
          ]
        },
        {
          "name": "to",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "liquidity",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "payable"
    },
    {
      "type": "function",
      "name": "zapOut",
      "inputs": [
        {
          "name": "tokenOut",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "liquidity",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "zapOutPool",
          "type": "tuple",
          "internalType": "struct IRouter.Zap",
          "components": [
            {
              "name": "tokenA",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "tokenB",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "amountOutMinA",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "amountOutMinB",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "amountAMin",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "amountBMin",
              "type": "uint256",
              "internalType": "uint256"
            }
          ]
        },
        {
          "name": "routesA",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            }
          ]
        },
        {
          "name": "routesB",
          "type": "tuple[]",
          "internalType": "struct IRouter.Route[]",
          "components": [
            {
              "name": "from",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "to",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "factory",
              "type": "address",
              "internalType": "address"
            }
          ]
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "error",
      "name": "ETHTransferFailed",
      "inputs": []
    },
    {
      "type": "error",
      "name": "Expired",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InsufficientAmount",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InsufficientAmountA",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InsufficientAmountADesired",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InsufficientAmountAOptimal",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InsufficientAmountB",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InsufficientAmountBDesired",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InsufficientLiquidity",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InsufficientOutputAmount",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InvalidAmountInForETHDeposit",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InvalidPath",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InvalidRouteA",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InvalidRouteB",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InvalidTokenInForETHDeposit",
      "inputs": []
    },
    {
      "type": "error",
      "name": "OnlyWETH",
      "inputs": []
    },
    {
      "type": "error",
      "name": "PoolDoesNotExist",
      "inputs": []
    },
    {
      "type": "error",
      "name": "PoolFactoryDoesNotExist",
      "inputs": []
    },
    {
      "type": "error",
      "name": "SameAddresses",
      "inputs": []
    },
    {
      "type": "error",
      "name": "ZeroAddress",
      "inputs": []
    }
  ] as const,
  address: {
    143: '0x4861840C2EfB2b98312B0aE34d86fD73E8f9B6f6',
    10143: '0xcf6cD45210b3ffE3cA28379C4683F1e60D0C2CCd',
  } as Partial<Record<number, `0x${string}`>>,
};
