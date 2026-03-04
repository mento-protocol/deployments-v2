export const marketHoursBreakerAbi = [
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
  ] as const;
