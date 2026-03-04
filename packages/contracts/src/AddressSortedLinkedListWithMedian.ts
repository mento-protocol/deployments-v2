export const addressSortedLinkedListWithMedianAbi = [
    {
      "type": "function",
      "name": "toAddress",
      "inputs": [
        {
          "name": "b",
          "type": "bytes32",
          "internalType": "bytes32"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "pure"
    },
    {
      "type": "function",
      "name": "toBytes",
      "inputs": [
        {
          "name": "a",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "bytes32",
          "internalType": "bytes32"
        }
      ],
      "stateMutability": "pure"
    }
  ] as const;
