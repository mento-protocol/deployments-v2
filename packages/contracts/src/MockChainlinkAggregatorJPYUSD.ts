export const mockChainlinkAggregatorJPYUSDAbi = [
    {
      "type": "constructor",
      "inputs": [
        {
          "name": "_description",
          "type": "string",
          "internalType": "string"
        },
        {
          "name": "_decimals",
          "type": "uint8",
          "internalType": "uint8"
        },
        {
          "name": "_initialOwner",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "decimals",
      "inputs": [],
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
      "name": "description",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "string",
          "internalType": "string"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "externalProvider",
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
      "name": "lastUpdated",
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
      "name": "latestRoundData",
      "inputs": [],
      "outputs": [
        {
          "name": "roundId",
          "type": "uint80",
          "internalType": "uint80"
        },
        {
          "name": "answer",
          "type": "int256",
          "internalType": "int256"
        },
        {
          "name": "startedAt",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "updatedAt",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "answeredInRound",
          "type": "uint80",
          "internalType": "uint80"
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
      "name": "report",
      "inputs": [
        {
          "name": "_answer",
          "type": "int256",
          "internalType": "int256"
        },
        {
          "name": "_lastUpdated",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "savedAnswer",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "int256",
          "internalType": "int256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "setAnswer",
      "inputs": [
        {
          "name": "_answer",
          "type": "int256",
          "internalType": "int256"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setDecimals",
      "inputs": [
        {
          "name": "_decimals",
          "type": "uint8",
          "internalType": "uint8"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setExternalProvider",
      "inputs": [
        {
          "name": "_externalProvider",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setLastUpdated",
      "inputs": [
        {
          "name": "_lastUpdated",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
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
      "type": "error",
      "name": "OwnableInvalidOwner",
      "inputs": [
        {
          "name": "owner",
          "type": "address",
          "internalType": "address"
        }
      ]
    },
    {
      "type": "error",
      "name": "OwnableUnauthorizedAccount",
      "inputs": [
        {
          "name": "account",
          "type": "address",
          "internalType": "address"
        }
      ]
    }
  ] as const;
