export const HintHelpers = {
  abi: [
      {
        "type": "constructor",
        "inputs": [
          {
            "name": "_collateralRegistry",
            "type": "address",
            "internalType": "contract ICollateralRegistry"
          },
          {
            "name": "_systemParams",
            "type": "address",
            "internalType": "contract ISystemParams"
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
        "name": "collateralRegistry",
        "inputs": [],
        "outputs": [
          {
            "name": "",
            "type": "address",
            "internalType": "contract ICollateralRegistry"
          }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "forcePredictAdjustInterestRateUpfrontFee",
        "inputs": [
          {
            "name": "_collIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_troveId",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_newInterestRate",
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
        "name": "getApproxHint",
        "inputs": [
          {
            "name": "_collIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_interestRate",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_numTrials",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_inputRandomSeed",
            "type": "uint256",
            "internalType": "uint256"
          }
        ],
        "outputs": [
          {
            "name": "hintId",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "diff",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "latestRandomSeed",
            "type": "uint256",
            "internalType": "uint256"
          }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "predictAdjustBatchInterestRateUpfrontFee",
        "inputs": [
          {
            "name": "_collIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_batchAddress",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "_newInterestRate",
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
        "name": "predictAdjustInterestRateUpfrontFee",
        "inputs": [
          {
            "name": "_collIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_troveId",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_newInterestRate",
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
        "name": "predictAdjustTroveUpfrontFee",
        "inputs": [
          {
            "name": "_collIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_troveId",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_debtIncrease",
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
        "name": "predictJoinBatchInterestRateUpfrontFee",
        "inputs": [
          {
            "name": "_collIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_troveId",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_batchAddress",
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
        "name": "predictOpenTroveAndJoinBatchUpfrontFee",
        "inputs": [
          {
            "name": "_collIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_borrowedAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_batchAddress",
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
        "name": "predictOpenTroveUpfrontFee",
        "inputs": [
          {
            "name": "_collIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_borrowedAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_interestRate",
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
        "name": "predictRemoveFromBatchUpfrontFee",
        "inputs": [
          {
            "name": "_collIndex",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_troveId",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_newInterestRate",
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
        "name": "systemParamsAddress",
        "inputs": [],
        "outputs": [
          {
            "name": "",
            "type": "address",
            "internalType": "address"
          }
        ],
        "stateMutability": "view"
      }
    ] as const,
  address: {
    11142220: '0x5A54DD5d7AD1b782b43bB08d0A40CA947a315556',
  } as const,
} as const;
