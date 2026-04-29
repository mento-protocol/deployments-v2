export const CollSurplusPoolv300JPYm = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "_addressesRegistry",
          type: "address",
          internalType: "contract IAddressesRegistry",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "NAME",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "string",
          internalType: "string",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "accountSurplus",
      inputs: [
        {
          name: "_account",
          type: "address",
          internalType: "address",
        },
        {
          name: "_amount",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "borrowerOperationsAddress",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "claimColl",
      inputs: [
        {
          name: "_account",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "collToken",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "contract IERC20",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getCollBalance",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getCollateral",
      inputs: [
        {
          name: "_account",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "troveManagerAddress",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "event",
      name: "BorrowerOperationsAddressChanged",
      inputs: [
        {
          name: "_newBorrowerOperationsAddress",
          type: "address",
          indexed: false,
          internalType: "address",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "CollBalanceUpdated",
      inputs: [
        {
          name: "_account",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "_newBalance",
          type: "uint256",
          indexed: false,
          internalType: "uint256",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "CollSent",
      inputs: [
        {
          name: "_to",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "_amount",
          type: "uint256",
          indexed: false,
          internalType: "uint256",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "TroveManagerAddressChanged",
      inputs: [
        {
          name: "_newTroveManagerAddress",
          type: "address",
          indexed: false,
          internalType: "address",
        },
      ],
      anonymous: false,
    },
  ] as const,
  address: {
    42220: "0x52f659C562f5bA9668Ac71DB2ac860aF10040b15",
    11142220: "0xCBBcfFdC94c7f9A95c5F7489F6D1d988f4AD0576",
  } as Partial<Record<number, `0x${string}`>>,
};
