export const ReserveV2 = {
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
      "type": "receive",
      "stateMutability": "payable"
    },
    {
      "type": "function",
      "name": "getCollateralAssets",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address[]",
          "internalType": "address[]"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getLiquidityStrategySpenders",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address[]",
          "internalType": "address[]"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getOtherReserveAddresses",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address[]",
          "internalType": "address[]"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getReserveManagerSpenders",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address[]",
          "internalType": "address[]"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getStableAssets",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address[]",
          "internalType": "address[]"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "initialize",
      "inputs": [
        {
          "name": "_stableAssets",
          "type": "address[]",
          "internalType": "address[]"
        },
        {
          "name": "_collateralAssets",
          "type": "address[]",
          "internalType": "address[]"
        },
        {
          "name": "_otherReserveAddresses",
          "type": "address[]",
          "internalType": "address[]"
        },
        {
          "name": "_liquidityStrategySpenders",
          "type": "address[]",
          "internalType": "address[]"
        },
        {
          "name": "_reserveManagerSpenders",
          "type": "address[]",
          "internalType": "address[]"
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
      "name": "isCollateralAsset",
      "inputs": [
        {
          "name": "_collateralAsset",
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
      "name": "isLiquidityStrategySpender",
      "inputs": [
        {
          "name": "_liquidityStrategySpender",
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
      "name": "isOtherReserveAddress",
      "inputs": [
        {
          "name": "_otherReserveAddress",
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
      "name": "isReserveManagerSpender",
      "inputs": [
        {
          "name": "_reserveManagerSpender",
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
      "name": "isStableAsset",
      "inputs": [
        {
          "name": "_stableAsset",
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
      "name": "registerCollateralAsset",
      "inputs": [
        {
          "name": "_collateralAsset",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "registerLiquidityStrategySpender",
      "inputs": [
        {
          "name": "_liquidityStrategySpender",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "registerOtherReserveAddress",
      "inputs": [
        {
          "name": "_otherReserveAddress",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "registerReserveManagerSpender",
      "inputs": [
        {
          "name": "_reserveManagerSpender",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "registerStableAsset",
      "inputs": [
        {
          "name": "_stableAsset",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
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
      "name": "transferCollateralAsset",
      "inputs": [
        {
          "name": "collateralAsset",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "to",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "value",
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
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "transferCollateralAssetToOtherReserve",
      "inputs": [
        {
          "name": "collateralAsset",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "to",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "value",
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
      "name": "transferStableAsset",
      "inputs": [
        {
          "name": "stableAsset",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "to",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "value",
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
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "unregisterCollateralAsset",
      "inputs": [
        {
          "name": "_collateralAsset",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "unregisterLiquidityStrategySpender",
      "inputs": [
        {
          "name": "_liquidityStrategySpender",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "unregisterOtherReserveAddress",
      "inputs": [
        {
          "name": "_otherReserveAddress",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "unregisterReserveManagerSpender",
      "inputs": [
        {
          "name": "_reserveManagerSpender",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "unregisterStableAsset",
      "inputs": [
        {
          "name": "_stableAsset",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "event",
      "name": "CollateralAssetRegistered",
      "inputs": [
        {
          "name": "collateralAsset",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "CollateralAssetTransferredLiquidityStrategySpender",
      "inputs": [
        {
          "name": "liquidityStrategySpender",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "collateralAsset",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "to",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "value",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "CollateralAssetTransferredReserveManagerSpender",
      "inputs": [
        {
          "name": "reserveManagerSpender",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "collateralAsset",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "otherReserveAddress",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "value",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "CollateralAssetUnregistered",
      "inputs": [
        {
          "name": "collateralAsset",
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
      "name": "LiquidityStrategySpenderRegistered",
      "inputs": [
        {
          "name": "liquidityStrategySpender",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "LiquidityStrategySpenderUnregistered",
      "inputs": [
        {
          "name": "liquidityStrategySpender",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "OtherReserveAddressRegistered",
      "inputs": [
        {
          "name": "otherReserveAddress",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "OtherReserveAddressUnregistered",
      "inputs": [
        {
          "name": "otherReserveAddress",
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
      "name": "ReserveManagerSpenderRegistered",
      "inputs": [
        {
          "name": "reserveManagerSpender",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "ReserveManagerSpenderUnregistered",
      "inputs": [
        {
          "name": "reserveManagerSpender",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "StableAssetRegistered",
      "inputs": [
        {
          "name": "stableAsset",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "StableAssetTransferred",
      "inputs": [
        {
          "name": "reserveManagerSpender",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "stableAsset",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "to",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "value",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "StableAssetUnregistered",
      "inputs": [
        {
          "name": "stableAsset",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "error",
      "name": "AddressNotInArray",
      "inputs": []
    },
    {
      "type": "error",
      "name": "ArrayEmpty",
      "inputs": []
    },
    {
      "type": "error",
      "name": "CollateralAssetAlreadyRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "CollateralAssetNotRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "CollateralAssetZeroAddress",
      "inputs": []
    },
    {
      "type": "error",
      "name": "InsufficientReserveBalance",
      "inputs": []
    },
    {
      "type": "error",
      "name": "LiquidityStrategySpenderAlreadyRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "LiquidityStrategySpenderNotRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "LiquidityStrategySpenderZeroAddress",
      "inputs": []
    },
    {
      "type": "error",
      "name": "OtherReserveAddressAlreadyRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "OtherReserveAddressNotRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "OtherReserveAddressZeroAddress",
      "inputs": []
    },
    {
      "type": "error",
      "name": "ReserveManagerSpenderAlreadyRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "ReserveManagerSpenderNotRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "ReserveManagerSpenderZeroAddress",
      "inputs": []
    },
    {
      "type": "error",
      "name": "StableAssetAlreadyRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "StableAssetNotRegistered",
      "inputs": []
    },
    {
      "type": "error",
      "name": "StableAssetZeroAddress",
      "inputs": []
    }
  ] as const,
  address: {
    143: '0x4255Cf38e51516766180b33122029A88Cb853806',
    10143: '0xbCdc1D0b92DfceEaa0FcD0a0D53355F4bF1DB8a7',
    42220: '0x4255Cf38e51516766180b33122029A88Cb853806',
    11142220: '0xbCdc1D0b92DfceEaa0FcD0a0D53355F4bF1DB8a7',
  } as Partial<Record<number, `0x${string}`>>,
};
