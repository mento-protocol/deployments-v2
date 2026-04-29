export const DefaultPoolv300CHFm = {
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
      name: "activePoolAddress",
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
      name: "decreaseBoldDebt",
      inputs: [
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
      name: "getBoldDebt",
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
      name: "increaseBoldDebt",
      inputs: [
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
      name: "receiveColl",
      inputs: [
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
      name: "sendCollToActivePool",
      inputs: [
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
      name: "ActivePoolAddressChanged",
      inputs: [
        {
          name: "_newActivePoolAddress",
          type: "address",
          indexed: false,
          internalType: "address",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "CollTokenAddressChanged",
      inputs: [
        {
          name: "_newCollTokenAddress",
          type: "address",
          indexed: false,
          internalType: "address",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "DefaultPoolBoldDebtUpdated",
      inputs: [
        {
          name: "_boldDebt",
          type: "uint256",
          indexed: false,
          internalType: "uint256",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "DefaultPoolCollBalanceUpdated",
      inputs: [
        {
          name: "_collBalance",
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
    42220: "0x542191E79732A4498f263e793Cc47942956f33f7",
    11142220: "0xfaad27924d950848B5c8BB47B5ADA5E3e2909277",
  } as Partial<Record<number, `0x${string}`>>,
};
