export const CollSurplusPool = {
  abi: [
      {
        "type": "constructor",
        "inputs": [
          {
            "name": "_addressesRegistry",
            "type": "address",
            "internalType": "contract IAddressesRegistry"
          }
        ],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "NAME",
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
        "name": "accountSurplus",
        "inputs": [
          {
            "name": "_account",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "_amount",
            "type": "uint256",
            "internalType": "uint256"
          }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "borrowerOperationsAddress",
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
        "name": "claimColl",
        "inputs": [
          {
            "name": "_account",
            "type": "address",
            "internalType": "address"
          }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "collToken",
        "inputs": [],
        "outputs": [
          {
            "name": "",
            "type": "address",
            "internalType": "contract IERC20"
          }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getCollBalance",
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
        "name": "getCollateral",
        "inputs": [
          {
            "name": "_account",
            "type": "address",
            "internalType": "address"
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
        "name": "troveManagerAddress",
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
        "type": "event",
        "name": "BorrowerOperationsAddressChanged",
        "inputs": [
          {
            "name": "_newBorrowerOperationsAddress",
            "type": "address",
            "indexed": false,
            "internalType": "address"
          }
        ],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "CollBalanceUpdated",
        "inputs": [
          {
            "name": "_account",
            "type": "address",
            "indexed": true,
            "internalType": "address"
          },
          {
            "name": "_newBalance",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          }
        ],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "CollSent",
        "inputs": [
          {
            "name": "_to",
            "type": "address",
            "indexed": true,
            "internalType": "address"
          },
          {
            "name": "_amount",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          }
        ],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "TroveManagerAddressChanged",
        "inputs": [
          {
            "name": "_newTroveManagerAddress",
            "type": "address",
            "indexed": false,
            "internalType": "address"
          }
        ],
        "anonymous": false
      }
    ] as const,
  address: {
    42220: '0xfFF48ee3bd2D534E35b54D538de30a9d7709d4B6',
    11142220: '0x4b8FD6eFe77B56a27c90eb46586c8903E8D0A63a',
  } as const,
} as const;
