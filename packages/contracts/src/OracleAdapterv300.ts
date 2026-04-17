export const OracleAdapterv300 = {
  abi: [
    {
      "type": "constructor",
      "inputs": [
        {
          "name": "disable",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "TRADING_MODE_BIDIRECTIONAL",
      "inputs": [],
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
      "name": "breakerBox",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "contract IBreakerBox"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "ensureRateValid",
      "inputs": [
        {
          "name": "rateFeedID",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getFXRateIfValid",
      "inputs": [
        {
          "name": "rateFeedID",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "numerator",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "denominator",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getRate",
      "inputs": [
        {
          "name": "rateFeedID",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "tuple",
          "internalType": "struct IOracleAdapter.RateInfo",
          "components": [
            {
              "name": "numerator",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "denominator",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "tradingMode",
              "type": "uint8",
              "internalType": "uint8"
            },
            {
              "name": "isRecent",
              "type": "bool",
              "internalType": "bool"
            },
            {
              "name": "isFXMarketOpen",
              "type": "bool",
              "internalType": "bool"
            }
          ]
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getRateIfValid",
      "inputs": [
        {
          "name": "rateFeedID",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "numerator",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "denominator",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getTradingMode",
      "inputs": [
        {
          "name": "rateFeedID",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint8",
          "internalType": "uint8"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "hasRecentRate",
      "inputs": [
        {
          "name": "rateFeedID",
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
      "name": "initialize",
      "inputs": [
        {
          "name": "_sortedOracles",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_breakerBox",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_marketHoursBreaker",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_l2SequencerUptimeFeed",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_initialOwner",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "isFXMarketOpen",
      "inputs": [],
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
      "name": "isL2SequencerUp",
      "inputs": [
        {
          "name": "since",
          "type": "uint256",
          "internalType": "uint256"
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
      "name": "l2SequencerUptimeFeed",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "contract AggregatorV3Interface"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "marketHoursBreaker",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "contract IMarketHoursBreaker"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "owner",
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
      "name": "renounceOwnership",
      "inputs": [],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setBreakerBox",
      "inputs": [
        {
          "name": "_breakerBox",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setL2SequencerUptimeFeed",
      "inputs": [
        {
          "name": "_l2SequencerUptimeFeed",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setMarketHoursBreaker",
      "inputs": [
        {
          "name": "_marketHoursBreaker",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setSortedOracles",
      "inputs": [
        {
          "name": "_sortedOracles",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "sortedOracles",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "contract ISortedOracles"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "transferOwnership",
      "inputs": [
        {
          "name": "newOwner",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "event",
      "name": "BreakerBoxUpdated",
      "inputs": [
        {
          "name": "oldBreakerBox",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "newBreakerBox",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "Initialized",
      "inputs": [
        {
          "name": "version",
          "type": "uint8",
          "indexed": false,
          "internalType": "uint8"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "L2SequencerUptimeFeedUpdated",
      "inputs": [
        {
          "name": "oldL2SequencerUptimeFeed",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "newL2SequencerUptimeFeed",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "MarketHoursBreakerUpdated",
      "inputs": [
        {
          "name": "oldMarketHoursBreaker",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "newMarketHoursBreaker",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "OwnershipTransferred",
      "inputs": [
        {
          "name": "previousOwner",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "newOwner",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "SortedOraclesUpdated",
      "inputs": [
        {
          "name": "oldSortedOracles",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "newSortedOracles",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "error",
      "name": "FXMarketClosed",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InvalidRate",
      "inputs": []
    },
    {
      "type": "error",
      "name": "NoRecentRate",
      "inputs": []
    },
    {
      "type": "error",
      "name": "TradingSuspended",
      "inputs": []
    },
    {
      "type": "error",
      "name": "ZeroAddress",
      "inputs": []
    }
  ] as const,
  address: {
    143: '0xc1B767756F582d124E76BB3e246f31e6aB256059',
    10143: '0x9CA4FA8253f14CfF40E42970df38799a78d3c482',
    42220: '0xc1B767756F582d124E76BB3e246f31e6aB256059',
    11142220: '0x9CA4FA8253f14CfF40E42970df38799a78d3c482',
  } as Partial<Record<number, `0x${string}`>>,
};
