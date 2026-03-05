export const MarketHoursBreaker = {
  abi: [
      {
        "type": "function",
        "name": "isFXMarketOpen",
        "inputs": [
          {
            "name": "timestamp",
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
        "stateMutability": "pure"
      },
      {
        "type": "function",
        "name": "shouldTrigger",
        "inputs": [
          {
            "name": "",
            "type": "address",
            "internalType": "address"
          }
        ],
        "outputs": [
          {
            "name": "triggerBreaker",
            "type": "bool",
            "internalType": "bool"
          }
        ],
        "stateMutability": "view"
      }
    ] as const,
  address: {
    11142220: '0x99C968Bf5972C11442654b989B7eAD0237cA654B',
  } as const,
} as const;
