export const MarketHoursBreakerv300 = {
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
    143: '0x0A18B8e7338eF8d6025529257aA5CCd5A14e0DAF',
    10143: '0x99C968Bf5972C11442654b989B7eAD0237cA654B',
  } as Partial<Record<number, `0x${string}`>>,
};
