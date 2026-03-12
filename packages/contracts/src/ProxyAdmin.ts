export const ProxyAdmin = {
  abi: [
    {
      "type": "function",
      "name": "changeProxyAdmin",
      "inputs": [
        {
          "name": "proxy",
          "type": "address",
          "internalType": "contract ITransparentUpgradeableProxy"
        },
        {
          "name": "newAdmin",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "getProxyAdmin",
      "inputs": [
        {
          "name": "proxy",
          "type": "address",
          "internalType": "contract ITransparentUpgradeableProxy"
        }
      ],
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
      "name": "getProxyImplementation",
      "inputs": [
        {
          "name": "proxy",
          "type": "address",
          "internalType": "contract ITransparentUpgradeableProxy"
        }
      ],
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
      "type": "function",
      "name": "upgrade",
      "inputs": [
        {
          "name": "proxy",
          "type": "address",
          "internalType": "contract ITransparentUpgradeableProxy"
        },
        {
          "name": "implementation",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "upgradeAndCall",
      "inputs": [
        {
          "name": "proxy",
          "type": "address",
          "internalType": "contract ITransparentUpgradeableProxy"
        },
        {
          "name": "implementation",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "data",
          "type": "bytes",
          "internalType": "bytes"
        }
      ],
      "outputs": [],
      "stateMutability": "payable"
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
    }
  ] as const,
  address: {
    42220: '0x70d8DC60f9701c46D4CE9AC141E154f6804e1dC3',
    11142220: '0x01bd47aa7B13a75c24E3dA760f8A503c435BB4Df',
  } as Partial<Record<number, `0x${string}`>>,
};
