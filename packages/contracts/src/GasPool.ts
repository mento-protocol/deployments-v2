export const GasPool = {
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
      }
    ] as const,
  address: {
    42220: '0x8b61f941D89560C7D8b3D595F44F7fd97D79817b',
    11142220: '0xcf0349BaffbEEb9f5c8871338415613610DC321E',
  } as const,
} as const;
